# encoding: utf-8

require 'resources/azure/azure_backend'
require 'utils/filter'

module Inspec::Resources
  class AzureGenericResource < AzureResourceBase
    name 'azure_generic_resource'

    desc '
      Inspec Resource to interrogate any Resource type in Azure
    '

    supports platform: 'azure'

    attr_accessor :filter, :total, :counts, :name, :type, :location, :probes

    def initialize(opts = {})
      super(opts)

      create_resource_group_methods
      create_resource_methods
      create_tag_methods
    end

    @filter = FilterTable.create
      .add_accessor(:count)
      .add_accessor(:entries)
      .add_accessor(:where)
      .add_accessor(:contains)
      .add(:exist?, field: 'exist?')
      .add(:type, field: 'type')
      .add(:name, field: 'name')
      .add(:location, field: 'location')
      .add(:properties, field: 'properties')
      .connect(self, :probes)
  end
end
