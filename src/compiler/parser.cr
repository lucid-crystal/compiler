module Lucid::Compiler
  class Parser
    class Exception < Exception
      getter target : Token | Node

      def initialize(@target : Token | Node, message : String)
        super message
      end

      def message : String
        super.as(String)
      end
    end

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

    @errors : Array(Error)
    @tokens : Array(Token)
    @fail_first : Bool
    @pos : Int32 = 0

    def self.parse(tokens : Array(Token), *, fail_first : Bool = false) : Program
      new(tokens, fail_first).parse
    end

    private def initialize(@tokens : Array(Token), @fail_first : Bool)
      @errors = [] of Error
    end

    def parse : Program
      nodes = [] of Node

      loop do
        break if current_token.kind.eof?
        break unless node = parse current_token
        nodes << node
      end

      Program.new(@errors, nodes)
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

    private def raise(target : Token | Node, message : String) : Node | NoReturn
      if @fail_first
        raise Parser::Exception.new target, message
      else
        @errors << (node = Error.new(target, message).at(target.loc))
        node
      end
    end

    private def parse(token : Token) : Node?
      case token.kind
      when .eof?
        nil
      when .space?, .newline?, .semicolon?
        parse next_token_skip space: true, newline: true, semicolon: true
      when .abstract?, .private?, .protected?
        parse_type_modifier_expression token
      when .module?
        parse_module token
      when .class?, .struct?
        parse_class_or_struct token
      when .def?
        parse_def token
      when .include?, .extend?
        parse_include_or_extend token
      when .alias?
        parse_alias token
      when .annotation?
        parse_annotation_def token
      when .require?
        parse_require token
      else
        parse_expression token
      end
    end

    private def parse_type_modifier_expression(token : Token) : Node
      loc = token.loc
      kind = case token.kind
             when .abstract?
               TypeModifier::Kind::Abstract
             when .private?
               TypeModifier::Kind::Private
             when .protected?
               TypeModifier::Kind::Protected
             else
               raise "unreachable"
             end

      token = next_token_skip space: true
      if token.kind.def? && kind.abstract?
        expr = parse_def token, true
      else
        expr = parse token
      end

      case expr
      when TypeModifier
        unless (kind.private? || kind.protected?) && expr.kind.abstract?
          expr = raise expr, "cannot apply #{kind.to_s.downcase} to #{expr.kind.to_s.downcase}"
        end
      when Nil
        expr = raise current_token, "unexpected end of file"
      end

      TypeModifier.new(kind, expr).at(loc)
    end

    # TODO: might be worth merging with below and erroring on inheritance
    private def parse_module(token : Token) : Node
      name = parse_const_or_path next_token_skip(space: true), false
      next_token_skip space: true, newline: true, semicolon: true

      parse_namespace token.loc, ModuleDef.new name
    end

    private def parse_class_or_struct(start : Token) : Node
      name = parse_const_or_path next_token_skip(space: true), false
      token = next_token_skip space: true, newline: true, semicolon: true

      if token.kind.lesser?
        superclass = parse_const_or_path next_token_skip(space: true), false
        next_token_skip space: true, newline: true, semicolon: true
      end

      if start.kind.class?
        parse_namespace start.loc, ClassDef.new(name, superclass: superclass)
      else
        parse_namespace start.loc, StructDef.new(name, superclass: superclass)
      end
    end

    private def parse_namespace(start : Location, namespace : NamespaceDef) : Node
      loop do
        break if current_token.kind.end?
        return raise current_token, "unexpected end of file" if current_token.kind.eof?

        case node = parse current_token
        when Include
          namespace.includes << node
        when Extend
          namespace.extends << node
        when Alias
          namespace.aliases << node
        when NamespaceDef
          namespace.types << node
        when Def
          namespace.methods << node
        when Nil
          namespace.body << raise current_token, "unexpected end of file"
          break
        else
          namespace.body << node
        end

        break if current_token.kind.end?
        case current_token.kind
        when .space?, .newline?, .semicolon?
          next_token_skip space: true, newline: true, semicolon: true
        end
      end

      namespace.at(start & current_token.loc)
      skip_token

      namespace
    end

    # DEF ::=
    #       ['private' | 'protected'] ['abstract'] 'def' (IDENT | PATH | OP) [
    #         '('
    #         [IDENT [IDENT] [':' CONST] ['=' EXPRESSION] ',']*
    #         ['&' IDENT [':' CONST]]
    #         ')'
    #       ]
    #       [':' (CONST | PATH)] ['forall' CONST [',' CONST]*] (';' | '\n' | '\r\n')
    #       [EXPRESSION*]
    #       ['end']
    private def parse_def(token : Token, is_abstract : Bool = false) : Node
      start = token.loc
      name = parse_ident_or_path next_token_skip(space: true), false
      token = next_token_skip space: true
      params = [] of Parameter
      empty_parens = false
      free_vars = [] of Node

      if token.kind.left_paren?
        token = next_token_skip space: true

        if token.kind.right_paren?
          empty_parens = true
          token = next_token_skip space: true
        else
          loop do
            internal : Node? = nil

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

            # TODO: not sure how to handle this one
            if token.kind.bit_and? && !pname.is_a?(NilLiteral)
              raise "block parameters cannot have external names"
            end

            if token.kind.ident?
              if block
                pname = raise pname, "block parameters cannot have external names"
              end
              internal = parse_ident_or_path token, false
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

            params << Parameter.new(pname, internal, type, value, block)

            unless token.kind.right_paren? || token.kind.comma?
              node = raise token, "expected a comma or right parenthesis; got #{token}"
              params << Parameter.new(node, nil, nil, nil, false)
              token = next_token_skip space: true
            end

            if token.kind.right_paren?
              token = next_token_skip space: true
              break
            elsif token.kind.comma?
              token = next_token_skip space: true
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
          node = parse_const_or_path token, false

          if node.is_a? Path
            free_vars << raise node, "free variables cannot be paths"
          else
            free_vars << node
          end

          token = next_token_skip space: true
          break unless token.kind.comma?
        end
      end

      if is_abstract
        return Def.new(name, params, return_type, free_vars, [] of Node).tap do |method|
          method.abstract = true
        end
      end

      unless empty_parens && return_type.nil?
        if token.kind.newline? || token.kind.semicolon?
          token = next_token_skip space: true, newline: true, semicolon: true
        else
          name = raise name.at(name.loc & token.loc), "expected a newline or semicolon after def signature; got #{token}"
        end
      end

      body = [] of Node
      loop do
        break if token.kind.end?
        return raise token, "unexpected end of file" if token.kind.eof?

        body << parse_expression token
        token = current_token
      end

      skip_token
      Def.new(name, params, return_type, free_vars, body).at(start & token.loc)
    end

    private def parse_include_or_extend(start : Token) : Node
      token = next_token_skip space: true

      if token.kind.eof?
        node = raise token, "unexpected end of file"
      else
        node = parse(token).as(Node) # TODO: replace with parse! method
      end

      if start.kind.include?
        Include.new(node).at(start.loc & node.loc)
      else
        Extend.new(node).at(start.loc & node.loc)
      end
    end

    private def parse_alias(token : Token) : Node
      name = parse_const_or_path next_token_skip(space: true), true

      if name.is_a?(Error) && current_token.kind.eof?
        return Alias.new(name, name).at(token.loc & name.loc)
      end

      case next_token_skip(space: true).kind
      when .eof?
        type = raise current_token, "unexpected end of file"
      when .assign?
        type = parse_const_or_path next_token_skip(space: true), true
        next_token_skip(space: true, newline: true) unless current_token.kind.eof?
      else
        type = raise current_token, "unexpected token #{current_token}"
        next_token_skip space: true, newline: true
      end

      Alias.new(name, type).at(token.loc & type.loc)
    end

    private def parse_annotation_def(token : Token) : Node
      next_token_skip space: true

      case current_token.kind
      when .eof?
        node = raise current_token, "unexpected end of file"
        end_loc = current_token.loc
      when .const?
        node = parse_const_or_path current_token, true
        next_token_skip space: true, newline: true, semicolon: true
      else
        node = raise current_token, "expected a const for annotation"
        next_token_skip space: true, newline: true, semicolon: true
      end

      unless end_loc
        while current_token.kind.comment?
          next_token_skip space: true, newline: true
        end

        case current_token.kind
        when .eof?
          node = raise current_token, "unexpected end of file"
          end_loc = current_token.loc
        when .end?
          end_loc = current_token.loc
          next_token_skip space: true, newline: true
        else
          node = raise current_token, "expected 'end' not #{current_token}"
          end_loc = current_token.loc
          next_token_skip space: true, newline: true
        end
      end

      AnnotationDef.new(node).at(token.loc & end_loc)
    end

    private def parse_require(token : Token) : Node
      start = token.loc
      token = next_token_skip space: true

      case token.kind
      when .eof?
        node = raise token, "unexpected end of file"
      when .string?
        node = parse_string token
        next_token_skip space: true, newline: true
      else
        node = raise token, "require needs a string literal"
        next_token_skip space: true, newline: true
      end

      Require.new(node).at(start & node.loc)
    end

    private def parse_expression(token : Token) : Node
      expr = parse_expression token, :lowest
      unless current_token.kind.eof?
        next_token_skip space: true, newline: true, semicolon: true
      end

      expr
    end

    # EXPRESSION ::= PREFIX_EXPR | INFIX_EXPR
    private def parse_expression(token : Token, prec : Precedence) : Node
      left = parse_prefix_expression token
      # TODO: should this error message change?
      return raise token, "cannot parse expression #{token}" if left.nil?

      loop do
        token = peek_token_skip space: true, newline: true
        break if prec >= Precedence.from(token.kind)

        next_token_skip space: true, newline: true
        left = parse_infix_expression token, left
      end

      left
    end

    # PREFIX_EXPR ::= ['!' | '&' | '*' | '**' | '+' | '-' | '~'] EXPRESSION
    private def parse_prefix_expression(token : Token) : Node?
      expr = case token.kind
             when .double_colon?
               parse_var_or_call(next_token_skip(space: true), true).tap do |node|
                 node.loc = token.loc & node.loc
               end
             when .ident?, .const?, .self?, .underscore?, .instance_var?, .class_var?, .pseudo?
               parse_var_or_call token, false
             when .begin?                        then parse_begin token
             when .command?, .command_start?     then parse_command_call token
             when .shorthand?                    then parse_block token
             when .integer?                      then parse_integer token
             when .integer_bad_suffix?           then parse_invalid_integer token
             when .float?                        then parse_float token
             when .float_bad_suffix?             then parse_invalid_float token
             when .string?, .string_part?        then parse_string token
             when .string_start?                 then parse_interpolated_string token
             when .true?, .false?                then parse_bool token
             when .char?                         then parse_char token
             when .symbol?, .quoted_symbol?      then parse_symbol token
             when .symbol_key?                   then parse_symbol_key token
             when .is_nil?                       then parse_nil token
             when .left_paren?                   then parse_grouped_expression
             when .left_bracket?                 then parse_array_literal token
             when .left_brace?                   then parse_hash_or_tuple_literal token
             when .string_array?, .symbol_array? then parse_percent_array_literal token
             when .annotation_open?              then parse_annotation token
             when .proc?                         then parse_proc token
             when .magic_line?                   then parse_integer token
             when .magic_dir?                    then parse_string token
             when .magic_file?                   then parse_string token
             else
               return unless token.operator?

               op = Prefix::Operator.from token.kind
               start = token.loc
               token = next_token_skip space: true
               value = parse_expression token, Precedence.from(token.kind)

               Prefix.new(op, value).at(start & value.loc)
             end

      expr
    end

    # INFIX_EXPR ::= (['('] EXPRESSION OP EXPRESSION [')'])+
    private def parse_infix_expression(token : Token, left : Node) : Node
      op = Infix::Operator.from token.kind
      error = "invalid infix operator '#{token.kind}'" if op.invalid?
      token = next_token_skip space: true
      right = parse_expression token, Precedence.from(token.kind)

      infix = Infix.new(op, left, right).at(left.loc & right.loc)
      infix = raise infix, error if error
      skip_token unless current_token.kind.eof?
      infix
    end

    # VAR ::= (IDENT | PATH) [':' (CONST | PATH)] ['=' EXPRESSION]
    #
    # CALL ::= OPEN_CALL | CLOSED_CALL
    #
    # PATH ::= [(['::'] CONST)+ '.'] IDENT ('.' IDENT)*
    private def parse_var_or_call(token : Token, global : Bool) : Node
      case token.kind
      when .ident?, .self?, .instance_var?, .class_var?, .keyword?
        receiver = parse_ident_or_path token, global
      when .const?
        receiver = parse_const_or_path token, global
      when .alignof?
        receiver = AlignOf.new.at(token.loc)
      when .instance_alignof?
        receiver = InstanceAlignOf.new.at(token.loc)
      when .instance_sizeof?
        receiver = InstanceSizeOf.new.at(token.loc)
      when .offsetof?
        receiver = OffsetOf.new.at(token.loc)
      when .pointerof?
        receiver = PointerOf.new.at(token.loc)
      when .sizeof?
        receiver = SizeOf.new.at(token.loc)
      when .underscore?
        receiver = Underscore.new.at(token.loc)
      else
        receiver = raise token, "unexpected token #{token}"
      end

      peek = peek_token_skip space: true
      is_call = if peek.kind.eof? ||
                   peek.kind.newline? ||
                   peek.kind.right_paren? ||
                   peek.kind.comma? ||
                   peek.kind.semicolon? ||
                   peek.kind.right_brace? ||
                   peek.kind.end?
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

      if !is_call && receiver.is_a?(Underscore)
        receiver = raise receiver, "underscore cannot be called as a method"
      end

      if is_call
        case receiver
        when Const, Underscore then return receiver
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

      case peek_token.kind
      when .space?
        token = next_token_skip space: true
        case token.kind
        when .colon?
          case node = parse_var_or_call next_token_skip(space: true), false
          when Assign
            Var.new(receiver, node.target, node.value).at(receiver.loc & node.loc)
          when Ident, Const
            Var.new(receiver, node, nil).at(receiver.loc & node.loc)
          else
            raise "BUG: expected Assign, Ident or Const; got #{node.class}"
          end
        when .assign?
          node = parse_expression next_token_skip(space: true), :lowest
          Assign.new(receiver, node).at(receiver.loc & node.loc)
        when .do?, .left_brace?
          node = parse_block token
          Call.new(receiver, [node]).at(receiver.loc & node.loc)
        when .left_paren?
          parse_closed_call receiver
        else
          parse_open_call receiver
        end
      when .left_paren?
        skip_token
        parse_closed_call receiver
      else
        Call.new(receiver, [] of Node).at(receiver.loc)
      end
    end

    # IDENT ::= ('a'..'z' | '_') ('a'..'z' | 'A'..'Z' | '0'..'9' | '_')*
    private def parse_ident_or_path(token : Token, global : Bool) : Node
      names = [] of Node

      case token.kind
      when .self?
        names << Self.new(global).at(token.loc)
      when .ident?
        names << Ident.new(token.str_value, global).at(token.loc)
      when .instance_var?
        names << InstanceVar.new(token.str_value, global).at(token.loc)
      when .class_var?
        names << ClassVar.new(token.str_value, global).at(token.loc)
      when .keyword?
        names << Ident.new(token.kind.to_s.downcase, global).at(token.loc)
      else
        names << raise token, "unexpected token #{token}"
      end

      while peek_token.kind.period?
        skip_token
        token = next_token_skip space: true

        case token.kind
        when .self?
          names << Self.new(false).at(token.loc)
        when .ident?
          names << Ident.new(token.str_value, false).at(token.loc)
        when .instance_var?
          names << InstanceVar.new(token.str_value, false).at(token.loc)
        when .class_var?
          names << ClassVar.new(token.str_value, false).at(token.loc)
        when Token::Kind::Abstract..Token::Kind::Require
          names << Ident.new(token.kind.to_s.downcase, false).at(token.loc)
        else
          names << raise token, "unexpected token #{token}"
        end
      end

      if names.size > 1
        Path
          .new(names, names[0].as?(Ident).try(&.global?) || false)
          .at(names[0].loc & names[-1].loc)
      else
        names[0]
      end
    end

    # CONST ::= ('A'..'Z') ('a'..'z' | 'A'..'Z' | '0'..'9' | '_')*
    private def parse_const_or_path(token : Token, global : Bool) : Node
      return raise token, "unexpected end of file" if token.kind.eof?

      names = [] of Node
      if token.kind.const?
        names << Const.new(token.str_value, global).at(token.loc)
      else
        names << raise token, "expected token 'const', not '#{token.kind.to_s.downcase}'"
      end
      in_method = false

      while peek_token.kind.period? || peek_token.kind.double_colon?
        global = peek_token.kind.double_colon?
        names << raise peek_token, "unexpected token #{peek_token}" if global && in_method
        skip_token
        token = next_token_skip space: true

        case token.kind
        when .self?
          in_method = true
          names << Self.new(global).at(token.loc)
        when .ident?
          in_method = true
          names << Ident.new(token.str_value, global).at(token.loc)
        when .instance_var?
          in_method = true
          names << InstanceVar.new(token.str_value, global).at(token.loc)
        when .class_var?
          in_method = true
          names << ClassVar.new(token.str_value, global).at(token.loc)
        when Token::Kind::Abstract..Token::Kind::Require
          in_method = true
          names << Ident.new(token.kind.to_s.downcase, global).at(token.loc)
        when .const?
          node = Const.new(token.str_value, global).at(token.loc)
          if in_method
            names << raise node, "unexpected token #{token}"
          else
            names << node
          end
        else
          names << raise token, "unexpected token #{token}"
        end
      end

      if names.size > 1
        Path
          .new(names, names[0].as?(Ident).try(&.global?) || false)
          .at(names[0].loc & names[-1].loc)
      else
        names[0]
      end
    end

    # OPEN_CALL ::= (IDENT | PATH) [EXPRESSION (',' [NEWLINE] EXPRESSION)*]
    private def parse_open_call(receiver : Node) : Node
      args = [] of Node
      named_args = {} of String => Node
      delimited = false
      received = true

      if current_token.kind.symbol_key?
        key = current_token.str_value
        named_args[key] = parse_expression next_token_skip(space: true), :lowest
      else
        args << parse_expression current_token, :lowest
      end

      loop do
        token = peek_token_skip space: true
        case token.kind
        when .eof?, .semicolon?, .right_brace?, .right_paren?, .end?
          break
        when .newline?
          break unless delimited
          next_token_skip space: true
        when .comma?
          args << raise token, "unexpected token ','" if delimited
          next_token_skip space: true
          delimited = true
          received = false
        when .symbol_key?
          key = next_token_skip(space: true).str_value
          node = parse_expression next_token_skip(space: true), :lowest
          if received
            named_args[key] = raise node, "expected a comma after the last argument"
          else
            named_args[key] = node
          end

          delimited = false
          received = true
        else
          node = parse_expression next_token_skip(space: true), :lowest
          if received
            args << raise node, "expected a comma after the last argument"
          else
            args << node
          end

          delimited = false
          received = true
        end
      end

      if delimited && !args.last.is_a?(Error)
        args << raise current_token, "invalid trailing comma in call"
      end

      Call.new(receiver, args, named_args).at(receiver.loc & current_token.loc)
    end

    # CLOSED_CALL ::= (IDENT | PATH) '(' [EXPRESSION (',' [NEWLINE] EXPRESSION)*] ')'
    private def parse_closed_call(receiver : Node) : Node
      skip_token
      args = [] of Node
      named_args = {} of String => Node
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
          args << raise current_token, "unexpected token ','" unless delimited
          delimited = false
          skip_token
        when .symbol_key?
          key = current_token.str_value
          named_args[key] = parse_expression next_token_skip(space: true), :lowest
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

      call = Call.new(receiver, args, named_args).at(receiver.loc & current_token.loc)
      call = raise call, "expected closing parenthesis for call" unless closed

      if peek_token_skip(space: true, newline: true).kind.period?
        next_token_skip space: true, newline: true
        expr = parse_var_or_call next_token_skip(space: true, newline: true), false

        case receiver
        when Call, Const, Ident
          new_receiver = Path.new([call, expr], false).at(call.loc & expr.loc)
          call = Call.new(new_receiver, [] of Node).at(new_receiver.loc)
        when Path
          receiver.names << expr
        else
          raise "BUG: expected Call or Path for closed call; got #{receiver.class}"
        end
      end

      call
    end

    private def parse_begin(start : Token) : Node
      next_token_skip space: true, newline: true, semicolon: true
      body = parse_begin_branch
      ensure_alt = else_alt = nil
      rescues = [] of Rescue
      order = [] of Begin::OrderKind
      done = false

      loop do
        case current_token.kind
        when .eof?
          break
        when .end?
          done = true
          break
        when .ensure?
          order << :ensure
          next_token_skip space: true, newline: true, semicolon: true
          if ensure_alt
            void = VoidExpression.new parse_begin_branch
            ensure_alt << raise void, "duplicate ensure clause for begin"
          else
            ensure_alt = parse_begin_branch
          end
        when .else?
          order << :else
          next_token_skip space: true, newline: true, semicolon: true
          if else_alt
            void = VoidExpression.new parse_begin_branch
            else_alt << raise void, "duplicate else clause for begin"
          else
            else_alt = parse_begin_branch
          end
        when .rescue?
          order << :rescue
          maybe_type = next_token_skip(space: true).kind
          if maybe_type.ident? || maybe_type.const?
            type = parse_var_or_call current_token, false
            next_token_skip space: true, newline: true, semicolon: true
          elsif maybe_type.newline?
            next_token_skip space: true, newline: true
          end

          rescues << Rescue.new(type, parse_begin_branch)
        else
          raise "unexpected token #{current_token}"
        end
      end

      Begin.new(body, rescues, ensure_alt, else_alt, order).at(start.loc & current_token.loc)
    end

    private def parse_begin_branch : Array(Node)
      body = [] of Node

      loop do
        case current_token.kind
        when .eof?
          body << raise current_token, "unexpected end of file"
          break
        when .rescue?, .ensure?, .else?, .end?
          break
        else
          body << parse_expression current_token
        end
      end

      body
    end

    private def parse_command_call(token : Token) : Node
      if token.kind.command_start?
        expr = parse_interpolated_string token
      else
        expr = parse_string token
      end

      receiver = Ident.new("`", false).at(expr.loc)
      Call.new(receiver, [expr]).at(expr.loc)
    end

    private def parse_block(token : Token) : Node
      if token.kind.shorthand?
        call = parse_expression next_token, :lowest
        return Block.new(:shorthand, [] of Node, [call] of Node).at(token.loc & call.loc)
      end

      start_loc = token.loc
      if token.kind.left_brace?
        closing = Token::Kind::RightBrace
        kind = Block::Kind::Braces
      else
        closing = Token::Kind::End
        kind = Block::Kind::DoEnd
      end

      next_token_skip space: true, newline: true

      if current_token.kind.bit_or?
        next_token_skip space: true
        args = parse_block_args_until :bit_or
      else
        args = [] of Node
      end

      body = [] of Node

      loop do
        break if current_token.kind == closing
        return raise token, "unexpected end of file" if current_token.kind.eof?

        body << parse_expression current_token
      end

      end_loc = current_token.loc
      skip_token

      Block.new(kind, args, body).at(start_loc & end_loc)
    end

    private def parse_block_args_until(stop_kind : Token::Kind) : Array(Node)
      args = [] of Node
      delimited = true
      done = false

      loop do
        case current_token.kind
        when .eof?
          break
        when .space?
          next_token_skip space: true
        when .comma?
          args << raise current_token, "unexpected token ','" unless delimited
          delimited = false
          next_token_skip space: true
        when .left_paren?
          start = current_token.loc
          next_token_skip space: true
          inner = parse_block_args_until :right_paren
          args << UnpackedArgs.new(inner).at(start & current_token.loc)
        when .ident?, .underscore?
          if current_token.kind.underscore?
            args << Underscore.new.at(current_token.loc)
          else
            args << parse_ident_or_path current_token, false
          end

          token = peek_token_skip space: true
          case token.kind
          when .eof?
            break
          when .comma?
            delimited = true
            next_token_skip space: true
          when stop_kind
            done = true
            next_token_skip space: true
          else
            raise "Unexpected token #{token}"
          end
        when stop_kind
          done = true
          next_token_skip space: true, newline: true
          break
        else
          raise "Unexpected token #{current_token}"
        end
      end

      raise "Missing closing argument character #{stop_kind}" unless done

      args
    end

    private def parse_integer(token : Token) : Node
      case value = token.raw_value
      when String
        if value =~ /[fiu]\d+/
          IntLiteral
            .new(value.rchop($0).to_i64(strict: false), IntLiteral::Base.from($0))
            .at(token.loc)
        else
          IntLiteral.new(value.to_i64(strict: false), :dynamic).at(token.loc)
        end
      when Int64
        IntLiteral.new(value, :dynamic).at(token.loc)
      else
        raise "BUG: type '#{value.class}' lexed for integer"
      end
    end

    private def parse_invalid_integer(token : Token) : Node
      raise IntLiteral.new(token.str_value.split(/i|u/)[0].to_i64, :invalid).at(token.loc),
        "invalid integer literal suffix"
    end

    private def parse_float(token : Token) : Node
      value = token.str_value
      base = value.ends_with?("f64") ? FloatLiteral::Base::F64 : FloatLiteral::Base::F32

      FloatLiteral.new(value.to_f64(strict: false), base).at(token.loc)
    end

    private def parse_invalid_float(token : Token) : Node
      raise FloatLiteral.new(token.str_value.split('f')[0].to_f64, :invalid).at(token.loc),
        "invalid float literal suffix"
    end

    private def parse_string(token : Token) : Node
      StringLiteral.new(token.str_value).at(token.loc)
    end

    private def parse_interpolated_string(token : Token) : Node
      next_token_skip space: true, newline: true
      parts = [parse_string token] of Node
      start = token.loc

      loop do
        case current_token.kind
        when .eof?
          parts << raise current_token, "unterminated quote string"
        when .string_end?
          parts << parse_string current_token
          break
        else
          parts << parse_expression current_token
        end
      end

      StringInterpolation.new(parts).at(start & current_token.loc)
    end

    private def parse_bool(token : Token) : Node
      BoolLiteral.new(token.kind.true?).at(token.loc)
    end

    private def parse_char(token : Token) : Node
      CharLiteral.new(token.char_value).at(token.loc)
    end

    private def parse_symbol(token : Token) : Node
      SymbolLiteral.new(token.str_value, token.kind.quoted_symbol?).at(token.loc)
    end

    private def parse_symbol_key(token : Token) : Node
      SymbolKey.new(token.str_value).at(token.loc)
    end

    private def parse_nil(token : Token) : Node
      NilLiteral.new.at(token.loc)
    end

    private def parse_annotation(token : Token) : Node
      call = parse_const_or_path next_token_skip(space: true), true

      if call.is_a?(Error) && current_token.kind.eof?
        return Annotation.new(call).at(token.loc & call.loc)
      end

      case next_token_skip(space: true).kind
      when .eof?
        call = raise current_token, "unexpected end of file"
        end_loc = current_token.loc
      when .right_bracket?
        end_loc = current_token.loc
        next_token_skip space: true, newline: true
      else
        call = raise current_token, "unexpected token #{current_token}"
        end_loc = current_token.loc
        next_token_skip space: true, newline: true
      end

      Annotation.new(call).at(token.loc & end_loc)
    end

    private def parse_grouped_expression : Node
      start = current_token.loc
      expr = parse_expression next_token_skip(space: true), :lowest

      if expr.is_a? Call
        next_token_skip space: true
      end

      case current_token.kind
      when .right_paren?
        GroupedExpression.new(expr).at(start & current_token.loc)
      when .eof?
        raise expr, "unexpected end of file"
      else
        raise current_token, "expected closing parenthesis after expression"
      end
    end

    private def parse_array_literal(token : Token) : Node
      next_token_skip space: true, newline: true
      values = [] of Node
      start = token.loc
      delimited = true
      done = false

      loop do
        case current_token.kind
        when .eof?
          break
        when .right_bracket?
          done = true
          break
        when .space?
          next_token_skip space: true, newline: true
        when .comma?
          values << raise current_token, "unexpected token ','" unless delimited
          delimited = false
          next_token_skip space: true, newline: true
        else
          node = parse_expression current_token
          if delimited
            values << node
            delimited = false
          else
            values << raise node, "expected a comma before expression"
          end

          if current_token.kind.comma?
            delimited = true
            next_token_skip space: true, newline: true
          end
        end
      end

      end_loc = current_token.loc
      if peek_token_skip(space: true).kind.of?
        next_token_skip space: true
        of_type = parse_const_or_path next_token_skip(space: true), false
        end_loc = of_type.loc
      end

      node = ArrayLiteral.new(values, of_type, false).at(start & end_loc)
      unless done
        node = raise node, "missing closing bracket for array literal"
      end

      if values.empty? && !of_type
        node = raise node, "an empty array literal must have an explicit type"
      end

      node
    end

    private def parse_percent_array_literal(token : Token) : Node
      values = token.str_value.split %r[(?<!\\)\s+]
      values.each_with_index do |value, index|
        values[index] = " " if value == "\\ "
      end

      if token.kind.string_array?
        values = values.map { |v| StringLiteral.new(v).at(token.loc) }
        of_type = Const.new("String", true).at(token.loc)
      else
        values = values.map { |v| SymbolLiteral.new(v, true).at(token.loc) }
        of_type = Const.new("Symbol", true).at(token.loc)
      end

      ArrayLiteral.new(values.unsafe_as(Array(Node)), of_type, true).at(token.loc)
    end

    private def parse_hash_or_tuple_literal(token : Token) : Node
      if next_token_skip(space: true, newline: true).kind.right_brace?
        return parse_hash_literal token.loc, nil
      end

      node = parse_expression current_token
      case current_token.kind
      when .eof?
        raise current_token, "unexpected end of file"
      when .comma?, .right_brace?
        parse_tuple_literal token.loc, node
      when .symbol_key?
        raise "unimplemented"
        # parse_named_tuple_literal token.loc, node
      else
        parse_hash_literal token.loc, node
      end
    end

    private def parse_tuple_literal(start : Location, node : Node) : Node
      if current_token.kind.right_brace?
        expr = TupleLiteral.new([node] of Node, [] of Node).at(start & current_token.loc)
        next_token_skip space: true, newline: true
        return expr
      end

      next_token_skip space: true, newline: true
      values = [node] of Node
      delimited = true
      done = false

      loop do
        case current_token.kind
        when .eof?
          break
        when .right_brace?
          done = true
          break
        when .comma?
          values << raise current_token, "unexpected token ','" unless delimited
          delimited = false
          next_token_skip space: true, newline: true
        else
          node = parse_expression current_token
          if delimited
            values << node
            delimited = false
          else
            values << raise node, "expected a comma before expression"
          end

          if current_token.kind.comma?
            delimited = true
            next_token_skip space: true, newline: true
          end
        end
      end

      node = TupleLiteral.new(values, [] of Node).at(start & current_token.loc)
      if done
        next_token_skip space: true, newline: true
      else
        node = raise node, "missing closing brace for tuple literal"
      end

      node
    end

    private def parse_hash_literal(start : Location, key : Node?) : Node
      unless key
        of_type = parse_hash_explicit_typing
        return HashLiteral.new([] of Node, of_type).at(start & of_type.loc)
      end

      case current_token.kind
      when .eof?
        return raise current_token, "unexpected end of file"
      when .rocket?
        value = parse_expression next_token_skip(space: true, newline: true)
      else
        value = parse_expression current_token
        value = raise value, "expected token '=>' before value"
      end

      entries = [HashLiteral::Entry.new(key, value).at(key.loc & value.loc)] of Node
      delimited = true
      done = false

      loop do
        case current_token.kind
        when .eof?
          break
        when .right_brace?
          done = true
          break
        when .comma?
          entries << raise current_token, "unexpected token ','" unless delimited
          delimited = false
          next_token_skip space: true, newline: true
        else
          key = parse_expression current_token

          case current_token.kind
          when .eof?
            entries << HashLiteral::Entry.new(key, raise current_token, "unexpected end of file")
              .at(key.loc & current_token.loc)
            break
          when .rocket?
            value = parse_expression next_token_skip(space: true, newline: true)
          else
            value = parse_expression current_token
            value = raise value, "expected token '=>' before value"
          end

          node = HashLiteral::Entry.new(key, value).at(key.loc & value.loc)
          if delimited
            entries << raise node, "expected a comma before expression"
          else
            entries << node
            delimited = false
          end

          if current_token.kind.comma?
            delimited = true
            next_token_skip space: true, newline: true
          end
        end
      end

      node = HashLiteral.new(entries, nil).at(start & current_token.loc)
      if done
        if peek_token_skip(space: true).kind.of?
          node.of_type = parse_hash_explicit_typing.tap do |type|
            node.loc &= type.loc
          end
          next_token_skip(space: true, newline: true) unless current_token.kind.eof?
        end
      else
        node = raise node, "missing closing brace for tuple literal"
      end

      node
    end

    private def parse_hash_explicit_typing : Node
      case next_token_skip(space: true).kind
      when .eof?
        return raise current_token, "unexpected end of file"
      when .of?
        # expected
      else
        return raise current_token, "for empty hashes use '{} of KeyType => ValueType'"
      end

      case next_token_skip(space: true).kind
      when .eof?
        return raise current_token, "unexpected end of file"
      when .const?
        key_type = parse_const_or_path current_token, false
      when .underscore?
        key_type = raise current_token, "can't use underscore as generic type argument"
      else
        return raise current_token, "unexpected token #{current_token.inspect}"
      end

      case next_token_skip(space: true).kind
      when .eof?
        return raise current_token, "unexpected end of file"
      when .rocket?
        # expected
      else
        return raise current_token, "unexpected token #{current_token.inspect}"
      end

      case next_token_skip(space: true).kind
      when .eof?
        return raise current_token, "unexpected end of file"
      when .const?
        value_type = parse_const_or_path current_token, false
      when .underscore?
        value_type = raise current_token, "can't use underscore as generic type argument"
      else
        return raise current_token, "unexpected token #{current_token.inspect}"
      end

      HashLiteral::Entry.new(key_type, value_type).at(key_type.loc & value_type.loc)
    end

    private def parse_proc(token : Token) : Node
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
          params << Parameter.new(pname, nil, type, nil, false)
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
      body = [] of Node

      loop do
        break if token.kind == closing_token
        raise "unexpected end of file" if token.kind.eof?

        body << parse_expression token
        token = current_token
      end

      skip_token
      ProcLiteral.new(params, body).at(start & token.loc)
    end
  end
end
