require "./spec_helper"

describe Compiler::Lexer do
  it "parses string expressions" do
    assert_token_sequence(seq!(:string, :eof), %("hello world"))
  end

  it "parses number-integer expressions" do
    assert_token_sequence(seq!(:number, :eof), %(123_45))
  end

  it "parses number-float expressions" do
    assert_token_sequence(seq!(:number, :eof), %(3.141_592))
  end

  it "parses nil expressions" do
    assert_token_sequence(seq!(:nil, :eof), "nil")
  end

  it "parses the equal sign" do
    assert_token_sequence(seq!(:ident, :space, :equal, :space, :number, :eof), "x = 7")
  end

  it "parses an ident that contains a keyword" do
    assert_token_sequence(
      seq!(:ident, :space, :equal, :space, :number, :newline, 
           :ident, :space, :equal, :space, :number, :newline,
           :ident, :space, :equal, :space, :number, :eof), <<-CR)
    nil_a = 2
    end_me = 2
    cool_module = 2
    CR
  end

  it "parses normal expressions" do
    assert_token_sequence(seq!(:ident, :space, :string, :eof), %(puts "hello world"))
  end

  it "parses def expressions" do
    assert_token_sequence(seq!(:def, :space, :ident, :newline, :end, :eof), <<-CR)
      def foo
      end
      CR
  end

  it "parses def expressions with types" do
    assert_token_sequence(
      seq!(:def, :space, :ident, :space, :colon,
        :space, :ident, :newline, :end, :eof), <<-CR)
      def foo : Nil
      end
      CR
  end

  it "parses def expressions with types and values" do
    assert_token_sequence(
      seq!(:def, :space, :ident, :space, :colon, :space,
        :ident, :newline, :space, :number, :newline, :end,
        :eof), <<-CR)
      def foo : Int32
        123
      end
      CR
  end

  it "parses module expressions" do
    assert_token_sequence(
      seq!(:module, :space, :ident, :newline, :end, :eof), <<-CR)
      module Yay
      end
      CR
  end
end
