module ShopifyConnector
  RSpec.describe Handlers::CheckSyncOfVariantCoverImages do
    let(:vertical) do
      create(
        :vertical,
      )
    end
    let!(:shopify_config) do
      create(
        :shopify_vertical_configuration,
        vertical: vertical,
      )
    end
    let(:triggering_event) do
      Events::NoImagesCreatedOnMarketplacer.new(
        data: {
          shopify_product_entity_id: shopify_product_entity.id,
        },
      )
    end
    let(:marketplacer_advert_entity) do
      create(
        :marketplacer_entity,
        :advert,
        vertical: vertical,
      )
    end
    let(:shopify_product_entity) do
      create(
        :shopify_entity,
        :product,
        marketplacer_entity: marketplacer_advert_entity,
        vertical: vertical,
      )
    end
    let(:marketplacer_variant_entity) do
      create(
        :marketplacer_entity,
        :variant,
        vertical: vertical,
        parents: [marketplacer_advert_entity],
      )
    end
    let!(:shopify_product_variant_entity) do
      create(
        :shopify_entity,
        :product_variant,
        marketplacer_entity: marketplacer_variant_entity,
        parents: [shopify_product_entity],
        vertical: vertical,
      )
    end

    let(:marketplacer_variant_entity_2) do
      create(
        :marketplacer_entity,
        :variant,
        vertical: vertical,
        parents: [marketplacer_advert_entity],
      )
    end
    let!(:shopify_product_variant_entity_2) do
      create(
        :shopify_entity,
        :product_variant,
        marketplacer_entity: marketplacer_variant_entity_2,
        parents: [shopify_product_entity],
        vertical: vertical,
      )
    end

    let!(:variant_image_entity_deleted) do
      create(
        :marketplacer_entity,
        :image,
        parents: [marketplacer_variant_entity],
        vertical: vertical,
        source_value: {
          __typename: "Image",
          id: "SW1hZ2UtMjQ4",
          url: "https://marketplacer.imgix.net/1E/J9FlLUq70kPCahCTVsafJURtQ.jpg?auto=format&fm=pjpg&fit=max&w=2048&h=2048&s=cb856a89d7c8e51cb31704c2da5fad91",
          filename: "604-536x354.jpg",
          position: 1,
        },
        deleted: true,
      )
    end
    let!(:product_image_entity_deleted) do
      create(
        :shopify_entity,
        :product_image,
        parents: [shopify_product_entity],
        vertical: vertical,
        marketplacer_entity: variant_image_entity_deleted,
      )
    end
    let(:variant_image_entity_1) do
      create(
        :marketplacer_entity,
        :image,
        parents: [marketplacer_variant_entity],
        vertical: vertical,
        source_value: {
          __typename: "Image",
          id: "SW1hZ2UtMjQ4",
          url: "https://marketplacer.imgix.net/1E/J9FlLUq70kPCahCTVsafJURtQ.jpg?auto=format&fm=pjpg&fit=max&w=2048&h=2048&s=cb856a89d7c8e51cb31704c2da5fad91",
          filename: "604-536x354.jpg",
          position: 1,
        },
      )
    end
    let(:variant_image_entity_2) do
      create(
        :marketplacer_entity,
        :image,
        parents: [marketplacer_variant_entity],
        vertical: vertical,
        source_value: {
          __typename: "Image",
          id: "SW1hZ2UtMjQ4",
          url: "https://marketplacer.imgix.net/1E/J9FlLUq70kPCahCTVsafJURtQ.jpg?auto=format&fm=pjpg&fit=max&w=2048&h=2048&s=cb856a89d7c8e51cb31704c2da5fad91",
          filename: "604-536x354.jpg",
          position: 2,
        },
      )
    end
    let!(:product_image_entity_1) do
      create(
        :shopify_entity,
        :product_image,
        parents: [shopify_product_entity],
        vertical: vertical,
        marketplacer_entity: variant_image_entity_1,
      )
    end
    let!(:product_image_entity_2) do
      create(
        :shopify_entity,
        :product_image,
        parents: [shopify_product_entity],
        vertical: vertical,
        marketplacer_entity: variant_image_entity_2,
      )
    end
    let!(:variant_image_mapping) do
      create(
        :shopify_entity_level_mapping,
        entity: shopify_product_variant_entity,
        marketplacer_entity: marketplacer_variant_entity,
        key: "Image",
        value: shopify_variant_image_entity_id.to_s,
      )
    end

    describe "#run - Check if the Shopify ProductVariant image matches the Marketplacer Variant cover image" do
      before do
        allow_any_instance_of(Handlers::MapMarketplacerAdvertImageOrdersToShopifyProductImageOrders).to receive(:run)
        EventStore.with_metadata(vertical_id: vertical.id) do
          EventStore.publish(triggering_event)
        end
        Sidekiq::Job.drain_all
      end

      context "when they both exist" do
        context "when they match" do
          let(:shopify_variant_image_entity_id) { product_image_entity_1.id }

          it "publishes a ProductVariantCoverImagesInSync event" do
            expect(EventStore).to have_published(
              an_event(
                Events::ProductVariantCoverImagesInSync,
              ).with_data(
                shopify_product_entity_id: shopify_product_entity.id,
              ),
            )
          end

          context "when there is also a previous Marketplacer variant cover image that was deleted" do
            let(:shopify_variant_image_entity_id) { product_image_entity_deleted.id }

            it "publishes a ProductVariantImagesUpdateRequired event" do
              expect(EventStore).to have_published(
                an_event(
                  Events::ProductVariantImagesUpdateRequired,
                ).with_data(
                  shopify_product_entity_id: shopify_product_entity.id,
                ),
              )
            end
          end
        end

        context "when some variants match and some don't" do
          let(:shopify_variant_image_entity_id) { product_image_entity_2.id }

          it "publishes a ProductVariantImagesUpdateRequired event" do
            expect(EventStore).to have_published(
              an_event(
                Events::ProductVariantImagesUpdateRequired,
              ).with_data(
                shopify_product_entity_id: shopify_product_entity.id,
              ),
            )
          end
        end
      end

      context "when they don't both exist" do
        context "when only a Marketplacer Variant cover image exists" do
          let(:shopify_variant_image_entity_id) { nil }

          it "publishes a ProductVariantImagesUpdateRequired event" do
            expect(EventStore).to have_published(
              an_event(
                Events::ProductVariantImagesUpdateRequired,
              ).with_data(
                shopify_product_entity_id: shopify_product_entity.id,
              ),
            )
          end
        end

        context "when only a Shopify ProductVariant image exists" do
          let(:shopify_variant_image_entity_id) { product_image_entity_2.id }
          let(:variant_image_entity_1) { nil }

          it "publishes a ProductVariantImagesUpdateRequired event" do
            expect(EventStore).to have_published(
              an_event(
                Events::ProductVariantImagesUpdateRequired,
              ).with_data(
                shopify_product_entity_id: shopify_product_entity.id,
              ),
            )
          end
        end

        context "when neither exists" do
          let(:shopify_variant_image_entity_id) { nil }
          let(:variant_image_entity_2) { nil }

          it "publishes a ProductVariantImagesUpdateRequired event" do
            expect(EventStore).to have_published(
              an_event(
                Events::ProductVariantImagesUpdateRequired,
              ).with_data(
                shopify_product_entity_id: shopify_product_entity.id,
              ),
            )
          end
        end
      end
    end
  end
end
