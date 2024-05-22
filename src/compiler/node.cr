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
    property free_vars : Array(Const)
    property body : Array(Expression)
    property? abstract : Bool = false
    property? private : Bool = false
    property? protected : Bool = false

    def initialize(@name : Node, @params : Array(Parameter), @return_type : Node?,
                   @free_vars : Array(Const), @body : Array(Expression))
      super()
    end

    def to_s(io : IO) : Nil
      io << "private " if @private
      io << "protected " if @protected
      io << "abstract " if @abstract
      io << "def " << @name

      unless @params.empty?
        io << '('
        @params.join(io, ", ")
        io << ')'
      end

      if @return_type
        io << " : " << @return_type
      end

      unless @free_vars.empty?
        io << " forall "
        @free_vars.join(io, ", ")
      end

      unless @abstract
        io << '\n'
        @body.each do |expr|
          io << ' '
          expr.to_s io
        end
        io << "end"
      end
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

        pp.text "free_vars: ["
        pp.group 1 do
          pp.breakable ""
          next if @free_vars.empty?

          @free_vars[0].pretty_print pp
          if @free_vars.size > 1
            @free_vars.skip(1).each do |var|
              pp.comma
              var.pretty_print pp
            end
          end
        end
        pp.text "]"
        pp.comma

        pp.text "private: "
        @private.pretty_print pp
        pp.comma

        pp.text "protected: "
        @protected.pretty_print pp
        pp.comma

        pp.text "abstract: "
        @abstract.pretty_print pp
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
    property internal_name : Node?
    property type : Node?
    property default_value : Node?
    property? block : Bool

    def initialize(@name : Node, @internal_name : Node?, @type : Node?, @default_value : Node?,
                   @block : Bool)
      super()
    end

    def to_s(io : IO) : Nil
      io << '&' if @block
      io << @name
      if @internal_name
        io << ' ' << @internal_name
      end
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

        pp.text "internal_name: "
        @internal_name.pretty_print pp
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

  class Underscore < Expression
    def to_s(io : IO) : Nil
      io << '_'
    end

    def pretty_print(pp : PrettyPrint) : Nil
      pp.text "Underscore"
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
      Not         # !
      BitAnd      # &
      Splat       # *
      DoubleSplat # **
      Plus        # +
      Minus       # -
      BitNot      # ~

      def self.from(kind : Token::Kind)
        case kind
        when .bang?        then Not
        when .bit_and?     then BitAnd
        when .star?        then Splat
        when .double_star? then DoubleSplat
        when .plus?        then Plus
        when .minus?       then Minus
        when .tilde?       then BitNot
        else
          raise "invalid prefix operator '#{kind}'"
        end
      end

      def to_s : String
        case self
        in Not         then "!"
        in BitAnd      then "&"
        in Splat       then "*"
        in DoubleSplat then "**"
        in Plus        then "+"
        in Minus       then "-"
        in BitNot      then "~"
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
      NotEqual       # !=
      PatternUnmatch # !~
      Modulo         # %
      BitAnd         # &
      And            # &&
      BinaryMultiply # &*
      BinaryAdd      # &+
      BinarySubtract # &-
      Multiply       # *
      Power          # **
      Add            # +
      Subtract       # -
      InRange        # ..
      OutRange       # ...
      Divide         # /
      DivFloor       # //
      LessThan       # <
      ShiftLeft      # <<
      LessEqual      # <=
      Comparison     # <=>
      Equal          # ==
      CaseEqual      # ===
      PatternMatch   # =~
      GreaterThan    # >
      ShiftRight     # >>
      GreaterEqual   # >=
      Xor            # ^
      BitOr          # |
      Or             # ||

      def self.from(kind : Token::Kind)
        case kind
        when .not_equal?       then NotEqual
        when .pattern_unmatch? then PatternUnmatch
        when .modulo?          then Modulo
        when .bit_and?         then BitAnd
        when .and?             then And
        when .binary_star?     then BinaryMultiply
        when .binary_plus?     then BinaryAdd
        when .binary_minus?    then BinarySubtract
        when .star?            then Multiply
        when .double_star?     then Power
        when .plus?            then Add
        when .minus?           then Subtract
        when .double_period?   then InRange
        when .triple_period?   then OutRange
        when .slash?           then Divide
        when .double_slash?    then DivFloor
        when .lesser?          then LessThan
        when .shift_left?      then ShiftLeft
        when .lesser_equal?    then LessEqual
        when .comparison?      then Comparison
        when .equal?           then Equal
        when .case_equal?      then CaseEqual
        when .pattern_match?   then PatternMatch
        when .greater?         then GreaterThan
        when .shift_right?     then ShiftRight
        when .greater_equal?   then GreaterEqual
        when .caret?           then Xor
        when .bit_or?          then BitOr
        when .or?              then Or
        else
          raise "invalid infix operator '#{kind}'"
        end
      end

      def to_s : String
        case self
        in NotEqual       then "!="
        in PatternUnmatch then "!~"
        in Modulo         then "%"
        in BitAnd         then "&"
        in And            then "&&"
        in BinaryMultiply then "&*"
        in BinaryAdd      then "&+"
        in BinarySubtract then "&-"
        in Multiply       then "*"
        in Power          then "**"
        in Add            then "+"
        in Subtract       then "-"
        in InRange        then ".."
        in OutRange       then "..."
        in Divide         then "/"
        in DivFloor       then "//"
        in LessThan       then "<"
        in ShiftLeft      then "<<"
        in LessEqual      then "<="
        in Comparison     then "<=>"
        in Equal          then "=="
        in CaseEqual      then "==="
        in PatternMatch   then "=~"
        in GreaterThan    then ">"
        in ShiftRight     then ">>"
        in GreaterEqual   then ">="
        in Xor            then "^"
        in BitOr          then "|"
        in Or             then "||"
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

  class ProcLiteral < Expression
    property params : Array(Parameter)
    property body : Array(Expression)

    def initialize(@params : Array(Parameter), @body : Array(Expression))
      super()
    end

    def to_s(io : IO) : Nil
      io << "-> "
      unless @params.empty?
        io << '(' << @params[0]

        if @params.size > 1
          @params.each do |param|
            io << ", " << param
          end
        end

        io << ") "
      end

      io << "do\n"
      @body.each do |expr|
        io << ' '
        expr.to_s io
      end
      io << "end"
    end

    def pretty_print(pp : PrettyPrint) : Nil
      pp.text "ProcLiteral("
      pp.group 1 do
        pp.breakable ""
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
end
