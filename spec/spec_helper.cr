require "spec"
require "../src/compiler"

macro seq!(*kinds)
  [{{ *kinds }}] of Compiler::Token::Kind
end

def assert_token_sequence(sequence : Array(Compiler::Token::Kind), for input : String) : Nil
  kinds = Compiler::Lexer.new(input).run.map &.kind
  kinds.should eq sequence
end
