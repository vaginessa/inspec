# Class to represent and analyze a parsed Markdown file

require 'commonmarker'

module DocAnalyzer
  class MarkdownDoc

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
