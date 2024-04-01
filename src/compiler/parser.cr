module Lucid::Compiler
  class Parser
    private enum Precedence
      Lowest
      Equals
      Compare
      Sum
      Product
      Prefix
      Call
      Index

      def self.from(kind : Token::Kind)
        case kind
        when .plus?, .minus?
          Sum
        when .star?, .double_star?, .slash?, .double_slash?
          Product
        when .equal?, .case_equal?
          Equals
        when .left_paren?
          Call
          # TODO: handle Index when [] is implemented
        else
          Lowest
        end
      end
    end

    @tokens : Array(Token)
    @pos : Int32

    def self.parse(tokens : Array(Token)) : Array(Statement)
      new(tokens).parse
    end

    def initialize(@tokens : Array(Token))
      @pos = -1
    end

    def parse : Array(Statement)
      statements = [] of Statement

      loop do
        break unless token = next_token?
        break unless statement = parse_statement token
        statements << statement
      end

      statements
    end

    # TODO: remove this
    private def current_token : Token
      @tokens[@pos]
    end

    private def next_token? : Token?
      @tokens[@pos += 1]?
    end

    private def next_token_skip_space? : Token?
      return unless token = next_token?

      if token.kind.space? || token.kind.newline?
        next_token_skip_space?
      else
        token
      end
    end

    private def peek_token? : Token?
      @tokens[@pos + 1]?
    end

    private def peek_token_skip_space?(offset : Int32 = 1) : Token?
      return unless token = @tokens[offset]?

      if token.kind.space? || token.kind.newline?
        peek_token_skip_space? offset + 1
      else
        token
      end
    end

    private def parse_statement(token : Token) : Statement?
      case token.kind
      # when .class?, .struct? then parse_class token
      else
        parse_expression_statement
      end
    end

    private def parse_expression_statement : Statement
      ExpressionStatement.new parse_expression :lowest
    end

    private def parse_expression(prec : Precedence) : Expression
      left = parse_prefix_expression current_token
      raise "cannot parse expression #{current_token}" if left.nil?

      loop do
        break unless token = next_token?
        break if prec >= Precedence.from(token.kind)
        break unless infix = parse_infix_expression token, left

        left = infix
      end

      left
    end

    private def parse_prefix_expression(token : Token) : Expression?
      case token.kind
      when .double_colon?
        token = next_token_skip_space? || raise "unexpected EOF"
        parse_ident_or_call token, true
      when .ident?, .const? then parse_ident_or_call token, false
      when .integer?        then parse_integer token
      when .float?          then parse_float token
      when .string?         then parse_string token
      when .true?, .false?  then parse_bool token
      when .is_nil?         then parse_nil token
      when .left_paren?     then parse_grouped_expression
      end
    end

    private def parse_infix_expression(token : Token, expr : Expression) : Expression?
      if token.operator?
        return parse_infix_expression expr
      end

      if token.kind.left_paren?
        return parse_call expr, true
      end
    end

    private def parse_infix_expression(left : Expression) : Expression
      op = Infix::Operator.from current_token.kind
      @pos += 1

      right = parse_expression Precedence.from(current_token.kind)

      Infix.new(op, left, right).at(left.loc & right.loc)
    end

    private def parse_ident_or_call(token : Token, global : Bool) : Expression
      names = [] of Ident
      if token.kind.ident?
        names << Ident.new(token.value, global).at(token.loc)
      else
        names << Const.new(token.value, global).at(token.loc)
      end
      end_loc = token.loc

      while (peek = peek_token?) && (peek.kind.period? || peek.kind.double_colon?)
        @pos += 1 # TODO: replace all these with skip_token
        break unless next_token = next_token_skip_space?
        next_global = peek.kind.double_colon?

        case next_token.kind
        when .ident?
          names << Ident.new(next_token.value, next_global).at(next_token.loc)
          end_loc = next_token.loc
        when .const?
          names << Const.new(next_token.value, next_global).at(next_token.loc)
          end_loc = next_token.loc
          # when .instance_var?
          #   names << InstanceVar.new next_token.value
          #   end_loc = next_token.loc
          # when .class_var?
          #   names << ClassVar.new next_token.value
          #   end_loc = next_token.loc
        else
          break
        end
      end

      if names.size > 1
        receiver = Path.new(names, global).at(token.loc & end_loc)
      else
        receiver = names[0]
      end

      unless next_token = next_token_skip_space?
        return receiver if receiver.is_a?(Const)
        if receiver.is_a?(Path)
          return receiver if receiver.names.last.is_a?(Const)
        end

        return Call.new(receiver, [] of Node).at(receiver.loc)
      end

      case next_token.kind
      when .colon?
        next_token = next_token_skip_space?
        raise "unexpected EOF" unless next_token

        case node = parse_ident_or_call next_token, false
        when Assign
          Var.new(receiver, node.target, node.value).at(receiver.loc)
        when Ident
          Var.new(receiver, node, nil).at(receiver.loc)
        else
          raise "BUG: expected Assign or Ident; got #{node.class}"
        end
      when .assign?
        next_token_skip_space? || raise "unexpected End of File"
        node = parse_expression :lowest

        Assign.new(receiver, node).at(receiver.loc)
      else
        parse_call receiver, next_token.kind.left_paren?
      end
    end

    private def parse_call(receiver : Node, with_paren : Bool) : Node
      args = [] of Node
      delimited = true

      if with_paren
        closed = false
      else
        @pos -= 1
        closed = true
      end

      loop do
        unless next_token = next_token?
          @pos -= 1
          break
        end

        case next_token.kind
        when .space?
          next
        when .newline?
          break unless with_paren
        when .comma?
          delimited = true
        when .right_paren?
          @pos -= 1 unless with_paren
          closed = true
          break
        else
          raise "expected a comma after the last argument" unless delimited
          delimited = false

          break unless node = parse_expression :lowest
          args << node
          @pos -= 1 # FIXME: cannot have this here
        end
      end

      raise "expected closing parenthesis for call" unless closed

      Call.new(receiver, args).at(receiver.loc)
    end

    private def parse_integer(token : Token) : Expression
      IntLiteral.new(token.value).at(token.loc)
    end

    private def parse_float(token : Token) : Expression
      FloatLiteral.new(token.value).at(token.loc)
    end

    private def parse_string(token : Token) : Expression
      StringLiteral.new(token.value).at(token.loc)
    end

    private def parse_bool(token : Token) : Expression
      BoolLiteral.new(token.kind.true?).at(token.loc)
    end

    private def parse_nil(token : Token) : Expression
      NilLiteral.new.at(token.loc)
    end

    private def parse_grouped_expression : Expression
      @pos += 1
      expr = parse_expression :lowest
      token = next_token?

      if token.nil? || !token.kind.right_paren?
        raise "expected closing parenthesis after expression"
      end

      expr
    end
  end
end
