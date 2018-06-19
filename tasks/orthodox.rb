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

  class ResourceDoc

    attr_reader :doc, :name

    def initialize(path)
      @name = path.split('/').last.split('.').first
      @doc = CommonMarker.render_doc(File.read(path))
    end

    def find_sections(name, level = :any)
      matches = []
      doc.walk do |header_node|
        next unless header_node.type == :header
        next if level != :any and header_node.header_level != level
        if header_node.any? do |header_text_node|
          header_text_node.type == :text and
          header_text_node.string_content =~ Regexp.new(name)
        end then
          matches.push header_node
        end
      end
      matches
    end
  end
end

namespace :orthodox do
  task main: [:since, :whinge, :extract]

  desc 'Examine each resource file and determine its version marker'
  task :since do
    puts "since:"
    Dir.glob('docs/resources/*.md.erb').sort.each do |md_file|
      resource_doc = Orthodoxy::ResourceDoc.new(md_file)
      puts "  #{resource_doc.name}:"

      # Determine release that the file appearred in, if any.

      # Find commit hash in which a file was added
      commit = `git log --follow --diff-filter=A --format=format:%h #{md_file} 2> /dev/null`
      unless $?.success?
        puts "    first_released_in: unknown"
        next
      end

      # Lists all tags that contain the commit, including CI releases. Chronological order
      tags = `git tag --list '*.*.*' --contains #{commit} 2>/dev/null`.split("\n")
      if !$?.success? or tags.empty?
        puts "    first_released_in: unknown"
        next
      end

      # Filter out the CI tags, to get the releases.
      first_released_in = Orthodoxy::Releases.filter_tags(tags).first
      puts "    first_released_in: #{first_released_in}"

      # Examine markdown file to check for an Availability section
      # require 'byebug'; byebug
      availability_sec = resource_doc.find_sections('Availability', 2).first
      if availability_sec.nil?
        # TODO: inject availability section
        puts "    availability_section: no"
        next
      end
      puts "    availability_section: yes"
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
