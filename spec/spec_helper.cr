require "spec"
require "../src/compiler"

macro seq!(*kinds)
  [{{ *kinds }}] of Compiler::Token::Kind
end

def assert_token_sequence(sequence : Array(Compiler::Token::Kind), for input : String) : Nil
  kinds = Compiler::Lexer.new(input).run.map &.kind
  kinds.should eq sequence
end

def assert_node_sequence(sequence : Array(Compiler::Node.class), for input : String) : Nil
  tokens = Compiler::Lexer.new(input).run
  nodes = Compiler::Parser.new(tokens).parse

  sequence.each_with_index do |cls, index|
    nodes[index].class.should eq cls
  end
end
