module Lucid
  class REPLCommand < Command
    WORD_DELIMITERS = [
      ' ', '\n', '\t', '+', '-',
      '*', '/', ',', ';', '@',
      '&', '%', '<', '>', '^',
      '\\', '[', ']', '(', ')',
      '{', '}', '|', '.', '~',
    ]

    def setup : Nil
      @name = "repl"
      @summary = @description = "An interactive REPL for analysis"

      add_option 'm', "mode", type: :single, default: "nodes"
    end

    def pre_run(arguments : Cling::Arguments, options : Cling::Options) : Nil
      mode = options.get("mode").as_s
      unless mode.in?("tokens", "nodes")
        STDERR.puts "invalid parsing mode (tokens, nodes)"
        exit_program 1
      end
    end

    def run(arguments : Cling::Arguments, options : Cling::Options) : Nil
      reader = LucidReader.new
      reader.word_delimiters = WORD_DELIMITERS
      parse_nodes = options.get("mode").as_s == "nodes"

      reader.read_loop do |expression|
        case expression
        when "exit"
          break
        when .presence
          results = Lucid::Compiler::Lexer.run expression
          if parse_nodes
            program = Lucid::Compiler::Parser.parse results
            results = program.nodes
          end

          print "=> "
          pp results[0]
          # str = String.build do |io|
          #   PrettyPrint.format results[0], io, 79
          # end
          # puts Crystal::SyntaxHighlighter::Colorize.highlight! str

          if results.size > 1
            results.skip(1).each do |result|
              print "   "
              pp result
            end
          end
          puts
        end
      rescue ex
        puts "Error: #{ex.message}".colorize.red
        ex.backtrace
          .as(Array(String))
          .take_while(&.includes?("'parse'").!)
          .each do |line|
            STDOUT << "  " << line << '\n'
          end
        puts
      end
    end
  end

  private class LucidReader < Reply::Reader
    CONTINUE_ERRORS = [
      "unterminated percent literal",
      "unterminated quote literal",
    ]

    @incomplete : Bool = false

    def prompt(io : IO, line_number : Int32, color : Bool) : Nil
      io << "lcc:" << line_number
      if @incomplete
        io << "* "
      else
        io << "> "
      end
    end

    def continue?(expression : String) : Bool
      tokens = Lucid::Compiler::Lexer.run expression
      Lucid::Compiler::Parser.parse tokens, fail_first: true
      @incomplete = false
    rescue ex
      @incomplete = ex.message.in? CONTINUE_ERRORS
    end

    def format(expression : String) : String?
      Crystal.format(expression).chomp rescue nil
    end

    def highlight(expression : String) : String
      Crystal::SyntaxHighlighter::Colorize.highlight!(expression)
    end

    def reindent_line(line : String) : Int32?
      case line.strip
      when "end", ")", "]", "}"
        0
      when "else", "elsif", "rescue", "ensure", "in", "when"
        -1
      else
        nil
      end
    end

    def save_in_history?(expression : String) : Bool
      !expression.blank?
    end
  end
end
