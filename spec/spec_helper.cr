require "spec"
require "../src/compiler"

macro seq!(*kinds)
  [{{ kinds.splat }}] of Lucid::Compiler::Token::Kind
end

def assert_token(token : Lucid::Compiler::Token::Kind, for input : String) : Nil
  kind = Lucid::Compiler::Lexer.run(input).map &.kind
  kind.should eq [token]
end

def assert_token_sequence(sequence : Array(Lucid::Compiler::Token::Kind), for input : String) : Nil
  kinds = Lucid::Compiler::Lexer.run(input).map &.kind
  kinds.should eq sequence
end

def assert_node_sequence(sequence : Array(Lucid::Compiler::Node.class), for input : String) : Nil
  tokens = Lucid::Compiler::Lexer.run input
  nodes = Lucid::Compiler::Parser.new(tokens).parse

  sequence.each_with_index do |cls, index|
    nodes[index].class.should eq cls
  end
end
