# Documentation consistency and migration tasks for resources

require_relative 'lib/doc_analyzer'
require 'yaml'

namespace :doc_analyze do
  task main: [:since, :critic, :extract]

  desc 'Examine each resource file and determine its version marker'
  task :since do
    puts "since:"
    Dir.glob('docs/resources/*.md.erb').sort.each do |md_file|
      resource_doc = DocAnalyzer::MarkdownDoc.new(md_file)
      puts "  #{resource_doc.name}:"

      # Determine release that the file appeared in, if any.

      # TODO: move this to the release analzyer lib
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
      first_released_in = DocAnalyzer::Releases.filter_tags(tags).first
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
  task :critic do
    # by doc, by rule, violations, by field
    results = {}
    Dir.glob('docs/resources/*.md.erb').sort.each do |md_file|
      resource_doc = DocAnalyzer::MarkdownDoc.new(md_file)
      doc_results = {}

      critic = DocAnalyzer::Critic.new
      critic.load_rules # TODO filter here
      critic.rules.each do |rule|
        violation_results = rule.check(resource_doc).map(&:to_h)
        doc_results[rule.name] = violation_results unless violation_results.empty?
      end
      results[resource_doc.name] = doc_results unless doc_results.empty?
    end
    puts({ 'critic' => results }.to_yaml)
  end

  desc 'Search markdown files and emit YAML'
  task :extract do
  end
end
