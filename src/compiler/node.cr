module Lucid::Compiler
  abstract class Node
    property loc : Location

    def initialize
      @loc = Location[0, 0]
    end

    def at(@loc : Location) : self
      self
    end
  end

  class Nop < Node
  end

  class Var < Node
    property name : String
    property type : String?
    property value : Node?

    def initialize(@name : String, @type : String?, @value : Node?)
      super() # needs investigating
    end

    def uninitialized? : Bool
      !@type.nil? && @value.nil?
    end
  end

  class Prefix < Node
    enum Kind
      Plus        # +
      Minus       # -
      Splat       # *
      DoubleSplat # **

      def self.from(value : String)
        case value
        when "+"  then Plus
        when "-"  then Minus
        when "*"  then Splat
        when "**" then DoubleSplat
        else
          raise "invalid prefix operator '#{value}'"
        end
      end
    end

    property op : Kind
    property value : Node

    def initialize(op : String, @value : Node)
      @op = Kind.from op
      super()
    end
  end

  class Infix < Node
    enum Kind
      Add      # +
      Subtract # -
      Multiply # *
      Divide   # /
      DivFloor # //
      Power    # **

      def self.from(value : String)
        case value
        when "+"  then Add
        when "-"  then Subtract
        when "*"  then Multiply
        when "/"  then Divide
        when "//" then DivFloor
        when "**" then Power
        else
          raise "invalid infix operator '#{value}'"
        end
      end
    end

    property op : Kind
    property left : Node
    property right : Node

    def initialize(op : String, @left : Node, @right : Node)
      @op = Kind.from op
      super()
    end
  end

  class Assign < Node
    property name : String
    property value : Node

    def initialize(@name : String, @value : Node)
      super()
    end
  end

  class Call < Node
    property name : String
    property args : Array(Node)

    def initialize(@name : String, @args : Array(Node))
      super()
    end
  end

  class StringLiteral < Node
    property value : String

    def initialize(@value : String)
      super()
    end
  end

  class IntLiteral < Node
    property raw : String
    property value : Int64

    def initialize(@raw : String)
      super()
      @value = @raw.to_i64 strict: false
    end
  end

  class FloatLiteral < Node
    property raw : String
    property value : Float64

    def initialize(@raw : String)
      super()
      @value = @raw.to_f64 strict: false
    end
  end

  class NilLiteral < Node
  end
end
