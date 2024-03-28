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

    private def peek_token? : Token?
      @tokens[@pos + 1]?
    end

    private def peek_token_no_space(offset : Int32 = 1) : Token?
      return unless token = @tokens[@pos + offset]?

      case token.kind
      when .space?, .newline?
        peek_token_no_space offset + 1
      else
        token
      end
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
      when .integer?
        node = IntLiteral.new(token.value).at(token.loc)
        if peek_token_no_space.try &.kind.operator?
          parse_infix node
        else
          node
        end
      when .float?
        node = FloatLiteral.new(token.value).at(token.loc)
        if peek_token_no_space.try &.kind.operator?
          parse_infix node
        else
          node
        end
      when Token::Kind::Nil # .nil? doesn't work here
        NilLiteral.new.at(token.loc)
      when .operator?
        parse_prefix token
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
      delimited = true
      with_paren = from.kind.left_paren?

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
        when .space?, .newline?
          next
        when .comma?
          delimited = true
        when .right_paren?
          closed = true
          break
        else
          raise "expected a comma after the last argument" unless delimited
          delimited = false

          break unless node = parse_token next_token
          args << node
        end
      end

      raise "expected closing parenthesis for call" unless closed

      Call.new(token.value, args).at(token.loc)
    end

    private def parse_prefix(token : Token) : Node
      value = next_node || raise "unexpected EOF"
      Prefix.new(token.value, value).at(token.loc & value.loc)
    end

    private def parse_infix(left : Node) : Node
      op = next_token_no_space || raise "unexpected EOF"
      right = next_node || raise "unexpected EOF"

      Infix.new(op.value, left, right).at(left.loc & right.loc)
    end
  end
end
