# encoding: utf-8
# author: Dominik Richter
# author: Christoph Hartmann

module Inspec
  module ResourceBehaviors
    def to_s
      @__resource_name__
    end

    # Overwrite inspect to provide better output to RSpec results.
    #
    # @return [String] full name of the resource
    def inspect
      to_s
    end
  end

  module ResourceDSL
    def name(name = nil)
      return if name.nil?
      @name = name
      @resource_metadata = {
        name: name,
        decription: '',
        example: '',
        limitations: '',
        related_resources: [],
        permissions_required: [],
        platform_support: [],
        resource_params: [],
        properties: [],
        matchers: [],
        filter_criteria: [],
        plural?: false
      }
      __register(name, self)
    end

    def resource_metadata
      @resource_metadata
    end

    def desc(description = nil)
      return if description.nil?
      @resource_metadata[:description] = description
      __resource_registry[@name].desc(description)
    end

    def supports(criteria = nil)
      return if criteria.nil?
      @resource_metadata[:platform_support].push(criteria)            
      Inspec::Resource.supports[@name] ||= []
      Inspec::Resource.supports[@name].push(criteria)
    end

    def example(example = nil)
      return if example.nil?
      @resource_metadata[:examples] = example      
      __resource_registry[@name].example(example)
    end

    def plurality(arity = :singular)
      # This may be nonbinary
      if arity == :plural
        @resource_metadata[:plural?] = true
      end
    end

    def limitations(info = nil)
      return if info.nil?
      @resource_metadata[:limitations] = info
    end

    def related_resource(opts = {})
      return if opts[:name].nil?
      # :name, :description, :relation
      @resource_metadata[:related_resources].push opts.dup
    end

    def resource_param(opts = {})
      return if opts[:name].nil?
      # :name, :type, :description, :example, :is_identifier
      @resource_metadata[:resource_params].push opts.dup
    end

    def required_permission(opts = {})
      return if opts[:name].nil?
      # :name, :description
      @resource_metadata[:permissions_required].push opts.dup
    end

    def property(opts = {})
      return if opts[:name].nil?
      # :name, :type, :description, :example, :identifier_for, :permissions_required, :see_also
      @resource_metadata[:properties].push opts.dup
    end

    def matcher(opts = {})
      return if opts[:name].nil?
      # :name, :args (array of hash: name, type, description), :description, :example, :permissions_required, :see_also
      @resource_metadata[:matchers].push opts.dup
    end

    def filter_criterion(opts = {})
      return if opts[:name].nil?
      # :name, :type, :description, :example, :permissions_required, :see_also
      @resource_metadata[:filter_criteria].push opts.dup
    end

    def __resource_registry
      Inspec::Resource.registry
    end

    def __register(name, obj) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
      cl = Class.new(obj) do # rubocop:disable Metrics/BlockLength
        attr_reader :resource_exception_message

        def initialize(backend, name, *args)
          @resource_skipped = false
          @resource_failed = false
          @supports = Inspec::Resource.supports[name]

          # attach the backend to this instance
          @__backend_runner__ = backend
          @__resource_name__ = name

          # check resource supports
          supported = true
          supported = check_supports unless @supports.nil?
          test_backend = defined?(Train::Transports::Mock::Connection) && backend.backend.class == Train::Transports::Mock::Connection
          # do not return if we are supported, or for tests
          return unless supported || test_backend

          # call the resource initializer
          begin
            super(*args)
          rescue Inspec::Exceptions::ResourceSkipped => e
            skip_resource(e.message)
          rescue Inspec::Exceptions::ResourceFailed => e
            fail_resource(e.message)
          rescue NoMethodError => e
            # The new platform resources have methods generated on the fly
            # for inspec check to work we need to skip these train errors
            raise unless test_backend && e.receiver.class == Train::Transports::Mock::Connection
            skip_resource(e.message)
          end
        end

        def self.desc(description = nil)
          return @description if description.nil?
          @description = description
        end

        def self.example(example = nil)
          return @example if example.nil?
          @example = example
        end



        def check_supports
          status = inspec.platform.supported?(@supports)
          skip_msg = "Resource #{@__resource_name__.capitalize} is not supported on platform #{inspec.platform.name}/#{inspec.platform.release}."
          skip_resource(skip_msg) unless status
          status
        end

        def skip_resource(message)
          @resource_skipped = true
          @resource_exception_message = message
        end

        def resource_skipped?
          @resource_skipped
        end

        def fail_resource(message)
          @resource_failed = true
          @resource_exception_message = message
        end

        def resource_failed?
          @resource_failed
        end

        def resource_metadata
          @resource_metadata
        end

        def inspec
          @__backend_runner__
        end
      end

      # rubocop:enable Lint/NestedMethodDefinition
      if __resource_registry.key?(name)
        Inspec::Log.warn("Overwriting resource #{name}. To reference a specific version of #{name} use the resource() method")
      end
      __resource_registry[name] = cl
    end
  end

  module Plugins
    class Resource
      extend Inspec::ResourceDSL
      include Inspec::ResourceBehaviors
    end
  end
end
