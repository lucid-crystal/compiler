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
    @pos : Int32 = 0

    def self.parse(tokens : Array(Token)) : Array(Statement)
      new(tokens).parse
    end

    private def initialize(@tokens : Array(Token))
    end

    def parse : Array(Statement)
      statements = [] of Statement

      loop do
        break if current_token.kind.eof?
        statements << parse_statement current_token
      end

      statements
    end

    private def current_token : Token
      @tokens[@pos]
    end

    private def next_token : Token
      @tokens[@pos += 1]
    end

    private def next_token? : Token?
      @tokens[@pos += 1]?
    end

    # These methods are getting out of hand...

    private def next_token_skip_space? : Token?
      return unless token = next_token?

      if token.kind.space?
        next_token_skip_space?
      else
        token
      end
    end

    private def next_token_skip_space! : Token
      next_token_skip_space? || raise "unexpected EOF"
    end

    private def next_token_skip_newline? : Token?
      return unless token = next_token?

      if token.kind.newline?
        next_token_skip_newline?
      else
        token
      end
    end

    private def next_token_skip_newline! : Token
      next_token_skip_newline? || raise "unexpected EOF"
    end

    private def skip_token : Nil
      @pos += 1
    end

    private def peek_token : Token
      @tokens[@pos + 1]
    end

    private def peek_token_skip_space(offset : Int32 = @pos) : Token
      if token = @tokens[offset + 1]?
        if token.kind.space?
          peek_token_skip_space offset + 1
        else
          token
        end
      else
        @tokens[offset]
      end
    end

    private def next_token_skip(space : Bool = false, newline : Bool = false) : Token
      token = next_token
      if (space && token.kind.space?) || (newline && token.kind.newline?)
        next_token_skip space, newline
      else
        token
      end
    end

    private def peek_token_skip(space : Bool = false, newline : Bool = false,
                                offset : Int32 = @pos) : Token
      if token = @tokens[offset + 1]?
        if space && token.kind.space?
          peek_token_skip space, newline, offset + 1
        elsif newline && token.kind.newline?
          peek_token_skip space, newline, offset + 1
        else
          token
        end
      else
        @tokens[offset]
      end
    end

    private def peek_token_skip_space?(offset : Int32 = @pos) : Token?
      return unless token = @tokens[offset + 1]?

      if token.kind.space?
        peek_token_skip_space? offset + 1
      else
        token
      end
    end

    private def parse_statement(token : Token) : Statement?
      case token.kind
      when .def?
        parse_def token
        # when .class?, .struct? then parse_class token
      else
        parse_expression_statement token
      end
    end

    # DEF ::=
    #       'def' (IDENT | PATH | OP) [
    #         '('
    #         [IDENT [IDENT] [':' CONST] ['=' EXPRESSION] ',']*
    #         ['&' IDENT [':' CONST]]
    #         ')'
    #       ]
    #       [':' (CONST | PATH)] (';' | '\n' | '\r\n')
    #       [EXPRESSION*]
    #       'end'
    private def parse_def(token : Token) : Statement
      start = token.loc
      name = parse_ident_or_path next_token_skip_space!, false
      token = next_token_skip_space!
      params = [] of Parameter
      parens = false

      if token.kind.left_paren?
        parens = true
        token = next_token_skip_space!

        if token.kind.right_paren?
          token = next_token_skip_space!
        else
          loop do
            pname = parse_ident_or_path token, false
            token = next_token_skip_space!

            if token.kind.colon?
              type = parse_const_or_path next_token_skip_space!, false
              token = next_token_skip_space!
            end

            if token.kind.assign?
              value = parse_expression next_token_skip_space!, :lowest
              token = next_token_skip_space!
            end

            params << Parameter.new(pname, type, value, false)

            if token.kind.right_paren?
              token = next_token_skip_space!
              break
            elsif token.kind.comma?
              token = next_token_skip_space!
            else
              raise "expected a comma after the last parameter"
            end
          end
        end
      end

      if token.kind.colon?
        return_type = parse_const_or_path next_token_skip_space!, false
        token = next_token_skip_space!
      end

      unless parens && return_type.nil?
        unless token.kind.newline? # TODO: add semicolon
          raise "expected a newline after def signature"
        end
        token = next_token_skip space: true, newline: true
      end

      body = [] of ExpressionStatement
      until token.kind.end?
        body << parse_expression_statement token
        token = next_token_skip_space!
      end

      skip_token
      Def.new(name, params, return_type, body).at(start & token.loc)
    end

    private def parse_expression_statement(token : Token) : Statement
      expr = ExpressionStatement.new parse_expression(token, :lowest)
      next_token

      expr
    end

    # EXPRESSION ::= PREFIX_EXPR | INFIX_EXPR
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

    # PREFIX_EXPR ::= ('!' | '~' | '-' | '*' | '**') EXPRESSION
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
    end

    # INFIX_EXPR ::= (['('] EXPRESSION OP EXPRESSION [')'])+
    private def parse_infix_expression(token : Token, left : Expression) : Expression
      op = Infix::Operator.from token.kind
      token = next_token_skip_space!
      right = parse_expression token, Precedence.from(token.kind)

      Infix.new(op, left, right).at(left.loc & right.loc)
    end

    # VAR ::= (IDENT | PATH) [':' (CONST | PATH)] ['=' EXPRESSION]
    #
    # CALL ::= OPEN_CALL | CLOSED_CALL
    #
    # PATH ::= [(['::'] CONST)+ '.'] IDENT ('.' IDENT)*
    private def parse_var_or_call(token : Token, global : Bool) : Expression
      if token.kind.ident?
        receiver = parse_ident_or_path token, global
      else
        receiver = parse_const_or_path token, global
      end

      peek = peek_token_skip_space
      if peek.kind.eof? || peek.kind.newline? || peek.kind.comma? || peek.kind.right_paren?
        case receiver
        when Const then return receiver
        when Path
          if receiver.names.last.is_a?(Const)
            return receiver
          else
            return Call.new(receiver, [] of Node).at(receiver.loc)
          end
        else
          return Call.new(receiver, [] of Node).at(receiver.loc)
        end
      end

      skip_token
      case current_token.kind
      when .space?
        token = next_token_skip_space!
        case token.kind
        when .colon?
          node = parse_var_or_call next_token_skip_space!, false
          case node
          when Assign
            Var.new(receiver, node.target, node.value).at(receiver.loc & node.loc)
          when Ident
            Var.new(receiver, node, nil).at(receiver.loc & node.loc)
          else
            raise "BUG: expected Assign or Ident; got #{node.class}"
          end
        when .assign?
          node = parse_expression next_token_skip_space!, :lowest
          Assign.new(receiver, node).at(receiver.loc)
        when .left_paren?
          parse_closed_call receiver
        else
          parse_open_call receiver
        end
      when .left_paren?
        parse_closed_call receiver
      else
        raise "unexpected token #{current_token}"
      end
    end

    # IDENT ::= ('a'..'z' | '_') ('a'..'z' | 'A'..'Z' | '0'..'9' | '_')*
    private def parse_ident_or_path(token : Token, global : Bool) : Expression
      names = [Ident.new(token.value, global).at(token.loc)]

      while peek_token.kind.period?
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

    # CONST ::= ('A'..'Z') ('a'..'z' | 'A'..'Z' | '0'..'9' | '_')*
    private def parse_const_or_path(token : Token, global : Bool) : Expression
      names = [Const.new(token.value, global).at(token.loc)] of Ident
      in_method = false

      while peek_token.kind.period? || peek_token.kind.double_colon?
        global = peek_token.kind.double_colon?
        raise "unexpected token #{peek_token}" if global && in_method
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

    # OPEN_CALL ::= (IDENT | PATH) [EXPRESSION (',' [NEWLINE] EXPRESSION)*]
    private def parse_open_call(receiver : Node) : Node
      args = [] of Node
      delimited = true
      received = false

      loop do
        case current_token.kind
        when .eof?
          break
        when .newline?
          break if !delimited && received
          skip_token
        when .space?
          skip_token
        when .comma?
          raise "unexpected token ','" unless delimited
          delimited = false
          skip_token
        else
          args << parse_expression current_token, :lowest
          received = true
          case peek_token_skip_space.kind
          when .eof?, .newline?, .end?
            break
          when .comma?
            delimited = true
            received = false
            skip_token
          else
            raise "expected a comma after the last argument"
          end
        end
      end

      raise "invalid trailing comma in call" unless received

      Call.new(receiver, args).at(receiver.loc)
    end

    # CLOSED_CALL ::= (IDENT | PATH) '(' [EXPRESSION (',' [NEWLINE] EXPRESSION)*] ')'
    private def parse_closed_call(receiver : Node) : Node
      skip_token
      args = [] of Node
      delimited = true
      closed = false

      loop do
        case current_token.kind
        when .eof?
          break
        when .space?, .newline?
          skip_token
        when .right_paren?
          closed = true
          break
        when .comma?
          raise "unexpected token ','" unless delimited
          delimited = false
          skip_token
        else
          args << parse_expression current_token, :lowest
          token = peek_token_skip space: true, newline: true
          case token.kind
          when .eof?
            break
          when .comma?
            delimited = true
            skip_token
          when .right_paren?
            closed = true
            skip_token
          else
            raise "Unexpected token #{token}"
          end
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
      token = next_token?

      if token.nil? || !token.kind.right_paren?
        raise "expected closing parenthesis after expression"
      end

      expr
    end
  end
end
