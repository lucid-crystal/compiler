require "./spec_helper"

describe Lucid::Compiler::Lexer do
  it "parses string expressions" do
    assert_token :string, %("hello world")
  end

  it "parses number-integer expressions" do
    assert_token :number, "123_45"
  end

  it "parses number-float expressions" do
    assert_token :number, "3.141_592"
  end

  it "parses nil expressions" do
    assert_token :nil, "nil"
  end

  it "parses the equal sign" do
    assert_token_sequence(
      seq!(:ident, :space, :equal, :space, :number),
      "x = 7"
    )
  end

  it "parses an ident that contains a keyword" do
    assert_token_sequence(
      seq!(:ident, :space, :equal, :space, :number, :newline,
        :ident, :space, :equal, :space, :number, :newline,
        :ident, :space, :equal, :space, :number), <<-CR)
    nil_a = 2
    end_me = 2
    module_is_cool = 2
    CR
  end

  it "parses normal expressions" do
    assert_token_sequence(seq!(:ident, :space, :string), %(puts "hello world"))
  end

  it "parses def expressions" do
    assert_token_sequence(seq!(:def, :space, :ident, :newline, :end), <<-CR)
      def foo
      end
      CR
  end

  it "parses def expressions with types" do
    assert_token_sequence(
      seq!(:def, :space, :ident, :space, :colon,
        :space, :ident, :newline, :end), <<-CR)
      def foo : Nil
      end
      CR
  end

  it "parses def expressions with types and values" do
    assert_token_sequence(
      seq!(:def, :space, :ident, :space, :colon, :space, :ident,
        :newline, :space, :number, :newline, :end), <<-CR)
      def foo : Int32
        123
      end
      CR
  end

  it "parses module expressions" do
    assert_token_sequence(
      seq!(:module, :space, :ident, :newline, :end), <<-CR)
      module Yay
      end
      CR
  end
end
