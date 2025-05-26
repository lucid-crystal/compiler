module Lucid
  class HelpCommand < Command
    def setup : Nil
      @name = "help"
      @summary = "get help information"

      add_argument "command"
    end

    def run(arguments : Cling::Arguments, options : Cling::Options) : Nil
      main = parent.as(Cling::Command)
      command = arguments.get?("command").try &.as_s

      if command && command != "help"
        main.execute [command, "--help"]
      else
        main.run arguments, options
      end
    end
  end
end
