require 'cucumber/step_match'
require 'cucumber/core_ext/string'
require 'cucumber/core_ext/proc'
require 'cucumber/s18t'

module Cucumber
  module StepDefinitionMethods
    def step_match(name_to_match, name_to_report)
      match, is_negative = match_negative(name_to_match)
      if match
        if name_to_match =~ /should not/
          require 'ruby-debug'
          debugger
        end
        StepMatch.new(self, name_to_match, name_to_report, match.captures, is_negative)
      else
        nil
      end
    end

    # if it includes negative, sub it out and look for positives
    def match_negative(name_to_match)
      # if this step is already negative, we don't want to ruin the step match
      if regexp.to_s =~ /should not/
        [name_to_match.match(regexp), false]
      else
        new_name_to_match = name_to_match.gsub(/should not/, "should")
        [new_name_to_match.match(regexp), new_name_to_match != name_to_match]
      end
    end
    # Formats the matched arguments of the associated Step. This method
    # is usually called from visitors, which render output.
    #
    # The +format+ can either be a String or a Proc.
    #
    # If it is a String it should be a format string according to
    # <tt>Kernel#sprinf</tt>, for example:
    #
    #   '<span class="param">%s</span></tt>'
    #
    # If it is a Proc, it should take one argument and return the formatted
    # argument, for example:
    #
    #   lambda { |param| "[#{param}]" }
    #
    def format_args(step_name, format)
      if regexp.to_s =~ /should not/
        step_name.gzub(regexp, format)
      else
        # THIS DOES NOT WORK => outputs the positive version every time...
        step_name.gzub(Regexp.new(regexp.to_s.gsub(/should/, "should not"), format)
      end
    end

    def match(step_name)
      case step_name
      when String then regexp.match(step_name)
      when Regexp then regexp == step_name
      end
    end

    def backtrace_line
      "#{file_colon_line}:in `#{regexp.inspect}'"
    end

    def text_length
      regexp.inspect.jlength
    end
  end
  
  # A Step Definition holds a Regexp and a Proc, and is created
  # by calling <tt>Given</tt>, <tt>When</tt> or <tt>Then</tt>
  # in the <tt>step_definitions</tt> ruby files - for example:
  #
  #   Given /I have (\d+) cucumbers in my belly/ do
  #     # some code here
  #   end
  #
  class StepDefinition
    PARAM_PATTERN = /"([^\"]*)"/
    ESCAPED_PARAM_PATTERN = '"([^\\"]*)"'
    
    def self.snippet_text(step_keyword, step_name, multiline_arg_class = nil)
      escaped = Regexp.escape(step_name).gsub('\ ', ' ').gsub('/', '\/')
      escaped = escaped.gsub(PARAM_PATTERN, ESCAPED_PARAM_PATTERN)

      n = 0
      block_args = escaped.scan(ESCAPED_PARAM_PATTERN).map do |a|
        n += 1
        "arg#{n}"
      end
      block_args << multiline_arg_class.default_arg_name unless multiline_arg_class.nil?
      block_arg_string = block_args.empty? ? "" : " |#{block_args.join(", ")}|"
      multiline_class_string = multiline_arg_class ? "# #{multiline_arg_class.default_arg_name} is a #{multiline_arg_class.to_s}\n  " : ""

      "#{step_keyword} /^#{escaped}$/ do#{block_arg_string}\n  #{multiline_class_string}pending\nend"
    end

    class MissingProc < StandardError
      def message
        "Step definitions must always have a proc"
      end
    end

    include StepDefinitionMethods

    def initialize(pattern, &proc)
      raise MissingProc if proc.nil?
      if String === pattern
        p = pattern.gsub(/\$\w+/, '(.*)') # Replace $var with (.*)
        pattern = Regexp.new("^#{p}$") 
      end
      @regexp, @proc = pattern, proc
    end

    def regexp
      @regexp
    end

    def invoke(world, args, is_negative)
      args = args.map{|arg| Ast::PyString === arg ? arg.to_s : arg}
      begin
        is_negative ? S18tHelper.instance.is_negative : S18tHelper.instance.is_positive
        world.cucumber_instance_exec(true, regexp.inspect, *args, &@proc)
      rescue Cucumber::ArityMismatchError => e
        e.backtrace.unshift(self.backtrace_line)
        raise e
      end
    end

    def file_colon_line
      @proc.file_colon_line
    end
  end
end
