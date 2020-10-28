# frozen_string_literal: true

module ContextualLogger
  module Context
    module RegistryTypes
      class String
        attr_reader :formatter

        def initialize(formatter: nil)
          @formatter = formatter || :to_s
        end

        def to_h
          { type: :string, formatter: formatter }
        end

        def format(value)
          case formatter
          when Proc
            formatter.call(value)
          else
            value.send(formatter)
          end
        end
      end
    end
  end
end
