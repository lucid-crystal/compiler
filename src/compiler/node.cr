module Compiler
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
    property value : Int64

    def initialize(@value : Int64)
      super()
    end
  end

  class FloatLiteral < Node
    property value : Float64

    def initialize(@value : Float64)
      super()
    end
  end
end
