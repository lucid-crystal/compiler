module Lucid
  abstract class Command < Cling::Command
    def initialize
      super

      @inherit_options = true
      add_option "no-color", description: "disable ansi color formatting"
      add_option 'h', "help", description: "get help information"
    end

    def help_template : String
      String.build do |io|
        io << "Lucid Crystal ".colorize.blue.bold
        io << "Compiler\n\n".colorize.magenta.bold
        io << @description << "\n\n"

        unless @children.empty?
          io << "Comamnds\n".colorize.bold
          max_size = 4 + @children.keys.max_of &.size

          @children.each do |name, command|
            io << "- " << name
            io << " " * (max_size - name.size)
            io << command.summary << '\n'
          end

          io << '\n'
        end

        io << "Options\n".colorize.bold
        max_size = 4 + @options.each.max_of { |name, opt| name.size + (opt.short ? 2 : 0) }

        @options.each do |name, option|
          if short = option.short
            io << '-' << short << ", "
          end
          io << "--" << name

          if desc = option.description
            name_size = name.size + (option.short ? 4 : 0)
            io << " " * (max_size - name_size)
            io << desc
          end
          io << '\n'
        end
        io << '\n'
      end
    end

    def pre_run(arguments : Cling::Arguments, options : Cling::Options) : Nil
      @debug = true if options.has? "debug"
      Colorize.enabled = false if options.has? "no-color"

      if options.has? "help"
        stdout.puts help_template
        exit_program 0
      end
    end

    def on_error(ex : Exception) : Nil
      if ex.is_a? Cling::CommandError
        stderr << "Error: ".colorize.red << ex.message << '\n'
        stderr.puts "See 'lcc help' for more information"
      else
        stderr.puts "Unexpected exception:".colorize.red
        stderr.puts ex
        stderr.puts "Please report this on the Lucid Compiler GitHub:"
        stderr.puts "https://github.com/lucid-crystal/compiler/issues"
      end

      exit_program
    end

    def on_unknown_arguments(args : Array(String)) : Nil
      stderr.puts %(#{"Error:".colorize.red} unexpected arguments: #{args.join ", "})
      exit_program
    end

    def on_unknown_options(options : Array(String)) : Nil
      stderr.puts %(#{"Error:".colorize.red} unexpected options: #{options.join ", "})
      exit_program
    end
  end
end
