# Documentation consistency and migration tasks for resources

require_relative 'lib/doc_analyzer'
require 'yaml'

namespace :doc_analyze do
  task main: [:since, :critic, :extract]

  desc 'Examine each resource file and determine its version marker'
  task :since do
    release_lister = DocAnalyzer::ReleaseLister.new
    puts "since:"
    Dir.glob('docs/resources/*.md.erb').sort.each do |md_file|
      resource_doc = DocAnalyzer::MarkdownDoc.new(md_file)
      puts "  #{resource_doc.name}:"

      release = release_lister.earliest_release_containing_file(md_file)
      puts "    first_released_in: " + (release ? release : 'unknown')
      next unless release

      # Examine markdown file to check for an Availability section
      availability_sec = resource_doc.find_sections('Availability', 2).first
      # TODO: detect level 3 Version section within Availability section
      # TODO: verify value in text
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
