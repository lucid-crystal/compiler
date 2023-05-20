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
end
