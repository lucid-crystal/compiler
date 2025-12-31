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

    @errors : Array(Error)
    @tokens : Array(Token)
    @fail_first : Bool
    @pos : Int32 = 0
    @heredocs : Array(Heredoc)

    def self.parse(tokens : Array(Token), *, fail_first : Bool = false) : Program
      new(tokens, fail_first).parse
    end

    private def initialize(@tokens : Array(Token), @fail_first : Bool)
      @errors = [] of Error
      @heredocs = [] of Heredoc
    end

    def parse : Program
      nodes = [] of Node

      loop do
        break if current_token.kind.eof?
        break unless node = parse? current_token
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

    private def peek_token : Token
      @tokens[@pos + 1]
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

    private def skip_token : Nil
      @pos += 1
    end

    private def raise(target : Token | Node, message : String) : Node | NoReturn
      if @fail_first
        raise Parser::Exception.new target, message
      else
        @errors << (node = Error.new(target, message).at(target.loc))
        node
      end
    end

    private def parse(token : Token) : Node
      parse?(token) || raise "unexpected end of file"
    end

    private def parse?(token : Token) : Node?
      unless @heredocs.empty?
        @heredocs.each do |node|
          parse_heredoc node
        end
        @heredocs.clear
        token = current_token
      end

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
        parse_chainable token
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
      name = parse_callable next_token_skip(space: true), false
      next_token_skip space: true, newline: true, semicolon: true

      parse_namespace token.loc, ModuleDef.new name
    end

    private def parse_class_or_struct(start : Token) : Node
      name = parse_callable next_token_skip(space: true), false
      token = next_token_skip space: true, newline: true, semicolon: true

      if token.kind.lesser?
        superclass = parse_callable next_token_skip(space: true), false
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
      name = parse_callable next_token_skip(space: true), false
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
                pname = parse_callable token, false
                token = next_token_skip space: true
              else
                pname = NilLiteral.new
              end
            else
              block = false
              pname = parse_callable token, false
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
              internal = parse_callable token, false
              token = next_token_skip space: true
            end

            if token.kind.colon?
              type = parse_callable next_token_skip(space: true), false
              token = next_token_skip space: true
            end

            if token.kind.assign?
              value = parse next_token_skip space: true
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
        return_type = parse_callable next_token_skip(space: true), false
        token = next_token_skip space: true
      end

      if token.kind.forall?
        loop do
          token = next_token_skip space: true
          node = parse_callable token, false

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

        body << parse token
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
        node = parse(token).as(Node) # TODO: replace with parse method
      end

      if start.kind.include?
        Include.new(node).at(start.loc & node.loc)
      else
        Extend.new(node).at(start.loc & node.loc)
      end
    end

    private def parse_alias(token : Token) : Node
      name = parse_callable next_token_skip(space: true), true

      if name.is_a?(Error) && current_token.kind.eof?
        return Alias.new(name, name).at(token.loc & name.loc)
      end

      case next_token_skip(space: true).kind
      when .eof?
        type = raise current_token, "unexpected end of file"
      when .assign?
        type = parse_callable next_token_skip(space: true), true
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
        node = parse_callable current_token, true
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

    private def parse_chainable(token : Token) : Node
      left = parse_prefix(token) || raise token, "cannot parse expression #{token}"

      loop do
        break if current_token.kind.eof?
        token = next_token_skip space: true, newline: true

        break unless token.operator?
        left = parse_infix token, left
      end

      left
    end

    private def parse_prefix(token : Token) : Node?
      case token.kind
      when .double_colon?
        parse_var_or_call(next_token_skip(space: true), true).tap do |node|
          node.loc = token.loc & node.loc
        end
      when .ident?, .const?, .self?, .underscore?, .instance_var?, .class_var?, .pseudo?
        parse_var_or_call token, false
      when .command?, .command_start?     then parse_command_call token
      when .shorthand?                    then parse_block token
      when .integer?                      then parse_integer token
      when .integer_bad_suffix?           then parse_invalid_integer token
      when .float?                        then parse_float token
      when .float_bad_suffix?             then parse_invalid_float token
      when .string?, .string_part?        then parse_string token
      when .heredoc?, .heredoc_escaped?   then parse_heredoc_marker token
      when .string_start?, .regex_start?  then parse_interpolated token
      when .regex?                        then parse_regex token
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
      end
    end

    private def parse_infix(token : Token, left : Node) : Node
      if token.kind.period?
        call = parse_var_or_call next_token_skip(space: true, newline: true), false
        if call.is_a? Call
          call.tap &.receiver = left
        else
          Call.new(call, left, [] of Node).at(left.loc & call.loc)
        end
      else
        op = Infix::Operator.from token.kind
        error = "invalid infix operator '#{token.kind}'" if op.invalid?
        right = parse next_token_skip space: true
        infix = Infix.new(op, left, right).at(left.loc & right.loc)
        infix = raise infix, error if error
        skip_token unless current_token.kind.eof?

        infix
      end
    end

    private def parse_var_or_call(token : Token, global : Bool) : Node
      name = parse_callable token, global
      token = next_token_skip space: true

      case token.kind
      when .eof?, .newline?, .comma?, .semicolon?, .right_paren?, .right_brace?, .end?
        if name.is_a? Path
          name.into_call
        else
          Call.new(name, nil, [] of Node).at(name.loc)
        end
      when .colon?
        case node = parse_var_or_call next_token_skip(space: true), false
        when Assign
          Var.new(name, node.target, node.value).at(name.loc & node.loc)
        when Call # TODO: need to review/revert back to ident/const/path
          Var.new(name, node, nil).at(name.loc & node.loc)
        else
          raise "BUG: expected Assign, Ident or Const; got #{node.class}"
        end
      when .assign?
        node = parse next_token_skip space: true
        Assign.new(name, node).at(name.loc & node.loc)
      when .do?, .left_brace?
        node = parse_block token
        Call.new(name, [node]).at(name.loc & node.loc)
      when .left_paren?
        skip_token
        if name.is_a? Path
          parse_closed_call name.into_call
        else
          parse_closed_call name
        end
      else
        if name.is_a? Path
          parse_open_call name.into_call
        else
          parse_open_call name
        end
      end
    end

    private def parse_callable(token : Token, global : Bool) : Node
      parts = [] of Node

      case token.kind
      when .self?
        parts << Self.new(global).at(token.loc)
      when .ident?
        parts << Ident.new(token.str_value, global).at(token.loc)
      when .const?
        parts << Const.new(token.str_value, global).at(token.loc)
      when .instance_var?
        parts << InstanceVar.new(token.str_value, global).at(token.loc)
      when .class_var?
        parts << ClassVar.new(token.str_value, global).at(token.loc)
      when .keyword?
        parts << Ident.new(token.kind.to_s.downcase, global).at(token.loc)
      else
        parts << raise token, "unexpected token #{token}"
      end

      in_method = !token.kind.const?

      while peek_token.kind.period? || peek_token.kind.double_colon?
        global = peek_token.kind.double_colon?
        parts << raise peek_token, "unexpected token #{peek_token}" if global && in_method
        skip_token
        token = next_token_skip space: true

        case token.kind
        when .self?
          in_method = true
          parts << Self.new(global).at(token.loc)
        when .ident?
          in_method = true
          parts << Ident.new(token.str_value, global).at(token.loc)
        when .instance_var?
          in_method = true
          parts << InstanceVar.new(token.str_value, global).at(token.loc)
        when .class_var?
          in_method = true
          parts << ClassVar.new(token.str_value, global).at(token.loc)
        when Token::Kind::Abstract..Token::Kind::Require
          in_method = true
          parts << Ident.new(token.kind.to_s.downcase, global).at(token.loc)
        when .const?
          node = Const.new(token.str_value, global).at(token.loc)
          if in_method
            parts << raise node, "unexpected token #{token}"
          else
            parts << node
          end
        else
          parts << raise token, "unexpected token #{token}"
        end
      end

      if parts.size == 1
        parts[0]
      else
        Path
          .new(parts, parts[0].as?(Ident).try(&.global?) || false)
          .at(parts[0].loc & parts[-1].loc)
      end
    end

    private def parse_open_call(method : Node) : Node
      args = [] of Node
      delimited = false
      received = true

      if current_token.kind.symbol_key?
        key = current_token.str_value
        args << NamedArg.new key, parse next_token_skip space: true
      else
        args << parse current_token
      end

      last_comma : Token? = nil

      loop do
        case current_token.kind
        when .eof?, .semicolon?, .right_brace?, .right_paren?, .end?
          # TODO: may need to review
          break
        when .newline?
          break unless delimited
          next_token_skip space: true
        when .comma?
          args << raise current_token, "unexpected token ','" if delimited
          last_comma = current_token
          next_token_skip space: true
          delimited = true
          received = false
        when .symbol_key?
          key = current_token.str_value
          node = parse next_token_skip(space: true)
          if received
            args << NamedArg.new key, raise(node, "expected a comma after the last argument")
          else
            args << NamedArg.new key, node
          end

          delimited = false
          received = true
        else
          node = parse current_token
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
        args << raise (last_comma || current_token), "invalid trailing comma in call"
      end

      Call.new(method, args).at(method.loc & current_token.loc)
    end

    private def parse_closed_call(method : Node) : Node
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
          args << raise current_token, "unexpected token ','" unless delimited
          delimited = false
          skip_token
        when .symbol_key?
          key = current_token.str_value
          args << NamedArg.new key, parse next_token_skip space: true
          case current_token.kind
          when .eof?
            break
          when .comma?
            delimited = true
            skip_token
          when .right_paren?
            closed = true
            break
          else
            raise "Unexpected token #{current_token}"
          end
        else
          args << parse current_token
          case current_token.kind
          when .eof?
            break
          when .comma?
            delimited = true
            skip_token
          when .right_paren?
            closed = true
            break
          else
            raise "Unexpected token #{current_token}"
          end
        end
      end

      call = Call.new(method, args).at(method.loc & current_token.loc)
      call = raise call, "expected closing parenthesis for call" unless closed

      call
    end

    private def parse_command_call(token : Token) : Node
      if token.kind.command_start?
        expr = parse_interpolated token
      else
        expr = parse_string token
      end

      receiver = Ident.new("`", false).at(expr.loc)
      Call.new(receiver, [expr]).at(expr.loc)
    end

    private def parse_block(token : Token) : Node
      if token.kind.shorthand?
        call = parse next_token
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

        body << parse current_token
        if current_token.kind.space? || current_token.kind.newline?
          next_token_skip space: true, newline: true
        end
      end

      end_loc = current_token.loc
      skip_token

      Block.new(kind, args, body).at(start_loc & end_loc)
    end

    private def parse_block_args_until(stop_kind : Token::Kind) : Array(Node)
      args = [] of Node
      delimited = false
      done = false

      # TODO: comma edge cases
      loop do
        case current_token.kind
        when .eof?
          break
        when .space?
          next_token_skip space: true
        when .comma?
          args << raise current_token, "unexpected token ','" if delimited
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
            next_token_skip space: true
          else
            args << parse_callable current_token, false
          end
          delimited = false
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

    private def parse_heredoc_marker(token : Token) : Node
      @heredocs << (node = Heredoc.new(token.str_value, token.kind.heredoc_escaped?).at(token.loc))
      next_token

      node
    end

    private def parse_heredoc(doc : Heredoc) : Nil
      if current_token.kind.string?
        str = current_token.str_value
        if str.ends_with? ' '
          lines = str.lines
          indent = lines[-1]

          if lines.select(&.presence).all?(&.starts_with? indent)
            lines.map! &.lchop indent
            doc.value = StringLiteral.new(lines.join('\n').chomp).at(current_token.loc)
          else
            error = "heredoc line must have an indent greater than or equal to #{indent.size}"
            doc.value = raise parse_string(current_token), error
          end
        else
          doc.value = parse_string current_token
        end

        return next_token_skip space: true, newline: true
      end

      parts = [] of Node
      until current_token.kind.string_end?
        parts << parse current_token
      end
      parts << parse_string current_token
      next_token_skip space: true, newline: true

      str = parts[-1].as(StringLiteral)
      lines = str.value.lines
      str.value = str.value.lchop('\n').rchop('\n')

      if lines[-1].blank?
        indent = lines[-1]
        error = "heredoc line must have an indent greater than or equal to #{indent.size}"

        parts.each_with_index do |str, index|
          next unless str.is_a? StringLiteral
          if str.value.starts_with? indent
            str.value = str.value.lchop(indent).rchop(indent)
          else
            parts[index] = raise str, error
          end
        end
      end

      doc.value = StringInterpolation.new(parts).at(parts[0].loc & parts[-1].loc)
    end

    private def parse_regex(token : Token) : Node
      RegexLiteral.new(token.str_value).at(token.loc)
    end

    private def parse_interpolated(token : Token) : Node
      next_token_skip space: true, newline: true
      parts = [parse_string token] of Node
      start = token.loc

      error = case token.kind
              when .string_start?  then "unterminated string literal"
              when .command_start? then "unterminated command literal"
              when .regex_start?   then "unterminated regular expression"
              else                      raise "unreachable"
              end

      loop do
        case current_token.kind
        when .eof?
          parts << raise current_token, error
        when .string_end?
          parts << parse_string current_token
          break
        else
          parts << parse current_token
        end
      end

      if token.kind.regex_start?
        RegexInterpolation.new(parts).at(start & current_token.loc)
      else
        StringInterpolation.new(parts).at(start & current_token.loc)
      end
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
      call = parse_callable next_token_skip(space: true), true

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
      # expr = parse next_token_skip(space: true), :lowest
      expr = parse next_token_skip space: true

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
          node = parse current_token
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
        of_type = parse_callable next_token_skip(space: true), false
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

      node = parse current_token
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
          node = parse current_token
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
        value = parse next_token_skip(space: true, newline: true)
      else
        value = parse current_token
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
          key = parse current_token

          case current_token.kind
          when .eof?
            entries << HashLiteral::Entry.new(key, raise current_token, "unexpected end of file")
              .at(key.loc & current_token.loc)
            break
          when .rocket?
            value = parse next_token_skip(space: true, newline: true)
          else
            value = parse current_token
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
        key_type = parse_callable current_token, false
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
        value_type = parse_callable current_token, false
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

          pname = parse_callable token, false
          token = next_token_skip space: true
          unless token.kind.colon?
            raise "expected a colon after parameter name; got #{token}"
          end

          type = parse_callable next_token_skip(space: true), false
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

        body << parse token
        token = current_token
      end

      skip_token
      ProcLiteral.new(params, body).at(start & token.loc)
    end
  end
end
