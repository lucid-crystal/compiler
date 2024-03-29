require "spec"
require "../src/compiler"

alias LC = Lucid::Compiler

macro seq!(*kinds)
  [{{ kinds.splat }}] of LC::Token::Kind
end

def assert_token(token : LC::Token::Kind, for input : String) : Nil
  kind = LC::Lexer.run(input).map &.kind
  kind.should eq [token]
end

def assert_token_sequence(sequence : Array(LC::Token::Kind), for input : String) : Nil
  kinds = LC::Lexer.run(input).map &.kind
  kinds.should eq sequence
end

def parse(source : String) : Array(LC::Node)
  tokens = LC::Lexer.run source
  LC::Parser.parse tokens
end

def assert_node(cls : LC::Node.class, for input : String) : Nil
  parse(input).map(&.class).should eq [cls]
end

def assert_node_sequence(sequence : Array(LC::Node.class), for input : String) : Nil
  nodes = parse input

  sequence.each_with_index do |cls, index|
    nodes[index].class.should eq cls
  end
end
