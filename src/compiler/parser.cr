module Lucid::Compiler
  class Parser
    # https://crystal-lang.org/reference/1.12/syntax_and_semantics/operators.html#operator-precedence
    private enum Precedence
      Lowest
      Splat
      Assignment
      Conditional
      Range
      Or
      And
      Comparison
      Equality
      BinaryOr
      BinaryAnd
      Shift
      # Additive # doesn't make sense
      Multiplicative
      Exponential
      Unary
      Index

      def self.from(kind : Token::Kind)
        case kind
        # when .left_bracket?
        #   Index
        when .bang?, .binary_plus?, .binary_minus?, .plus?, .minus?, .tilde?
          Unary
        when .binary_double_star?, .double_star?
          Exponential
        when .modulo?, .binary_star?, .star?, .slash?, .double_slash?
          Multiplicative
        when .shift_left?, .shift_right?
          Shift
        when .bit_and?
          BinaryAnd
        when .bit_or?, .caret?
          BinaryOr
        when .not_equal?, .pattern_unmatch?, .equal?, .case_equal?, .pattern_match?
          Equality
        when .lesser?, .lesser_equal?, .comparison?, .greater?, .greater_equal?
          Comparison
        when .and?
          And
        when .or?
          Or
        when .double_period?, .triple_period?
          Range
        when .question?
          Conditional
        when Token::Kind::Assign..Token::Kind::OrAssign
          Assignment
        when .star?, .double_star?
          Splat
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
        break unless stmt = parse_statement current_token
        statements << stmt
      end

      statements
    end

    private def current_token : Token
      @tokens[@pos]
    end

    private def next_token : Token
      @tokens[@pos += 1]
    end

    private def skip_token : Nil
      @pos += 1
    end

    private def peek_token : Token
      @tokens[@pos + 1]
    end

    private def next_token_skip(space : Bool = false, newline : Bool = false,
                                semicolon : Bool = false) : Token
      token = next_token
      if (space && token.kind.space?) ||
         (newline && token.kind.newline?) ||
         (semicolon && token.kind.semicolon?)
        next_token_skip space, newline, semicolon
      else
        token
      end
    end

    private def peek_token_skip(space : Bool = false, newline : Bool = false,
                                offset : Int32 = @pos) : Token
      if token = @tokens[offset + 1]?
        if (space && token.kind.space?) || (newline && token.kind.newline?)
          peek_token_skip space, newline, offset + 1
        else
          token
        end
      else
        @tokens[offset]
      end
    end

    private def parse_statement(token : Token) : Statement?
      case token.kind
      when .eof?
        nil
      when .space?, .newline?, .semicolon?
        parse_statement next_token_skip space: true, newline: true, semicolon: true
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
    #       [':' (CONST | PATH)] ['forall' CONST [',' CONST]*] (';' | '\n' | '\r\n')
    #       [EXPRESSION*]
    #       'end'
    private def parse_def(token : Token) : Statement
      start = token.loc
      name = parse_ident_or_path next_token_skip(space: true), false
      token = next_token_skip space: true
      params = [] of Parameter
      empty_parens = false
      free_vars = [] of Const

      if token.kind.left_paren?
        token = next_token_skip space: true

        if token.kind.right_paren?
          empty_parens = true
          token = next_token_skip space: true
        else
          loop do
            # TODO: catch-all when not ident or bit-and
            if token.kind.bit_and?
              block = true
              token = next_token_skip space: true

              if token.kind.ident?
                pname = parse_ident_or_path token, false
                token = next_token_skip space: true
              else
                pname = NilLiteral.new
              end
            else
              block = false
              pname = parse_ident_or_path token, false
              token = next_token_skip space: true
            end

            if token.kind.colon?
              type = parse_const_or_path next_token_skip(space: true), false
              token = next_token_skip space: true
            end

            if token.kind.assign?
              value = parse_expression next_token_skip(space: true), :lowest
              token = next_token_skip space: true
            end

            params << Parameter.new(pname, type, value, block)

            if token.kind.right_paren?
              token = next_token_skip space: true
              break
            elsif token.kind.comma?
              token = next_token_skip space: true
            else
              raise "expected a comma or right parenthesis; got #{token}"
            end
          end
        end
      end

      if token.kind.colon?
        return_type = parse_const_or_path next_token_skip(space: true), false
        token = next_token_skip space: true
      end

      if token.kind.forall?
        loop do
          token = next_token_skip space: true
          raise "expected token const; got #{token}" unless token.kind.const?

          case node = parse_const_or_path token, false
          when Const then free_vars << node
          else            raise "free variables cannot be paths"
          end

          token = next_token_skip space: true
          break unless token.kind.comma?
        end
      end

      unless empty_parens && return_type.nil?
        unless token.kind.newline? || token.kind.semicolon?
          raise "expected a newline or semicolon after def signature; got #{token}"
        end
        token = next_token_skip space: true, newline: true, semicolon: true
      end

      body = [] of Expression
      loop do
        break if token.kind.end?
        raise "unexpected end of file" if token.kind.eof?

        body << parse_expression_statement(token).value
        token = current_token
      end

      skip_token
      Def.new(name, params, return_type, free_vars, body).at(start & token.loc)
    end

    private def parse_expression_statement(token : Token) : Statement
      expr = ExpressionStatement.new parse_expression(token, :lowest)
      unless current_token.kind.eof?
        next_token_skip space: true, newline: true, semicolon: true
      end

      expr
    end

    # EXPRESSION ::= PREFIX_EXPR | INFIX_EXPR
    private def parse_expression(token : Token, prec : Precedence) : Expression
      left = parse_prefix_expression token
      raise "cannot parse expression #{token}" if left.nil?

      loop do
        token = peek_token_skip space: true, newline: true
        break if prec >= Precedence.from(token.kind)

        next_token_skip space: true, newline: true
        left = parse_infix_expression token, left
      end

      left
    end

    # PREFIX_EXPR ::= ['!' | '&' | '*' | '**' | '+' | '-' | '~'] EXPRESSION
    private def parse_prefix_expression(token : Token) : Expression?
      case token.kind
      when .double_colon?   then parse_var_or_call next_token_skip(space: true), true
      when .ident?, .const? then parse_var_or_call token, false
      when .integer?        then parse_integer token
      when .float?          then parse_float token
      when .string?         then parse_string token
      when .true?, .false?  then parse_bool token
      when .is_nil?         then parse_nil token
      when .left_paren?     then parse_grouped_expression
      when .proc?           then parse_proc token
      else
        return unless token.operator?

        op = Prefix::Operator.from token.kind
        start = token.loc
        token = next_token_skip space: true
        value = parse_expression token, Precedence.from(token.kind)

        Prefix.new(op, value).at(start & value.loc)
      end
    end

    # INFIX_EXPR ::= (['('] EXPRESSION OP EXPRESSION [')'])+
    private def parse_infix_expression(token : Token, left : Expression) : Expression
      op = Infix::Operator.from token.kind
      token = next_token_skip space: true
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

      peek = peek_token_skip space: true
      is_call = if peek.kind.eof? ||
                   peek.kind.newline? ||
                   peek.kind.right_paren? ||
                   peek.kind.comma? ||
                   peek.kind.semicolon? ||
                   peek.kind.right_brace?
                  true
                elsif peek.operator?
                  pos = @pos
                  next_token_skip space: true
                  stop = peek_token.kind.space?
                  @pos = pos
                  stop
                else
                  false
                end

      if is_call
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
        token = next_token_skip space: true
        case token.kind
        when .colon?
          node = parse_var_or_call next_token_skip(space: true), false
          case node
          when Assign
            Var.new(receiver, node.target, node.value).at(receiver.loc & node.loc)
          when Ident
            Var.new(receiver, node, nil).at(receiver.loc & node.loc)
          else
            raise "BUG: expected Assign or Ident; got #{node.class}"
          end
        when .assign?
          node = parse_expression next_token_skip(space: true), :lowest
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
        token = next_token_skip space: true

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
        token = next_token_skip space: true

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
    private def parse_open_call(receiver : Node) : Expression
      args = [parse_expression(current_token, :lowest)] of Node
      delimited = false
      received = true

      loop do
        token = peek_token_skip space: true
        case token.kind
        when .eof?, .semicolon?, .right_brace?, .end?
          break
        when .newline?
          break unless delimited
          next_token_skip space: true
        when .comma?
          raise "unexpected token ','" if delimited
          next_token_skip space: true
          delimited = true
          received = false
        else
          raise "expected a comma after the last argument" if received

          args << parse_expression next_token_skip(space: true), :lowest
          delimited = false
          received = true
        end
      end

      raise "invalid trailing comma in call" if delimited

      Call.new(receiver, args).at(receiver.loc)
    end

    # CLOSED_CALL ::= (IDENT | PATH) '(' [EXPRESSION (',' [NEWLINE] EXPRESSION)*] ')'
    private def parse_closed_call(receiver : Node) : Expression
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
      expr = parse_expression next_token_skip(space: true), :lowest

      unless next_token_skip(space: true).kind.right_paren?
        raise "expected closing parenthesis after expression"
      end

      expr
    end

    private def parse_proc(token : Token) : Expression
      start = token.loc
      token = next_token_skip space: true
      params = [] of Parameter

      if token.kind.left_paren?
        loop do
          token = next_token_skip space: true, newline: true
          break if token.kind.right_paren?

          pname = parse_ident_or_path token, false
          token = next_token_skip space: true
          unless token.kind.colon?
            raise "expected a colon after parameter name; got #{token}"
          end

          type = parse_const_or_path next_token_skip(space: true), false
          params << Parameter.new(pname, type, nil, false)
          token = next_token_skip space: true, newline: true

          case token.kind
          when .comma?       then next
          when .right_paren? then break
          else
            raise "expected a comma or right parenthesis; got #{token}"
          end
        end

        token = next_token_skip space: true, newline: true
      end

      if token.kind.left_brace?
        closing_token = Token::Kind::RightBrace
      elsif token.kind.do?
        closing_token = Token::Kind::End
      else
        raise "unexpected token #{token}"
      end

      token = next_token_skip space: true, newline: true
      body = [] of Expression

      loop do
        break if token.kind == closing_token
        raise "unexpected end of file" if token.kind.eof?

        body << parse_expression_statement(token).value
        token = current_token
      end

      skip_token
      ProcLiteral.new(params, body).at(start & token.loc)
    end
  end
end
