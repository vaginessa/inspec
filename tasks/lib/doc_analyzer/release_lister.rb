
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

    # Returns array of tags, in chronological order,
    # that contains the named file.  If none or indeterminable,
    # returns empty array.
    def tags_containing_file(file)

      # Find commit hash in which a file was added
      # The git rubygem approach doesn't actuall allow filtering or following as of v1.4.0
      # commit = git.log.path(file).last
      commit = `git log --follow --diff-filter=A --format=format:%h #{file} 2> /dev/null`
      return [] unless $?.success?

      # git gem can't do --contains
      # Lists all tags that contain the commit, including CI releases. Chronological order
      tags = `git tag --list '*.*.*' --contains #{commit} 2>/dev/null`.split("\n")
      return [] unless $?.success?
      tags
    end

    def earliest_release_containing_file(file)
      tags = tags_containing_file(file)
      first_released_in = filter_tags(tags).first
    end

    private
    def fetch_all_releases
      # Provide authentication credentials
      Octokit.configure do |c|
        c.netrc = true
        c.auto_paginate = true
      end

      # This returns the release tags in reverse chronological order
      # So, there will be a mix of 1.x and 2.x, though each series will decrease
      release_tags = Octokit.releases(repo).map(&:tag_name)
      if release_tags.empty?
        # If there are no official releases, it may not be connected to CI
        # So, tags would be the closest thing.
        release_tags = Octokit.tags(repo).map(&:name)
      end
      release_tags
    end
  end
end