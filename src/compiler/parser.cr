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

    private def next_token_skip_space! : Token
      next_token_skip_space? || raise "unexpected EOF"
    end

    private def skip_token : Nil
      @pos += 1
    end

    private def peek_token? : Token?
      @tokens[@pos + 1]?
    end

    private def peek_token_skip_space?(offset : Int32 = @pos) : Token?
      return unless token = @tokens[offset + 1]?

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
        parse_expression_statement token
      end
    end

    private def parse_expression_statement(token : Token) : Statement
      ExpressionStatement.new parse_expression(token, :lowest)
    end

    private def parse_expression(token : Token, prec : Precedence) : Expression
      left = parse_prefix_expression token
      raise "cannot parse expression #{token}" if left.nil?

      loop do
        break unless token = peek_token_skip_space?
        break if prec >= Precedence.from(token.kind)

        skip_token
        break unless infix = parse_infix_expression token, left

        left = infix
      end

      left
    end

    private def parse_prefix_expression(token : Token) : Expression?
      case token.kind
      when .double_colon?   then parse_var_or_call next_token_skip_space!, true
      when .ident?, .const? then parse_var_or_call token, false
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
        return parse_infix_expression token, expr
      end

      if token.kind.left_paren?
        return parse_call expr, true
      end
    end

    private def parse_infix_expression(token : Token, left : Expression) : Expression
      op = Infix::Operator.from token.kind
      token = next_token_skip_space!
      right = parse_expression token, Precedence.from(token.kind)

      Infix.new(op, left, right).at(left.loc & right.loc)
    end

    private def parse_var_or_call(token : Token, global : Bool) : Expression
      if token.kind.ident?
        receiver = parse_ident_or_path token, global
      else
        receiver = parse_const_or_path token, global
      end

      unless peek_token_skip_space?
        return receiver if receiver.is_a?(Const)
        if receiver.is_a?(Path)
          return receiver if receiver.names.last.is_a?(Const)
        end

        return Call.new(receiver, [] of Node).at(receiver.loc)
      end

      token = next_token_skip_space!
      case token.kind
      when .colon?
        case node = parse_var_or_call next_token_skip_space!, false
        when Assign
          Var.new(receiver, node.target, node.value).at(receiver.loc)
        when Ident
          Var.new(receiver, node, nil).at(receiver.loc)
        else
          raise "BUG: expected Assign or Ident; got #{node.class}"
        end
      when .assign?
        node = parse_expression next_token_skip_space!, :lowest
        Assign.new(receiver, node).at(receiver.loc)
      when .left_paren?
        parse_closed_call receiver
      when .comma?
        Call.new(receiver, [] of Node).at(receiver.loc)
      else
        parse_open_call receiver, token
      end
    end

    private def parse_ident_or_path(token : Token, global : Bool) : Expression
      names = [Ident.new(token.value, global).at(token.loc)]

      while (peek = peek_token?) && peek.kind.period?
        skip_token
        break unless token = next_token_skip_space?

        if token.kind.ident?
          names << Ident.new(token.value, false).at(token.loc)
        else
          raise "unexpected token #{token}"
        end
      end

      if names.size > 1
        Path.new(names, names[0].global?)
      else
        names[0]
      end
    end

    private def parse_const_or_path(token : Token, global : Bool) : Expression
      names = [Const.new(token.value, global).at(token.loc)] of Ident
      in_method = false

      while (peek = peek_token?) && (peek.kind.period? || peek.kind.double_colon?)
        global = peek.kind.double_colon?
        raise "unexpected token #{peek}" if global && in_method
        skip_token
        break unless token = next_token_skip_space?

        case token.kind
        when .ident?
          in_method = true
          names << Ident.new(token.value, global).at(token.loc)
        when .const?
          raise "unexpected token #{token}" if in_method
          names << Const.new(token.value, global).at(token.loc)
        else
          raise "unexpected token #{token}"
        end
      end

      if names.size > 1
        Path.new(names, names[0].global?)
      else
        names[0]
      end
    end

    private def parse_open_call(receiver : Node, first : Token) : Node
      args = [parse_expression(first, :lowest)] of Node
      delimited = false

      loop do
        break unless token = next_token_skip_space?

        case token.kind
        when .space?
          next
        when .newline?
          break unless delimited
        when .comma?
          raise "unexpected token ','" if delimited
          delimited = true
        else
          raise "expected a comma after the last argument" unless delimited
          delimited = false
          args << parse_expression token, :lowest
        end
      end

      raise "invalid trailing comma in call" if delimited

      Call.new(receiver, args).at(receiver.loc)
    end

    private def parse_closed_call(receiver : Node) : Node
      args = [] of Node
      delimited = true
      closed = false

      loop do
        break unless token = next_token_skip_space?

        case token.kind
        when .right_paren?
          closed = true
          skip_token
          break
        when .comma?
          raise "unexpected token ','" if delimited
          delimited = true
        else
          raise "expected a comma after the last argument" unless delimited
          delimited = false
          args << parse_expression token, :lowest
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
      expr = parse_expression next_token_skip_space!, :lowest
      # FIXME: figure out why parse_expression is still skipping ahead
      token = @tokens[@pos]? || raise "unexpected EOF"

      unless token.kind.right_paren?
        raise "expected closing parenthesis after expression"
      end

      expr
    end
  end
end
