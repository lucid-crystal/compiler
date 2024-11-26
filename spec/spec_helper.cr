require "spec"
require "../src/compiler"

alias LC = Lucid::Compiler

def parse(source : String, file : String = "STDIN", dir : String = "") : LC::Node
  tokens = LC::Lexer.run source, filename: file, dirname: dir
  LC::Parser.parse(tokens)[0]
end

def assert_node(cls : LC::Node.class, for input : String) : Nil
  parse(input).class.should eq cls
end

def assert_tokens(source : String, *kinds : LC::Token::Kind) : Nil
  LC::Lexer.run(source).map(&.kind).should eq kinds.to_a
end
