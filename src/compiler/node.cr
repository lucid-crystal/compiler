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
    abstract def pretty_print(pp : PrettyPrint) : Nil
  end

  abstract class Statement < Node
  end

  abstract class Expression < Node
  end

  class Def < Statement
    property name : Node
    property params : Array(Parameter)
    property return_type : Node?
    property body : Array(ExpressionStatement)

    def initialize(@name : Node, @params : Array(Parameter),
                   @return_type : Node?, @body : Array(ExpressionStatement))
      super()
    end

    def to_s(io : IO) : Nil
      io << "def " << @name
      unless @params.empty?
        io << '(' << @params[0]

        if @params.size > 1
          @params.each do |param|
            io << ", " << param
          end
        end

        io << ')'
      end

      if @return_type
        io << " : " << @return_type
      end

      io << '\n'
      @body.each do |expr|
        io << ' '
        expr.to_s io
      end
      io << "end"
    end

    def pretty_print(pp : PrettyPrint) : Nil
      pp.text "Def("
      pp.group 1 do
        pp.breakable ""
        pp.text "name: "
        @name.pretty_print pp
        pp.comma

        pp.text "params: ["
        pp.group 1 do
          pp.breakable ""
          next if @params.empty?

          @params[0].pretty_print pp
          if @params.size > 1
            @params.skip(1).each do |param|
              pp.comma
              param.pretty_print pp
            end
          end
        end
        pp.text "]"
        pp.comma

        pp.text "return_type: "
        @return_type.pretty_print pp
        pp.comma

        pp.text "body: ["
        pp.group 1 do
          pp.breakable ""
          next if @body.empty?

          @body[0].pretty_print pp
          if @body.size > 1
            @body.skip(1).each do |expr|
              pp.comma
              expr.pretty_print pp
            end
          end
        end
        pp.text "]"
      end
      pp.text ")"
    end
  end

  class Parameter < Node
    property name : Node
    property type : Node?
    property default_value : Node?
    property? block : Bool

    def initialize(@name : Node, @type : Node?, @default_value : Node?, @block : Bool)
      super()
    end

    def to_s(io : IO) : Nil
      io << '&' if @block
      io << @name
      if @type
        io << " : " << @type
      end
      if @default_value
        io << " = " << @default_value
      end
    end

    def pretty_print(pp : PrettyPrint) : Nil
      pp.text "Parameter("
      pp.group 1 do
        pp.breakable ""
        pp.text "name: "
        @name.pretty_print pp
        pp.comma

        pp.text "type: "
        @type.pretty_print pp
        pp.comma

        pp.text "default_value: "
        @default_value.pretty_print pp
        pp.comma

        pp.text "block: "
        pp.text @block
      end
      pp.text ")"
    end
  end

  class ExpressionStatement < Statement
    property value : Expression

    def initialize(@value : Expression)
      super()
    end

    def to_s(io : IO) : Nil
      io << '('
      @value.to_s io
      io << ')'
    end

    def pretty_print(pp : PrettyPrint) : Nil
      pp.text "ExpressionStatement("
      pp.group 1 do
        pp.breakable ""
        pp.nest { @value.pretty_print pp }
      end
      pp.text ")"
    end
  end

  class Path < Expression
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

    def pretty_print(pp : PrettyPrint) : Nil
      pp.text "Path("
      pp.group 1 do
        pp.breakable ""
        pp.text "names: ["
        pp.group 1 do
          pp.breakable ""
          next if @names.empty?

          @names[0].pretty_print pp
          if @names.size > 1
            @names.skip(1).each do |name|
              pp.comma
              name.pretty_print pp
            end
          end
        end
        pp.text "]"

        pp.comma
        pp.text "global: "
        pp.text @global
      end
      pp.text ")"
    end
  end

  class Ident < Expression
    property value : String
    property? global : Bool

    def initialize(@value : String, @global : Bool)
      super()
    end

    def to_s(io : IO) : Nil
      io << @value
    end

    def pretty_print(pp : PrettyPrint) : Nil
      pp.text "Ident("
      pp.group 1 do
        pp.breakable ""
        pp.text "value: "
        pp.text @value.inspect
        pp.comma

        pp.text "global: "
        pp.text @global
      end
      pp.text ")"
    end
  end

  class Const < Ident
    def pretty_print(pp : PrettyPrint) : Nil
      pp.text "Const("
      pp.group 1 do
        pp.breakable ""
        pp.text "value: "
        pp.text @value.inspect
        pp.comma

        pp.text "global: "
        pp.text @global
      end
      pp.text ")"
    end
  end

  class Var < Expression
    property name : Node
    property type : Node?
    property value : Node?

    def initialize(@name : Node, @type : Node?, @value : Node?)
      super()
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

    def pretty_print(pp : PrettyPrint) : Nil
      pp.text "Var("
      pp.group 1 do
        pp.breakable ""
        pp.text "name: "
        @name.pretty_print pp
        pp.comma

        pp.text "type: "
        @type.pretty_print pp
        pp.comma

        pp.text "value: "
        @value.pretty_print pp
      end
      pp.text ")"
    end
  end

  class InstanceVar < Var
  end

  class ClassVar < Var
  end

  class Prefix < Expression
    enum Operator
      Plus        # +
      Minus       # -
      Splat       # *
      DoubleSplat # **

      def self.from(kind : Token::Kind)
        case kind
        when .plus?        then Plus
        when .minus?       then Minus
        when .star?        then Splat
        when .double_star? then DoubleSplat
        else
          raise "invalid prefix operator '#{kind}'"
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

    property op : Operator
    property value : Node

    def initialize(@op : Operator, @value : Node)
      super()
    end

    def to_s(io : IO) : Nil
      io << @op << @value
    end

    def pretty_print(pp : PrettyPrint) : Nil
      pp.text "Prefix("
      pp.group 1 do
        pp.breakable ""
        pp.text "op: "
        pp.text @op
        pp.comma

        pp.text "value: "
        @value.pretty_print pp
      end
      pp.text ")"
    end
  end

  class Infix < Expression
    enum Operator
      Add      # +
      Subtract # -
      Multiply # *
      Divide   # /
      DivFloor # //
      Power    # **

      def self.from(kind : Token::Kind)
        case kind
        when .plus?         then Add
        when .minus?        then Subtract
        when .star?         then Multiply
        when .slash?        then Divide
        when .double_slash? then DivFloor
        when .double_star?  then Power
        else
          raise "invalid infix operator '#{kind}'"
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

    property op : Operator
    property left : Node
    property right : Node

    def initialize(@op : Operator, @left : Node, @right : Node)
      super()
    end

    def to_s(io : IO) : Nil
      io << @left << ' ' << @op << ' ' << @right
    end

    def pretty_print(pp : PrettyPrint) : Nil
      pp.text "Infix("
      pp.group 1 do
        pp.breakable ""
        pp.text "left: "
        @left.pretty_print pp
        pp.comma

        pp.text "op: "
        pp.text @op
        pp.comma

        pp.text "right: "
        @right.pretty_print pp
      end
      pp.text ")"
    end
  end

  class Assign < Expression
    property target : Node
    property value : Node

    def initialize(@target : Node, @value : Node)
      super()
    end

    def to_s(io : IO) : Nil
      io << @target << " = " << @value
    end

    def pretty_print(pp : PrettyPrint) : Nil
      pp.text "Assign("
      pp.group 1 do
        pp.breakable ""
        pp.text "target: "
        @target.pretty_print pp
        pp.comma

        pp.text "value: "
        @value.pretty_print pp
      end
      pp.text ")"
    end
  end

  class Call < Expression
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

    def pretty_print(pp : PrettyPrint) : Nil
      pp.text "Call("
      pp.group 1 do
        pp.breakable ""
        pp.text "receiver: "
        @receiver.pretty_print pp

        pp.comma
        pp.text "args: ["
        pp.group 1 do
          pp.breakable ""
          next if @args.empty?

          @args[0].pretty_print pp
          if @args.size > 1
            @args.skip(1).each do |arg|
              pp.comma
              arg.pretty_print pp
            end
          end
        end
        pp.text "]"
      end
      pp.text ")"
    end
  end

  class StringLiteral < Expression
    property value : String

    def initialize(@value : String)
      super()
    end

    def to_s(io : IO) : Nil
      @value.inspect io
    end

    def pretty_print(pp : PrettyPrint) : Nil
      pp.text "StringLiteral("
      pp.text @value.inspect
      pp.text ")"
    end
  end

  class IntLiteral < Expression
    property raw : String
    property value : Int64

    def initialize(@raw : String)
      super()
      @value = @raw.to_i64 strict: false
    end

    def to_s(io : IO) : Nil
      io << @value
    end

    def pretty_print(pp : PrettyPrint) : Nil
      pp.text "IntLiteral("
      pp.text @value.inspect
      pp.text ")"
    end
  end

  class FloatLiteral < Expression
    property raw : String
    property value : Float64

    def initialize(@raw : String)
      super()
      @value = @raw.to_f64 strict: false
    end

    def to_s(io : IO) : Nil
      io << @value
    end

    def pretty_print(pp : PrettyPrint) : Nil
      pp.text "FloatLiteral("
      pp.text @value.inspect
      pp.text ")"
    end
  end

  class BoolLiteral < Expression
    # ameba:disable Naming/QueryBoolMethods
    property value : Bool

    def initialize(@value : Bool)
      super()
    end

    def to_s(io : IO) : Nil
      io << @value
    end

    def pretty_print(pp : PrettyPrint) : Nil
      pp.text "BoolLiteral("
      pp.text @value
      pp.text ")"
    end
  end

  class NilLiteral < Expression
    def to_s(io : IO) : Nil
      io << "nil"
    end

    def pretty_print(pp : PrettyPrint) : Nil
      pp.text "NilLiteral"
    end
  end
end
