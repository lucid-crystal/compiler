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
        parse_visibility_expression token
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

    private def parse_visibility_expression(token : Token) : Node
      # start = token.loc # TODO: merge start loc into result node
      is_private = token.kind.private?
      is_protected = token.kind.protected?
      is_abstract = token.kind.abstract?

      loop do
        token = next_token_skip space: true
        case token.kind
        when .eof?
          return raise token, "unexpected end of file"
        when .private?
          return raise token, "unexpected token 'private'" if is_private
          return raise token, "cannot apply protected and private visibility" if is_protected

          is_private = true
        when .protected?
          return raise token, "unexpected token 'protected'" if is_protected
          return raise token, "cannot apply private and protected visibility" if is_private

          is_protected = true
        when .abstract?
          return raise token, "unexpected token 'abstract'" if is_abstract

          is_abstract = true
        else
          break
        end
      end

      if token.kind.def? && is_abstract
        node = parse_def token, true
      else
        node = parse token
      end

      case node
      when Def
        node.private = is_private
        node.protected = is_protected
      else
        return raise node.as(Node), "visibility modifier cannot be applied to #{node.class}"
      end

      node
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
             when .ident?, .const?, .self?, .underscore?, .instance_var?, .class_var?
               parse_var_or_call token, false
             when .integer?                 then parse_integer token
             when .integer_bad_suffix?      then parse_invalid_integer token
             when .float?                   then parse_float token
             when .float_bad_suffix?        then parse_invalid_float token
             when .string?                  then parse_string token
             when .true?, .false?           then parse_bool token
             when .char?                    then parse_char token
             when .symbol?, .quoted_symbol? then parse_symbol token
             when .symbol_key?              then parse_symbol_key token
             when .is_nil?                  then parse_nil token
             when .left_paren?              then parse_grouped_expression
             when .annotation_open?         then parse_annotation token
             when .proc?                    then parse_proc token
             when .magic_line?              then parse_integer token
             when .magic_dir?               then parse_string token
             when .magic_file?              then parse_string token
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
      infix
    end

    # VAR ::= (IDENT | PATH) [':' (CONST | PATH)] ['=' EXPRESSION]
    #
    # CALL ::= OPEN_CALL | CLOSED_CALL
    #
    # PATH ::= [(['::'] CONST)+ '.'] IDENT ('.' IDENT)*
    private def parse_var_or_call(token : Token, global : Bool) : Node
      case token.kind
      when .ident?, .self?, .instance_var?, .class_var?, Token::Kind::Abstract..Token::Kind::Require
        receiver = parse_ident_or_path token, global
      when .const?
        receiver = parse_const_or_path token, global
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
      when Token::Kind::Abstract..Token::Kind::Require
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
        when .eof?, .semicolon?, .right_brace?, .end?
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
      expr = parse_expression next_token_skip(space: true), :lowest

      unless next_token_skip(space: true).kind.right_paren?
        raise "expected closing parenthesis after expression"
      end

      expr
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
