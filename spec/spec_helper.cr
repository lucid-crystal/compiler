require "spec"
require "../src/compiler"

macro seq!(*types)
  [{{ *types }}] of Compiler::Token::Type
end

def assert_token_sequence(sequence : Array(Compiler::Token::Type), for input : String) : Nil
  types = Compiler::Lexer.new(input).run.map &.type
  types.should eq sequence
end
