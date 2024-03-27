module Lucid::Compiler
  class Parser
    VALID_OPERATORS = {"+", "-", "*", "**", "/", "//"}

    @tokens : Array(Token)
    @pos : Int32

    def self.parse(tokens : Array(Token)) : Array(Node)
      new(tokens).parse
    end

    private def initialize(@tokens : Array(Token))
      @pos = -1
    end

    def parse : Array(Node)
      nodes = [] of Node

      loop do
        break unless node = next_node
        nodes << node
      end

      nodes
    end

    private def next_node : Node?
      return unless token = next_token?
      parse_token token
    end

    private def next_token? : Token?
      @tokens[@pos += 1]?
    end

    private def next_token_no_space : Token?
      return unless token = next_token?

      case token.kind
      when .space?, .newline?
        next_token_no_space
      else
        token
      end
    end

    private def parse_token(token : Token) : Node?
      case token.kind
      when .space?, .newline?
        next_node
      when .ident?
        parse_ident_or_call token
      when .string?
        StringLiteral.new(token.value).at(token.loc)
      when .number? # TODO: split into integer & float
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

    private def parse_ident_or_call(token : Token) : Node
      next_token = next_token_no_space
      raise "unexpected EOF" unless next_token

      case next_token.kind
      when .colon?
        next_token = next_token_no_space
        raise "unexpected EOF" unless next_token

        Var.new(token.value, next_token.value, nil).at(token.loc)
      when .assign?
        node = next_node || raise "unexpected End of File"

        Assign.new(token.value, node).at(token.loc)
      else
        parse_call token, next_token
      end
    end

    private def parse_call(token : Token, from : Token) : Node
      args = [] of Node
      with_paren = from.kind.left_paren?
      @pos -= 1 unless with_paren

      loop do
        unless next_token = next_token?
          @pos -= 1
          break
        end

        case next_token.kind
        when .newline? # TODO: handle newline calls
          break
        when .right_paren?
          break if with_paren
          raise "unexpected closing parenthesis"
        when .comma?
          next
        else
          node = parse_token next_token
          break unless node
          args << node

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

      # left = @prev || raise "missing left-hand expression for operator #{value}"
      # right = next_node || raise "missing right-hand expression for operator #{value}"

      Op.new(value, Nop.new, Nop.new).at(token.loc)
    end
  end
end
