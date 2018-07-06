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

    # If 'node' is a L3 header, this searches back until it finds
    # the previous L2 header (if any).  To humans, this looks like
    # the L3 is "in" the L2, but it isn't markdown-wise.
    def previous_higher_level_header(node)
      higher_header = nil
      orig_level = node.header_level
      cursor = node
      while cursor = cursor.previous do
        next unless cursor.type == :header
        higher_header = cursor if cursor.header_level < orig_level
        break if higher_header
      end
      higher_header
    end

    # If node is a L2 header, this lists all L3 headers until we
    # hit another L2 header, or hit the end of the doc.
    def following_lower_level_headers(node)
      lower_headers = []
      orig_level = node.header_level
      cursor = node
      while cursor = cursor.next do
        next unless cursor.type == :header
        break if cursor.header_level < orig_level
        lower_headers << cursor if cursor.header_level == orig_level + 1
      end
      lower_headers
    end

  end
end
