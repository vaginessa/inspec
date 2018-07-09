# Class to represent and analyze a parsed Markdown file

require 'commonmarker'

module DocAnalyzer
  class MarkdownDoc

    attr_reader :doc, :name, :orig_content

    def initialize(path)
      @name = path.split('/').last.split('.').first
      @orig_content = File.read(path)
      @doc = CommonMarker.render_doc(orig_content)
      scrub_metadata_garbage
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

    def find_first_section(*header_names)
      first_header = nil
      header_names.each do |header_name|
        header = find_sections(header_name).first
        next unless header
        first_header ||= header
        first_header = header if header.sourcepos[:start_line] < first_header.sourcepos[:start_line]
      end
      first_header
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

    def inject_fragment_before(fragment, node)
      doc_fragment = CommonMarker.render_doc(fragment)
      source_cursor = doc_fragment.last_child
      target_cursor = node
      while source_cursor do
        # Must not perform the insertion on the cursor - it will get its pointers
        # updated to point into the target doc.  So, grab a copy of the cursor,
        # then advance it, then do the insert.
        inserter = source_cursor
        source_cursor = source_cursor.previous
        target_cursor.insert_before(inserter)
        target_cursor = target_cursor.previous
      end
    end

    # We need a special write, because we insert non-md garbage metadata at the top of the file.
    def write(path)
      # ---
      # title: About the google_container_node_pool Resource
      # platform: gcp
      # ---
      match = orig_content.match(/(---\ntitle:.+\nplatform:.+\n---\n)/m)
      unless match
        warn "WARN: refusing to write #{path}, could not find metadata block"
        return
      end
      metadata = match[1]
      rendered_markdown = doc.to_commonmark
      File.write(path, metadata + "\n" + rendered_markdown)
    end

    private
    def scrub_metadata_garbage
      # The metadata block typically gets turned into a horizontal rule and a level two header
      hr = doc.first_child
      if hr.type == :hrule
        hr.delete
      end

      l2 = find_sections('^title:', 2).first
      l2.delete if l2

    end
  end
end
