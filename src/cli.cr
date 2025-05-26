require "compiler/crystal/tools/formatter"
require "crystal/syntax_highlighter/colorize"

require "cling"
require "colorize"
require "reply"

require "./compiler"
require "./cli/*"

module Lucid
  class App < Command
    def setup : Nil
      @name = "lcc"
      @description = "Parsing and analysis tools for Crystal Language."

      add_command HelpCommand.new
      add_command REPLCommand.new
    end

    def run(arguments : Cling::Arguments, options : Cling::Options) : Nil
      puts help_template
    end
  end
end

Lucid::App.new.execute ARGV
