# Documentation consistency and migration tasks for resources

require 'commonmarker'
require 'octokit'

module Orthodoxy
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

namespace :orthodox do
  task main: [:since, :whinge, :extract]

  desc 'Examine each resource file and determine its version marker'
  task :since do
    puts Dir.pwd
    Dir.glob('docs/resources/*.md.erb') do |md_file|
      # Determine release that the file appearred in, if any.

      # Find commit hash in which a file was added
      commit = `git log --follow --diff-filter=A --format=format:%h #{md_file} 2> /dev/null`
      next unless $?.success?

      # Lists all tags that contain the commit, including CI releases. Chronological order
      tags = `git tag --list '*.*.*' --contains #{commit} 2>/dev/null`.split("\n")
      next unless $?.success?
      next if tags.empty?
      # Filter out the CI tags, to get the releases.
      first_released_in = Orthodoxy::Releases.filter_tags(tags).first


      # TODO

    end
  end

  desc 'Look for things to complain about in each resource doc file'
  task :whinge do
    # List Files
    # Open and parse as markdown
    # Apply each rule to the markdown AST
    # summarize
  end

  desc 'Search markdown files and emit YAML'
  task :extract do
  end
end
