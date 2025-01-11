module Lucid::Compiler
  class Location
    # start       end
    # line:column-line:column
    @value : StaticArray(Int32, 4)

    def self.[](start_line : Int32, start_column : Int32, end_line : Int32, end_column : Int32)
      new StaticArray[start_line, start_column, end_line, end_column]
    end

    def initialize(@value : StaticArray(Int32, 4))
    end

    def start : {Int32, Int32}
      {@value[0], @value[1]}
    end

    def end : {Int32, Int32}
      {@value[2], @value[3]}
    end

    def to_tuple : {Int32, Int32, Int32, Int32}
      {@value[0], @value[1], @value[2], @value[3]}
    end

    # :nodoc:
    def end_at(line : Int32, column : Int32) : Nil
      @value[2], @value[3] = line, column
    end

    def &(other : Location) : Location
      line, column = other.end

      Location.new StaticArray[@value[0], @value[1], line, column]
    end
  end
end
