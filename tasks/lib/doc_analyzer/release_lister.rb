
# Utility class to work with github releases

require 'octokit'

module DocAnalyzer
  class ReleaseLister

    attr_reader :all_releases, :repo, :working_dir

    def initialize(repo = 'inspec/inspec', working_dir = '.')
      @repo = repo
      @working_dir = working_dir
      @all_releases ||= fetch_all_releases
    end

    def filter_tags(tag_list)
      tag_list.select { |tag| all_releases.include?(tag) }
    end

    private
    def fetch_all_releases
      # Provide authentication credentials
      Octokit.configure do |c|
        c.netrc = true
        c.auto_paginate = true
      end

      # This returns the releases in reverse chronological order
      # So, there will be a mix of 1.x and 2.x, though each series will decrease
      Octokit.releases(repo).map(&:tag_name)
    end
  end
end