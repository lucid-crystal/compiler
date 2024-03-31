require "./spec_helper"

describe LC::Lexer do
  it "parses string expressions" do
    assert_token :string, %("hello world")
  end

  it "parses integer expressions" do
    assert_token :integer, "123_45"
  end

  it "parses float expressions" do
    assert_token :float, "3.141_592"
  end

  it "parses boolean expressions" do
    assert_token :true, "true"
    assert_token :false, "false"
  end

  it "parses nil expressions" do
    assert_token :nil, "nil"
  end

  it "parses the assignment operator" do
    assert_token_sequence(
      seq!(:ident, :space, :assign, :space, :integer),
      "x = 7"
    )
  end

  it "parses compound operators" do
    assert_token_sequence(
      seq!(:ident, :space, :double_slash_assign, :space, :integer,
        :space, :double_star, :space, :integer),
      "a //= 2 ** 16"
    )

    assert_token_sequence(
      seq!(:ident, :space, :case_equal, :space, :ident),
      "x === y"
    )
  end

  it "parses comments" do
    assert_token_sequence(
      seq!(:comment, :newline, :ident, :space, :comment), <<-CR)
      # This is a comment
      an_ident # This is an ident
      CR
  end

  it "parses idents and constants separately" do
    assert_token_sequence(seq!(:ident, :space, :const), "int32 Int32")
  end

  it "parses ident that starts with en" do
    assert_token_sequence(seq!(:ident, :space, :assign, :space, :integer), "encryption = 1")
  end

  # TODO: add responds_to? spec when symbols are implemented
  it "parses pseudo methods" do
    assert_token_sequence(
      seq!(:ident, :period, :is_a, :left_paren, :const, :right_paren), <<-CR)
      a.is_a?(String)
      CR
  end

  it "parses an ident that contains a keyword" do
    assert_token_sequence(
      seq!(:ident, :space, :assign, :space, :integer, :newline,
        :ident, :space, :assign, :space, :integer, :newline,
        :ident, :space, :assign, :space, :integer), <<-CR)
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
        :space, :const, :newline, :end), <<-CR)
      def foo : Nil
      end
      CR
  end

  it "parses def expressions with types and values" do
    assert_token_sequence(
      seq!(:def, :space, :ident, :space, :colon, :space, :const,
        :newline, :space, :integer, :newline, :end), <<-CR)
      def foo : Int32
        123
      end
      CR
  end

  it "parses module expressions" do
    assert_token_sequence(
      seq!(:module, :space, :const, :newline, :end), <<-CR)
      module Yay
      end
      CR
  end

  it "parses class expressions" do
    assert_token_sequence(
      seq!(:class, :space, :const, :newline, :end), <<-CR)
      class Kot
      end
      CR
  end

  it "parses class expressions" do
    assert_token_sequence(
      seq!(:class, :space, :const, :newline, :end), <<-CR)
      class Kot
      end
      CR
  end

  it "parses class expressions" do
    assert_token_sequence(
      seq!(:class, :space, :const, :newline, :end), <<-CR)
      class Klass
      end
      CR
  end

  it "parses struct expressions" do
    assert_token_sequence(
      seq!(:struct, :space, :const, :newline, :end), <<-CR)
      struct Strukt
      end
      CR
  end

  it "parses enum expressions" do
    assert_token_sequence(
      seq!(:enum, :space, :const, :newline, :end), <<-CR)
      enum Enumn
      end
      CR
  end
end
