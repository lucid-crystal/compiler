require "spec"
require "../src/compiler"

alias LC = Lucid::Compiler

def parse_expr(source : String, file : String = "STDIN", dir : String = "") : LC::Expression
  tokens = LC::Lexer.run source, filename: file, dirname: dir
  nodes = LC::Parser.parse tokens

  nodes.size.should eq 1
  nodes[0].should be_a LC::ExpressionStatement

  nodes[0].as(LC::ExpressionStatement).value
end

def parse_stmt(source : String) : LC::Statement
  tokens = LC::Lexer.run source
  nodes = LC::Parser.parse tokens

  nodes.size.should eq 1
  nodes[0]
end

def assert_node(cls : LC::Node.class, for input : String) : Nil
  parse_expr(input).class.should eq cls
end

def assert_node_sequence(sequence : Array(LC::Node.class), for input : String) : Nil
  tokens = LC::Lexer.run source
  nodes = LC::Parser.parse tokens

  sequence.each_with_index do |cls, index|
    nodes[index].class.should eq cls
  end
end

def assert_tokens(source : String, *kinds : LC::Token::Kind) : Nil
  LC::Lexer.run(source).map(&.kind).should eq kinds.to_a
end
