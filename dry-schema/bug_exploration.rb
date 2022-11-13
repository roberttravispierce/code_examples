# frozen_string_literal: true

# File to reproduce and explore the cause of a reported bug with the dry-schema library ([Inconsistent errors using struct extension · Issue #424 · dry-rb/dry-schema](https://github.com/dry-rb/dry-schema/issues/424))

# To run locally, first: `gem install dry-schema dry-struct`

require 'dry-schema'
require 'dry-struct'

Types = Dry.Types

class FilterStruct < Dry::Struct
  attribute? :candidate_ids, Types::Array.of(Types::Params::Integer)

  # # Check with a coercible integer type just to see = no change
  # attribute? :candidate_ids, Types::Array.of(Dry::Types["coercible.integer"])

  # # Check integer & string param logic together = no errors
  # attribute? :candidate_ids, Types::Array.of(Types::Params::Integer | Types::Params::String)
end

class FiltersSchema < Dry::Schema::Params
  Dry::Schema.load_extensions(:struct)

  define do
    optional(:filters).hash(FilterStruct)
  end
end

def check_result_of(id_array)
  result = FiltersSchema.new.call(filters: { candidate_ids: id_array }).errors.to_h
  err_report = result == {} ? 'No errors' : "Errors: #{result}"
  puts "When candidate_ids is #{id_array}: #{err_report}\n\n"
end

# Original examples from issue
check_result_of(['1'])
check_result_of(%w[m 1])

# # Additional examples to tease out the problem scope
check_result_of([1])
check_result_of(['m', 1])
check_result_of([1, '2', 345])
check_result_of([1, '2', 345, 'xyz'])
check_result_of(%w[1 m 2])
check_result_of(['m'])
