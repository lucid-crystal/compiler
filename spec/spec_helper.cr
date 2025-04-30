require "spec"
require "../src/compiler"

alias LC = Lucid::Compiler

def parse(source : String, file : String = "STDIN", dir : String = "") : LC::Node
  tokens = LC::Lexer.run source, filename: file, dirname: dir
  LC::Parser.parse(tokens).nodes[0]
end

def assert_node(cls : LC::Node.class, for input : String) : Nil
  parse(input).class.should eq cls
end

# TODO: remove this
def assert_tokens(source : String, *kinds : LC::Token::Kind) : Nil
  LC::Lexer.run(source).map(&.kind).should eq kinds.to_a
end

def assert_tokens(source : String, *pairs : {LC::Token::Kind, Int32, Int32, Int32, Int32}) : Nil
  tokens = LC::Lexer.run source
  pairs.each_with_index do |(kind, *loc), index|
    token = tokens[index]
    token.kind.should eq kind
    token.loc.to_tuple.should eq loc
  end
end

macro t!(s)
  {%
    if s.stringify == "eof"
      id = s.id.upcase.id
    else
      id = s.id.camelcase.id
    end
  %}
  ::Lucid::Compiler::Token::Kind::{{id}}
end
