module Lucid::Compiler
  abstract class Node
    property loc : Location

    def initialize
      @loc = Location[0, 0]
    end

    def at(@loc : Location) : self
      self
    end

    abstract def to_s(io : IO) : Nil
    abstract def inspect(io : IO) : Nil
  end

  class Path < Node
    property names : Array(Ident)
    property? global : Bool

    def initialize(@names : Array(Ident), @global : Bool)
      super()
    end

    def to_s(io : IO) : Nil
      @names.each do |name|
        case name
        in Const
          io << "::" if name.global?
          io << name
        in Ident
          io << "::" if name.global?
          io << '.' << name
        end
      end
    end

    def inspect(io : IO) : Nil
      io << "Path(names: "
      io << @names << ", global: "
      io << @global << ')'
    end
  end

  class Ident < Node
    property value : String
    property? global : Bool

    def initialize(@value : String, @global : Bool)
      super()
    end

    def to_s(io : IO) : Nil
      io << @value
    end

    def inspect(io : IO) : Nil
      io << "Ident(value: "
      @value.inspect io
      io << ", global: "
      io << @global << ')'
    end
  end

  class Const < Ident
    def inspect(io : IO) : Nil
      io << "Const(value: "
      @value.inspect io
      io << ", global: "
      io << @global << ')'
    end
  end

  class Var < Node
    property name : Node
    property type : Node?
    property value : Node?

    def initialize(@name : Node, @type : Node?, @value : Node?)
      super() # needs investigating
    end

    def uninitialized? : Bool
      @value.nil?
    end

    def to_s(io : IO) : Nil
      io << @name
      if @type
        io << " : " << @type
      end

      if @value
        io << " = " << @value
      end
    end

    def inspect(io : IO) : Nil
      io << "Var(name: "
      @name.inspect io
      io << ", type: "
      @type.inspect io
      io << ", value: "
      @value.inspect io
      io << ')'
    end
  end

  class InstanceVar < Var
  end

  class ClassVar < Var
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

      def to_s : String
        case self
        in Plus        then "+"
        in Minus       then "-"
        in Splat       then "*"
        in DoubleSplat then "**"
        end
      end
    end

    property op : Kind
    property value : Node

    def initialize(op : String, @value : Node)
      @op = Kind.from op
      super()
    end

    def to_s(io : IO) : Nil
      io << @op << @value
    end

    def inspect(io : IO) : Nil
      io << "Prefix(op: '" << @op
      io << "', value: "
      @value.inspect io
      io << ')'
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

      def to_s : String
        case self
        in Add      then "+"
        in Subtract then "-"
        in Multiply then "*"
        in Divide   then "/"
        in DivFloor then "//"
        in Power    then "**"
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

    def to_s(io : IO) : Nil
      io << @left << ' ' << @op << ' ' << @right
    end

    def inspect(io : IO) : Nil
      io << "Infix(left: "
      @left.inspect io
      io << ", op: "
      @op.inspect io
      io << ", right: "
      @right.inspect io
      io << ')'
    end
  end

  class Assign < Node
    property target : Node
    property value : Node

    def initialize(@target : Node, @value : Node)
      super()
    end

    def to_s(io : IO) : Nil
      io << @target << " = " << @value
    end

    def inspect(io : IO) : Nil
      io << "Assign(target: "
      @target.inspect io
      io << ", value: "
      @value.inspect io
      io << ')'
    end
  end

  class Call < Node
    property receiver : Node
    property args : Array(Node)

    def initialize(@receiver : Node, @args : Array(Node))
      super()
    end

    def to_s(io : IO) : Nil
      io << @receiver << '('
      @args.join(io, ", ") unless @args.empty?
      io << ')'
    end

    def inspect(io : IO) : Nil
      io << "Call(receiver: "
      @receiver.inspect io
      io << ", args: "
      @args.inspect io
      io << ')'
    end
  end

  class StringLiteral < Node
    property value : String

    def initialize(@value : String)
      super()
    end

    def to_s(io : IO) : Nil
      @value.inspect io
    end

    def inspect(io : IO) : Nil
      io << "StringLiteral("
      @value.inspect io
      io << ')'
    end
  end

  class IntLiteral < Node
    property raw : String
    property value : Int64

    def initialize(@raw : String)
      super()
      @value = @raw.to_i64 strict: false
    end

    def to_s(io : IO) : Nil
      io << @value
    end

    def inspect(io : IO) : Nil
      io << "IntLiteral("
      @value.inspect io
      io << ')'
    end
  end

  class FloatLiteral < Node
    property raw : String
    property value : Float64

    def initialize(@raw : String)
      super()
      @value = @raw.to_f64 strict: false
    end

    def to_s(io : IO) : Nil
      io << @value
    end

    def inspect(io : IO) : Nil
      io << "FloatLiteral("
      @value.inspect io
      io << ')'
    end
  end

  class NilLiteral < Node
    def to_s(io : IO) : Nil
      io << "nil"
    end

    def inspect(io : IO) : Nil
      io << "NilLiteral"
    end
  end
end
