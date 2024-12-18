require "./spec_helper"

describe LC::Lexer, tags: "lexer" do
  it "formats tokens" do
    tokens = LC::Lexer.run ""
    tokens.size.should eq 1

    token = tokens[0]
    token.kind.should eq LC::Token::Kind::EOF
    token.raw_value.should be_nil
    token.inspect.should eq "Token(kind: Lucid::Compiler::Token::Kind::EOF, loc: 0:0-0:0)"
  end

  it "parses string expressions" do
    assert_tokens %("hello world"), :string, :eof
  end

  it "parses integer expressions" do
    assert_tokens "123", :integer, :eof
    assert_tokens "123_45", :integer, :eof
    assert_tokens "123_i64", :integer, :eof
  end

  it "parses invalid integer expressions" do
    assert_tokens "123i88", :integer_bad_suffix, :eof
    assert_tokens "123i162", :integer_bad_suffix, :eof
    assert_tokens "123i345", :integer_bad_suffix, :eof
    assert_tokens "123u654", :integer_bad_suffix, :eof
    assert_tokens "123u123", :integer_bad_suffix, :eof
  end

  it "parses float expressions" do
    assert_tokens "3.141_592", :float, :eof
    assert_tokens "2.468f64", :float, :eof
    assert_tokens "468f32", :float, :eof
  end

  it "parses invalid float expressions" do
    assert_tokens "2.46f8", :float_bad_suffix, :eof
    assert_tokens "1.2f34", :float_bad_suffix, :eof
    assert_tokens "23.45f67", :float_bad_suffix, :eof
  end

  it "parses boolean expressions" do
    assert_tokens "true", :true, :eof
    assert_tokens "false", :false, :eof
  end

  it "parses char literals" do
    assert_tokens "'0'", :char, :eof
    assert_tokens "'A'", :char, :eof
    assert_tokens "'é'", :char, :eof
    assert_tokens "'§'", :char, :eof
    assert_tokens "'°'", :char, :eof
    assert_tokens "'α'", :char, :eof

    expect_raises(Exception, "unterminated char literal") do
      assert_tokens "'e", :char, :eof
    end

    expect_raises(Exception, "invalid char literal (did you mean '\\''?)") do
      assert_tokens "''", :char, :eof
    end
  end

  it "parses char escape" do
    assert_tokens "'\\''", :char, :eof
    assert_tokens "'\\\\'", :char, :eof
    assert_tokens "'\\e'", :char, :eof
    assert_tokens "'\\f'", :char, :eof
    assert_tokens "'\\n'", :char, :eof
    assert_tokens "'\\r'", :char, :eof
    assert_tokens "'\\t'", :char, :eof
    assert_tokens "'\\v'", :char, :eof
  end

  it "parses hex in char" do
    assert_tokens "'\\u{F}'", :char, :eof
    assert_tokens "'\\uFFFF'", :char, :eof
    assert_tokens "'\\u{FFFFF}'", :char, :eof
  end

  it "parses hex in char properly" do
    expect_raises(Exception, "expected hexadecimal character in unicode escape") do
      assert_tokens "'\\uFFF'", :char, :eof
    end

    expect_raises(Exception, "expected hexadecimal character in unicode escape") do
      assert_tokens "'\\uFFFZ'", :char, :eof
    end

    expect_raises(Exception, "expected hexadecimal character in unicode escape") do
      assert_tokens "'\\u{ZFFF}'", :char, :eof
    end

    expect_raises(Exception, "invalid unicode codepoint (too large)") do
      assert_tokens "'\\u{FFFFFFF}'", :char, :eof
    end
  end

  it "parses nil expressions" do
    assert_tokens "nil", :nil, :eof
  end

  it "parses self expressions" do
    assert_tokens "self", :self, :eof
  end

  it "parses file magic expressions" do
    assert_tokens "__FILE__", :magic_file, :eof
  end

  it "parses line magic expressions" do
    assert_tokens "__LINE__", :magic_line, :eof
  end

  it "parses the assignment operator" do
    assert_tokens "x = 7", :ident, :space, :assign, :Space, :integer, :eof
  end

  it "parses compound operators" do
    assert_tokens(
      "a //= 2 ** 16",
      :ident, :space, :double_slash_assign, :space, :integer,
      :space, :double_star, :space, :integer, :eof
    )

    assert_tokens(
      "x === y",
      :ident, :space, :case_equal, :space, :ident, :eof
    )
  end

  it "parses complex operators" do
    assert_tokens(
      ".|..||...<=>^===`=~!~=>;->{}&&",
      :period, :bit_or, :double_period, :or, :triple_period,
      :comparison, :caret, :case_equal, :backtick, :pattern_match,
      :pattern_unmatch, :rocket, :semicolon, :proc, :left_brace,
      :right_brace, :and, :eof
    )

    assert_tokens(
      "%=//=<<=>>=**=&+=&-==",
      :modulo_assign, :double_slash_assign, :shift_left_assign,
      :shift_right_assign, :double_star_assign, :binary_plus_assign,
      :binary_minus_assign, :assign, :eof
    )
  end

  it "parses identifiers" do
    assert_tokens "foo", :ident, :eof
    assert_tokens "foo=", :ident, :eof
    assert_tokens "foo!", :ident, :eof
    assert_tokens "foo!!", :ident, :bang, :eof
    assert_tokens "foo!=", :ident, :not_equal, :eof
    assert_tokens "foo?", :ident, :eof
    assert_tokens "foo??", :ident, :question, :eof
    assert_tokens "foo?!", :ident, :bang, :eof
  end

  it "parses comments" do
    assert_tokens(
      <<-CR,
        # This is a comment
        an_ident # This is an ident
        CR
      :comment, :newline, :ident, :space, :comment, :eof
    )
  end

  it "parses idents and constants separately" do
    assert_tokens "int32 Int32", :ident, :space, :const, :eof
  end

  it "parses underscores and idents separately" do
    assert_tokens "_", :underscore, :eof
    assert_tokens "__", :ident, :eof
    assert_tokens "_x", :ident, :eof
    assert_tokens "_0", :ident, :eof
  end

  it "parses ident that starts with en" do
    assert_tokens "encryption = 1", :ident, :space, :assign, :space, :integer, :eof
  end

  # TODO: add responds_to? spec when symbols are implemented
  it "parses pseudo methods" do
    assert_tokens(
      "a.is_a?(String)",
      :ident, :period, :is_a, :left_paren,
      :const, :right_paren, :eof
    )
  end

  it "parses an ident that contains a keyword" do
    assert_tokens(
      <<-CR,
        nil_a = 2
        end_me = 2
        module_is_cool = 2
        CR
      :ident, :space, :assign, :space, :integer, :newline,
      :ident, :space, :assign, :space, :integer, :newline,
      :ident, :space, :assign, :space, :integer, :eof
    )
  end

  it "parses normal expressions" do
    assert_tokens %(puts "hello world"), :ident, :space, :string, :eof
  end

  it "parses def expressions" do
    assert_tokens(
      <<-CR,
        def foo
        end
        CR
      :def, :space, :ident, :newline, :end, :eof
    )
  end

  it "parses def expressions with types" do
    assert_tokens(
      <<-CR,
        def foo : Nil
        end
        CR
      :def, :space, :ident, :space, :colon,
      :space, :const, :newline, :end, :eof
    )
  end

  it "parses def expressions with types and values" do
    assert_tokens(
      <<-CR,
        def foo : Int32
          123
        end
        CR
      :def, :space, :ident, :space, :colon, :space, :const,
      :newline, :space, :integer, :newline, :end, :eof
    )
  end

  it "parses def expressions with generics" do
    assert_tokens(
      <<-CR,
        def puts(obj : T) : Nil forall T
        end
        CR
      :def, :space, :ident, :left_paren, :ident, :space,
      :colon, :space, :const, :right_paren, :space, :colon,
      :space, :const, :space, :forall, :space, :const,
      :newline, :end, :eof
    )
  end

  it "parses def expressions with visibility modifiers" do
    assert_tokens("abstract def foo", :abstract, :space, :def, :space, :ident, :eof)
    assert_tokens(
      "private def foo; end",
      :private, :space, :def, :space, :ident, :semicolon, :space, :end, :eof
    )
    assert_tokens(
      "protected def foo; end",
      :protected, :space, :def, :space, :ident, :semicolon, :space, :end, :eof
    )
  end

  it "parses module expressions" do
    assert_tokens(
      <<-CR,
        module Yay
        end
        CR
      :module, :space, :const, :newline, :end, :eof
    )
  end

  it "parses class expressions" do
    assert_tokens(
      <<-CR,
        class Klass
        end
        CR
      :class, :space, :const, :newline, :end, :eof
    )
  end

  it "parses struct expressions" do
    assert_tokens(
      <<-CR,
        struct Strukt
        end
        CR
      :struct, :space, :const, :newline, :end, :eof
    )
  end

  it "parses enum expressions" do
    assert_tokens(
      <<-CR,
        enum Enumn
        end
        CR
      :enum, :space, :const, :newline, :end, :eof
    )
  end

  it "parses require expressions" do
    assert_tokens(
      %q(require "json"),
      :require, :space, :string, :eof
    )
  end
end
