# Documentation consistency and migration tasks for resources

require 'commonmarker'
require 'octokit'
require 'yaml'
require 'set'

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

  Gripe = Struct.new(:severity, :location, :message, :peeve_name)

  class Peeve
    attr_reader :name
    attr_reader :checker
    attr_reader :message
    attr_accessor :gripes
    attr_accessor :whole_doc

    def initialize(name, whole_doc, checker, message)
      @name = name
      @checker = checker
      @whole_doc = whole_doc
      @message = message
      @gripes = []
    end

    def check(doc)
      if whole_doc
        checker.call(self, doc)
      else
        doc.doc.walk do |node|
          checker.call(self, node)
        end
      end
      gripes
    end

    def add_gripe(node, severity=:fail, msg=nil)
      loc = unpack_location(node)
      msg ||= message
      @gripes << Gripe.new(severity, loc, msg, name)
    end

    private
    def unpack_location(node)
      pos = node.sourcepos
      "#{pos[:start_line]}:#{pos[:start_column]}-#{pos[:end_line]}:#{pos[:end_column]}"
    end
  end

  class WhingeOMatic
    attr_reader :peeves
    attr_reader :gripes
    def initialize
      @peeves = []
      @gripes = []
    end

    def load_peeves
      peeves << Peeve.new(
        'UnescapedUnderScoreInHeading',
        false,
        ->(peeve, node) do
          return [] unless node.type == :header
          if node.each do |header_text_node|
            header_text_node.type == :text and
            header_text_node.string_content =~ /[^\\]_/
          end then
            peeve.add_gripe(header_text_node,:warn)
          end
        end,
        'Underscores in headings must be escaped',
      )

      peeves << Peeve.new(
        'MartianSectionNames',
        true,
        ->(peeve, rdoc) do
          allowed_section_names = [
            'Syntax',
            'Properties',
            'Matchers',
            'Limitations',
            'Examples',
            'Resource Parameters',
          ]
          rdoc.find_sections('.*', 2).each do |header_node|
            text = header_node.to_plaintext.gsub("\n", '')
            # Skip metadata-in-docs garbage
            next if text =~ /^title: About/
            next if text =~ /platform:/
            unless allowed_section_names.include?(text)
              peeve.add_gripe(header_node, :warn, "Unrecognized level 2 header '#{text}'")
            end
          end
        end,
        'Unrecognized level 2 header',
      )

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
    # by doc, by peeve, gripes, by field
    results = {}
    Dir.glob('docs/resources/*.md.erb').sort.each do |md_file|
      resource_doc = Orthodoxy::ResourceDoc.new(md_file)
      doc_results = {}

      whinger = Orthodoxy::WhingeOMatic.new
      whinger.load_peeves # TODO filter here
      whinger.peeves.each do |peeve|
        gripe_results = peeve.check(resource_doc).map(&:to_h)
        doc_results[peeve.name] = gripe_results unless gripe_results.empty?
      end
      results[resource_doc.name] = doc_results unless doc_results.empty?
    end
    puts({ 'whinge' => results }.to_yaml)
  end

  desc 'Search markdown files and emit YAML'
  task :extract do
  end
end
