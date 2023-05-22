module Compiler
  class Parser
    VALID_OPERATORS = {"+", "-", "*", "/"}

    @tokens : Array(Token)
    @prev : Node?
    @pos : Int32

    def initialize(@tokens : Array(Token))
      @pos = -1
    end

    def parse : Array(Node)
      nodes = [] of Node

      loop do
        break unless node = next_node
        break if node.is_a? Nop
        nodes << node
        @prev = node
      end

      nodes
    end

    private def next_node : Node?
      parse_token next_token
    end

    private def next_token : Token
      @tokens[@pos += 1]
    end

    private def next_token_skip_space : Token
      loop do
        token = next_token
        case token.kind
        when .space?, .newline?
          next
        else
          return token
        end
      end
    end

    private def parse_token(token : Token) : Node?
      case token.kind
      when .eof?
        Nop.new.at(token.loc)
      when .space?, .newline?
        next_node
      when .ident?
        parse_ident_or_call token
      when .string?
        StringLiteral.new(token.value).at(token.loc)
      when .number?
        if token.value.includes? '.'
          FloatLiteral.new(token.value).at(token.loc)
        else
          IntLiteral.new(token.value).at(token.loc)
        end
      when Token::Kind::Nil # .nil? doesn't work here
        NilLiteral.new.at(token.loc)
      when .operator?
        parse_operator token
      end
    end

    private def expect_next(*kinds : Token::Kind, allow_space : Bool = false, allow_end : Bool = false) : Token
      loop do
        token = next_token
        case token.kind
        when .eof?
          raise "unexpected End of File" unless allow_end
          return token
        else
          return token if kinds.includes? token.kind
          next if token.kind.space? && allow_space

          raise "expected token#{"s" if kinds.size > 1} #{kinds.join " or "}; got #{token.kind}"
        end
      end
    end

    private def parse_ident_or_call(token : Token) : Node
      _next = next_token_skip_space
      case _next.kind
      when .colon?
        _next = next_token_skip_space
        Var.new(token.value, _next.value, nil).at(token.loc)
      when .equal?
        node = next_node || raise "unexpected End of File"
        Assign.new(token.value, node).at(token.loc)
      else
        parse_call token, _next
      end
    end

    private def parse_call(token : Token, from : Token) : Node
      args = [] of Node
      with_paren = from.kind.left_paren?
      @pos -= 1 unless with_paren

      loop do
        _next = next_token
        case _next.kind
        when .eof?
          @pos -= 1
          break
        when .newline? # TODO: handle newline calls
          break
        when .right_paren?
          break if with_paren
          raise "unexpected closing parenthesis"
        when .comma?
          next
        else
          node = parse_token _next
          break unless node
          args << node
          @prev = node

          # TODO: workaround this for now
          # expect_next :comma, :right_paren, allow_space: true, allow_end: true
          # @pos -= 1
        end
      end

      Call.new(token.value, args).at(token.loc)
    end

    private def parse_operator(token : Token) : Node
      # TODO: implement OpAssign
      # assign = false

      value = token.value
      if token.value.ends_with? '='
        value = value.byte_slice 1
        # assign = true
      end

      raise "invalid operator #{value.inspect}" unless VALID_OPERATORS.includes? value

      left = @prev || raise "missing left-hand expression for operator #{value}"
      right = next_node || raise "missing right-hand expression for operator #{value}"

      Op.new(value, left, right).at(token.loc)
    end
  end
end
