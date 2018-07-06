
# Utility class to work with github releases

require 'octokit'

module DocAnalyzer
  class Releases
    def self.all
      @all_releases ||= fetch_all_releases
    end

    def self.filter_tags(tag_list)
      tag_list.select { |tag| all.include?(tag) }
    end

    private
    def self.fetch_all_releases
      # Provide authentication credentials
      Octokit.configure do |c|
        c.netrc = true
        c.auto_paginate = true
      end

      # This returns the releases in reverse chronological order
      # So, there will be a mix of 1.x and 2.x, though each series will decrease
      Octokit.releases('inspec/inspec').map(&:tag_name)
    end
  end
end