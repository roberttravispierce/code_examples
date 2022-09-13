module ShopifyConnector
  module Handlers
    class CheckSyncOfVariantCoverImages < BaseAsyncHandler
      # Checks that the existing Shopify ProductVariant image and the (possibly) updated
      # Marketplacer Variant cover image are the same.

      def run
        product_variant_cover_images_in_sync? ? publish_an_in_sync_event : publish_an_update_required_event
      end

      private

      def product_variant_cover_images_in_sync?
        get_variant_entities.all? do |variant_entity|
          new_cover_image_id = get_new_product_variant_cover_image_id(variant_entity)
          existing_cover_image_id = get_existing_product_variant_cover_image_id(variant_entity)

          new_cover_image_id == existing_cover_image_id
        end
      end

      def get_new_product_variant_cover_image_id(variant_entity)
        marketplacer_cover_image_entity = get_marketplacer_cover_image_entity(variant_entity)
        return unless marketplacer_cover_image_entity

        Entity.find_by(
          source_type: "ProductImage",
          vertical_id: vertical_id,
          deleted: false,
          marketplacer_entity: marketplacer_cover_image_entity,
        )&.id
      end

      def get_existing_product_variant_cover_image_id(variant_entity)
        product_variant_entity = get_product_variant_entity(variant_entity)
        return unless product_variant_entity

        image_id = EntityLevelMapping.find_by(
          marketplacer_entity_id: variant_entity.id,
          shopify_connector_entity_id: product_variant_entity.id,
          key: "Image",
        )&.value
        image_id.blank? ? nil : image_id.to_i
      end

      def product_entity
        Entity.find_by(
          id: data[:shopify_product_entity_id],
          source_type: "Product",
          vertical: vertical,
        )
      end

      def advert_entity
        product_entity.marketplacer_entity
      end

      def get_product_variant_entity(variant_entity)
        Entity.find_by(
          source_type: "ProductVariant",
          vertical_id: vertical.id,
          marketplacer_entity: variant_entity,
          deleted: false,
        )
      end

      def get_variant_entities
        advert_entity.children.where(
          source_type: "Variant",
          deleted: false,
        ).where.not(
          source_id: nil,
        )
      end

      def get_marketplacer_cover_image_entity(variant_entity)
        variant_entity
          .children
          .where("source_value->'position' = '1'")
          .find_by(
            source_type: "Image",
            vertical_id: vertical_id,
            deleted: false,
          )
      end

      def publish_an_update_required_event
        EventStore.publish(
          Events::ProductVariantImagesUpdateRequired.new(data: event_data),
        )
      end

      def publish_an_in_sync_event
        EventStore.publish(
          Events::ProductVariantCoverImagesInSync.new(data: event_data),
        )
      end

      def event_data
        {shopify_product_entity_id: data[:shopify_product_entity_id]}
      end
    end
  end
end
