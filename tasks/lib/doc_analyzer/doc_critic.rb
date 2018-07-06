# Classes to analyze docs and report style / structural violations

module DocAnalyzer
  Violation = Struct.new(:severity, :location, :message, :peeve_name)

  class Rule
    attr_reader :name
    attr_reader :checker
    attr_reader :message
    attr_accessor :violations
    attr_accessor :whole_doc

    def initialize(name, whole_doc, checker, message)
      @name = name
      @checker = checker
      @whole_doc = whole_doc
      @message = message
      @violations = []
    end

    def check(doc)
      if whole_doc
        checker.call(self, doc)
      else
        doc.doc.walk do |node|
          checker.call(self, node)
        end
      end
      violations
    end

    def add_violation(node, severity=:fail, msg=nil)
      loc = unpack_location(node)
      msg ||= message
      @violations << Violation.new(severity, loc, msg, name)
    end

    private
    def unpack_location(node)
      pos = node.sourcepos
      "#{pos[:start_line]}:#{pos[:start_column]}-#{pos[:end_line]}:#{pos[:end_column]}"
    end
  end

  class Critic
    attr_reader :rules
    attr_reader :violations
    def initialize
      @rules = []
      @violations = []
    end

    def load_rules
      rules << Rule.new(
        'UnescapedUnderScoreInHeading',
        false,
        ->(rule, node) do
          return [] unless node.type == :header
          if node.each do |header_text_node|
            header_text_node.type == :text and
            header_text_node.string_content =~ /[^\\]_/
          end then
            rule.add_violation(header_text_node,:warn)
          end
        end,
        'Underscores in headings must be escaped',
      )

      rules << Rule.new(
        'MartianSectionNames',
        true,
        ->(rule, mdoc) do
          allowed_section_names = [
            'Syntax',
            'Properties',
            'Matchers',
            'Limitations',
            'Examples',
            'Resource Parameters',
          ]
          mdoc.find_sections('.*', 2).each do |header_node|
            text = header_node.to_plaintext.gsub("\n", '')
            # Skip metadata-in-docs garbage
            next if text =~ /^title: About/
            next if text =~ /platform:/
            unless allowed_section_names.include?(text)
              rule.add_violation(header_node, :warn, "Unrecognized level 2 header '#{text}'")
            end
          end
        end,
        'Unrecognized level 2 header',
      )
    end
  end
end
