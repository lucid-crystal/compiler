module Lucid::Compiler
  class Location
    @value : StaticArray(Int32, 4)

    def self.[](line : Int32, column : Int32)
      new StaticArray[line, 0, column, 0]
    end

    def initialize(@value : StaticArray(Int32, 4))
    end

    def line : {Int32, Int32}
      {@value[0], @value[1]}
    end

    def column : {Int32, Int32}
      {@value[2], @value[3]}
    end

    def increment_column_start : Nil
      @value[2] += 1
    end

    def line_end_at(value : Int32) : Nil
      @value[1] = value
    end

    def column_end_at(value : Int32) : Nil
      @value[3] = value
    end
  end
end
