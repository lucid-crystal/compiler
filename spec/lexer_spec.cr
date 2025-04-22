require "./spec_helper"

describe LC::Lexer, tags: "lexer" do
  it "formats tokens" do
    tokens = LC::Lexer.run ""
    tokens.size.should eq 1

    token = tokens[0]
    token.kind.should eq LC::Token::Kind::EOF
    token.raw_value.should be_nil

    token.loc.start.should eq({0, 0})
    token.loc.end.should eq({0, 0})

    token.inspect.should eq "Token(kind: Lucid::Compiler::Token::Kind::EOF, loc: 0:0-0:0)"
  end

  it "parses string expressions" do
    assert_tokens %("hello world"), {t!(string), 0, 0, 0, 13}, {t!(eof), 0, 13, 0, 13}
  end

  it "parses integer expressions" do
    assert_tokens "123", {t!(integer), 0, 0, 0, 3}, {t!(eof), 0, 3, 0, 3}
    assert_tokens "123_45", {t!(integer), 0, 0, 0, 6}, {t!(eof), 0, 6, 0, 6}
    assert_tokens "123_i64", {t!(integer), 0, 0, 0, 7}, {t!(eof), 0, 7, 0, 7}
  end

  it "parses invalid integer expressions" do
    assert_tokens "123i88", {t!(integer_bad_suffix), 0, 0, 0, 6}, {t!(eof), 0, 6, 0, 6}
    assert_tokens "123i162", {t!(integer_bad_suffix), 0, 0, 0, 7}, {t!(eof), 0, 7, 0, 7}
    assert_tokens "123i345", {t!(integer_bad_suffix), 0, 0, 0, 7}, {t!(eof), 0, 7, 0, 7}
    assert_tokens "123u654", {t!(integer_bad_suffix), 0, 0, 0, 7}, {t!(eof), 0, 7, 0, 7}
    assert_tokens "123u123", {t!(integer_bad_suffix), 0, 0, 0, 7}, {t!(eof), 0, 7, 0, 7}
  end

  it "parses float expressions" do
    assert_tokens "3.141_592", {t!(float), 0, 0, 0, 9}, {t!(eof), 0, 9, 0, 9}
    assert_tokens "2.468f64", {t!(float), 0, 0, 0, 8}, {t!(eof), 0, 8, 0, 8}
    assert_tokens "468f32", {t!(float), 0, 0, 0, 6}, {t!(eof), 0, 6, 0, 6}
  end

  it "parses invalid float expressions" do
    assert_tokens "2.46f8", {t!(float_bad_suffix), 0, 0, 0, 6}, {t!(eof), 0, 6, 0, 6}
    assert_tokens "1.2f34", {t!(float_bad_suffix), 0, 0, 0, 6}, {t!(eof), 0, 6, 0, 6}
    assert_tokens "23.45f67", {t!(float_bad_suffix), 0, 0, 0, 8}, {t!(eof), 0, 8, 0, 8}
  end

  it "parses boolean expressions" do
    assert_tokens "true", {t!(true), 0, 0, 0, 4}, {t!(eof), 0, 4, 0, 4}
    assert_tokens "false", {t!(false), 0, 0, 0, 5}, {t!(eof), 0, 5, 0, 5}
  end

  it "parses char literals" do
    assert_tokens "'0'", {t!(char), 0, 0, 0, 3}, {t!(eof), 0, 3, 0, 3}
    assert_tokens "'A'", {t!(char), 0, 0, 0, 3}, {t!(eof), 0, 3, 0, 3}
    assert_tokens "'é'", {t!(char), 0, 0, 0, 3}, {t!(eof), 0, 3, 0, 3}
    assert_tokens "'§'", {t!(char), 0, 0, 0, 3}, {t!(eof), 0, 3, 0, 3}
    assert_tokens "'°'", {t!(char), 0, 0, 0, 3}, {t!(eof), 0, 3, 0, 3}
    assert_tokens "'α'", {t!(char), 0, 0, 0, 3}, {t!(eof), 0, 3, 0, 3}

    # TODO: lex this and raise in the parser
    expect_raises(Exception, "unterminated char literal") do
      assert_tokens "'e", :char, :eof
    end

    # and this...
    expect_raises(Exception, "invalid char literal (did you mean '\\''?)") do
      assert_tokens "''", :char, :eof
    end
  end

  it "parses char escape" do
    assert_tokens "'\\''", {t!(char), 0, 0, 0, 4}, {t!(eof), 0, 4, 0, 4}
    assert_tokens "'\\\\'", {t!(char), 0, 0, 0, 4}, {t!(eof), 0, 4, 0, 4}
    assert_tokens "'\\e'", {t!(char), 0, 0, 0, 4}, {t!(eof), 0, 4, 0, 4}
    assert_tokens "'\\f'", {t!(char), 0, 0, 0, 4}, {t!(eof), 0, 4, 0, 4}
    assert_tokens "'\\n'", {t!(char), 0, 0, 0, 4}, {t!(eof), 0, 4, 0, 4}
    assert_tokens "'\\r'", {t!(char), 0, 0, 0, 4}, {t!(eof), 0, 4, 0, 4}
    assert_tokens "'\\t'", {t!(char), 0, 0, 0, 4}, {t!(eof), 0, 4, 0, 4}
    assert_tokens "'\\v'", {t!(char), 0, 0, 0, 4}, {t!(eof), 0, 4, 0, 4}
  end

  it "parses hex in char" do
    assert_tokens "'\\u{F}'", {t!(char), 0, 0, 0, 7}, {t!(eof), 0, 7, 0, 7}
    assert_tokens "'\\uFFFF'", {t!(char), 0, 0, 0, 8}, {t!(eof), 0, 8, 0, 8}
    assert_tokens "'\\u{FFFFF}'", {t!(char), 0, 0, 0, 11}, {t!(eof), 0, 11, 0, 11}
  end

  # TODO: same as previous
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

  it "parses symbol literals" do
    assert_tokens ":foo", {t!(symbol), 0, 0, 0, 4}, {t!(eof), 0, 4, 0, 4}
    assert_tokens ":foo?", {t!(symbol), 0, 0, 0, 5}, {t!(eof), 0, 5, 0, 5}
    assert_tokens ":foo!", {t!(symbol), 0, 0, 0, 5}, {t!(eof), 0, 5, 0, 5}
    assert_tokens %(:"foo bar"), {t!(quoted_symbol), 0, 0, 0, 10}, {t!(eof), 0, 10, 0, 10}
    assert_tokens ":!", {t!(symbol), 0, 0, 0, 2}, {t!(eof), 0, 2, 0, 2}
    assert_tokens ":===", {t!(symbol), 0, 0, 0, 4}, {t!(eof), 0, 4, 0, 4}
  end

  it "parses symbol keys" do
    assert_tokens "foo:", {t!(symbol_key), 0, 0, 0, 4}, {t!(eof), 0, 4, 0, 4}
    assert_tokens %("foo bar":), {t!(symbol_key), 0, 0, 0, 10}, {t!(eof), 0, 10, 0, 10}
  end

  it "parses nil expressions" do
    assert_tokens "nil", {t!(nil), 0, 0, 0, 3}, {t!(eof), 0, 3, 0, 3}
  end

  it "parses self expressions" do
    assert_tokens "self", {t!(self), 0, 0, 0, 4}, {t!(eof), 0, 4, 0, 4}
  end

  it "parses file magic expressions" do
    assert_tokens "__FILE__", {t!(magic_file), 0, 0, 0, 8}, {t!(eof), 0, 8, 0, 8}
  end

  it "parses line magic expressions" do
    assert_tokens "__LINE__", {t!(magic_line), 0, 0, 0, 8}, {t!(eof), 0, 8, 0, 8}
  end

  it "parses the assignment operator" do
    assert_tokens "x = 7",
      {t!(ident), 0, 0, 0, 1},
      {t!(space), 0, 1, 0, 2},
      {t!(assign), 0, 2, 0, 3},
      {t!(space), 0, 3, 0, 4},
      {t!(integer), 0, 4, 0, 5},
      {t!(eof), 0, 5, 0, 5}
  end

  it "parses compound operators" do
    assert_tokens "a //= 2 ** 16",
      {t!(ident), 0, 0, 0, 1},
      {t!(space), 0, 1, 0, 2},
      {t!(double_slash_assign), 0, 2, 0, 5},
      {t!(space), 0, 5, 0, 6},
      {t!(integer), 0, 6, 0, 7},
      {t!(space), 0, 7, 0, 8},
      {t!(double_star), 0, 8, 0, 10},
      {t!(space), 0, 10, 0, 11},
      {t!(integer), 0, 11, 0, 13},
      {t!(eof), 0, 13, 0, 13}

    assert_tokens "x === y",
      {t!(ident), 0, 0, 0, 1},
      {t!(space), 0, 1, 0, 2},
      {t!(case_equal), 0, 2, 0, 5},
      {t!(space), 0, 5, 0, 6},
      {t!(ident), 0, 6, 0, 7},
      {t!(eof), 0, 7, 0, 7}
  end

  it "parses complex operators" do
    assert_tokens ".|..||...<=>^===`=~!~=>;->{}&&",
      {t!(period), 0, 0, 0, 1},
      {t!(bit_or), 0, 1, 0, 2},
      {t!(double_period), 0, 2, 0, 4},
      {t!(or), 0, 4, 0, 6},
      {t!(triple_period), 0, 6, 0, 9},
      {t!(comparison), 0, 9, 0, 12},
      {t!(caret), 0, 12, 0, 13},
      {t!(case_equal), 0, 13, 0, 16},
      {t!(backtick), 0, 16, 0, 17},
      {t!(pattern_match), 0, 17, 0, 19},
      {t!(pattern_unmatch), 0, 19, 0, 21},
      {t!(rocket), 0, 21, 0, 23},
      {t!(semicolon), 0, 23, 0, 24},
      {t!(proc), 0, 24, 0, 26},
      {t!(left_brace), 0, 26, 0, 27},
      {t!(right_brace), 0, 27, 0, 28},
      {t!(and), 0, 28, 0, 30}
    {t!(eof), 0, 30, 0, 30}

    assert_tokens "%=//=<<=>>=**=&+=&-==",
      {t!(modulo_assign), 0, 0, 0, 2},
      {t!(double_slash_assign), 0, 2, 0, 5},
      {t!(shift_left_assign), 0, 5, 0, 8},
      {t!(shift_right_assign), 0, 8, 0, 11},
      {t!(double_star_assign), 0, 11, 0, 14},
      {t!(binary_plus_assign), 0, 14, 0, 17},
      {t!(binary_minus_assign), 0, 17, 0, 20},
      {t!(assign), 0, 20, 0, 21},
      {t!(eof), 0, 21, 0, 21}
  end

  it "parses identifiers" do
    assert_tokens "foo", {t!(ident), 0, 0, 0, 3}, {t!(eof), 0, 3, 0, 3}
    assert_tokens "foo=", {t!(ident), 0, 0, 0, 4}, {t!(eof), 0, 4, 0, 4}
    assert_tokens "foo!", {t!(ident), 0, 0, 0, 4}, {t!(eof), 0, 4, 0, 4}
    assert_tokens "foo!!", {t!(ident), 0, 0, 0, 4}, {t!(bang), 0, 4, 0, 5}, {t!(eof), 0, 5, 0, 5}
    assert_tokens "foo!=", {t!(ident), 0, 0, 0, 3}, {t!(not_equal), 0, 3, 0, 5}, {t!(eof), 0, 5, 0, 5}
    assert_tokens "foo?", {t!(ident), 0, 0, 0, 4}, {t!(eof), 0, 4, 0, 4}
    assert_tokens "foo??", {t!(ident), 0, 0, 0, 4}, {t!(question), 0, 4, 0, 5}, {t!(eof), 0, 5, 0, 5}
    assert_tokens "foo?!", {t!(ident), 0, 0, 0, 4}, {t!(bang), 0, 4, 0, 5}, {t!(eof), 0, 5, 0, 5}
  end

  it "parses comments" do
    assert_tokens <<-CR,
        # This is a comment
        an_ident # This is an ident
        CR
      {t!(comment), 0, 0, 0, 19},
      {t!(newline), 0, 19, 0, 20},
      {t!(ident), 1, 0, 1, 8},
      {t!(space), 1, 8, 1, 9},
      {t!(comment), 1, 9, 1, 27},
      {t!(eof), 1, 27, 1, 27}
  end

  it "parses idents and constants separately" do
    assert_tokens "int32 Int32",
      {t!(ident), 0, 0, 0, 5},
      {t!(space), 0, 5, 0, 6},
      {t!(const), 0, 6, 0, 11},
      {t!(eof), 0, 11, 0, 11}
  end

  it "parses underscores and idents separately" do
    assert_tokens "_", {t!(underscore), 0, 0, 0, 1}, {t!(eof), 0, 1, 0, 1}
    assert_tokens "__", {t!(ident), 0, 0, 0, 2}, {t!(eof), 0, 2, 0, 2}
    assert_tokens "_0", {t!(ident), 0, 0, 0, 2}, {t!(eof), 0, 2, 0, 2}
    assert_tokens "_x", {t!(ident), 0, 0, 0, 2}, {t!(eof), 0, 2, 0, 2}
  end

  it "parses ident that starts with en" do
    assert_tokens "encryption = 1",
      {t!(ident), 0, 0, 0, 10},
      {t!(space), 0, 10, 0, 11},
      {t!(assign), 0, 11, 0, 12},
      {t!(space), 0, 12, 0, 13},
      {t!(integer), 0, 13, 0, 14},
      {t!(eof), 0, 14, 0, 14}
  end

  # TODO: add responds_to? spec when symbols are implemented
  it "parses pseudo methods" do
    assert_tokens "a.is_a?(String)",
      {t!(ident), 0, 0, 0, 1},
      {t!(period), 0, 1, 0, 2},
      {t!(is_a), 0, 2, 0, 7},
      {t!(left_paren), 0, 7, 0, 8},
      {t!(const), 0, 8, 0, 14},
      {t!(right_paren), 0, 14, 0, 15},
      {t!(eof), 0, 15, 0, 15}
  end

  it "parses an ident that contains a keyword" do
    assert_tokens <<-CR,
        nil_a = 2
        end_me = 2
        module_is_cool = 2
        CR
      {t!(ident), 0, 0, 0, 5},
      {t!(space), 0, 5, 0, 6},
      {t!(assign), 0, 6, 0, 7},
      {t!(space), 0, 7, 0, 8},
      {t!(integer), 0, 8, 0, 9},
      {t!(newline), 0, 9, 0, 10},
      {t!(ident), 1, 0, 1, 6},
      {t!(space), 1, 6, 1, 7},
      {t!(assign), 1, 7, 1, 8},
      {t!(space), 1, 8, 1, 9},
      {t!(integer), 1, 9, 1, 10},
      {t!(newline), 1, 10, 1, 11},
      {t!(ident), 2, 0, 2, 14},
      {t!(space), 2, 14, 2, 15},
      {t!(assign), 2, 15, 2, 16},
      {t!(space), 2, 16, 2, 17},
      {t!(integer), 2, 17, 2, 18},
      {t!(eof), 2, 18, 2, 18}
  end

  it "parses normal expressions" do
    assert_tokens %(puts "hello world"),
      {t!(ident), 0, 0, 0, 4},
      {t!(space), 0, 4, 0, 5},
      {t!(string), 0, 5, 0, 18},
      {t!(eof), 0, 18, 0, 18}
  end

  it "parses def expressions" do
    assert_tokens <<-CR,
        def foo
        end
        CR
      {t!(:def), 0, 0, 0, 3},
      {t!(space), 0, 3, 0, 4},
      {t!(ident), 0, 4, 0, 7},
      {t!(newline), 0, 7, 0, 8},
      {t!(end), 1, 0, 1, 3},
      {t!(eof), 1, 3, 1, 3}
  end

  it "parses def expressions with types" do
    assert_tokens <<-CR,
        def foo : Nil
        end
        CR
      {t!(:def), 0, 0, 0, 3},
      {t!(space), 0, 3, 0, 4},
      {t!(ident), 0, 4, 0, 7},
      {t!(space), 0, 7, 0, 8},
      {t!(colon), 0, 8, 0, 9},
      {t!(space), 0, 9, 0, 10},
      {t!(const), 0, 10, 0, 13},
      {t!(newline), 0, 13, 0, 14},
      {t!(end), 1, 0, 1, 3},
      {t!(eof), 1, 3, 1, 3}
  end

  it "parses def expressions with types and values" do
    assert_tokens <<-CR,
        def foo : Int32
          123
        end
        CR
      {t!(:def), 0, 0, 0, 3},
      {t!(space), 0, 3, 0, 4},
      {t!(ident), 0, 4, 0, 7},
      {t!(space), 0, 7, 0, 8},
      {t!(colon), 0, 8, 0, 9},
      {t!(space), 0, 9, 0, 10},
      {t!(const), 0, 10, 0, 15},
      {t!(newline), 0, 15, 0, 16},
      {t!(space), 1, 0, 1, 2},
      {t!(integer), 1, 2, 1, 5},
      {t!(newline), 1, 5, 1, 6},
      {t!(end), 2, 0, 2, 3},
      {t!(eof), 2, 3, 2, 3}
  end

  it "parses def expressions with generics" do
    assert_tokens <<-CR,
        def puts(obj : T) : Nil forall T
        end
        CR
      {t!(:def), 0, 0, 0, 3},
      {t!(space), 0, 3, 0, 4},
      {t!(ident), 0, 4, 0, 8},
      {t!(left_paren), 0, 8, 0, 9},
      {t!(ident), 0, 9, 0, 12},
      {t!(space), 0, 12, 0, 13},
      {t!(colon), 0, 13, 0, 14},
      {t!(space), 0, 14, 0, 15},
      {t!(const), 0, 15, 0, 16},
      {t!(right_paren), 0, 16, 0, 17},
      {t!(space), 0, 17, 0, 18},
      {t!(colon), 0, 18, 0, 19},
      {t!(space), 0, 19, 0, 20},
      {t!(const), 0, 20, 0, 23},
      {t!(space), 0, 23, 0, 24},
      {t!(forall), 0, 24, 0, 30},
      {t!(space), 0, 30, 0, 31},
      {t!(const), 0, 31, 0, 32},
      {t!(newline), 0, 32, 0, 33},
      {t!(end), 1, 0, 1, 3},
      {t!(eof), 1, 3, 1, 3}
  end

  it "parses def expressions with visibility modifiers" do
    assert_tokens "abstract def foo",
      {t!(:abstract), 0, 0, 0, 8},
      {t!(space), 0, 8, 0, 9},
      {t!(:def), 0, 9, 0, 12},
      {t!(space), 0, 12, 0, 13},
      {t!(ident), 0, 13, 0, 16},
      {t!(eof), 0, 16, 0, 16}

    assert_tokens "private def foo; end",
      {t!(:private), 0, 0, 0, 7},
      {t!(space), 0, 7, 0, 8},
      {t!(:def), 0, 8, 0, 11},
      {t!(space), 0, 11, 0, 12},
      {t!(ident), 0, 12, 0, 15},
      {t!(semicolon), 0, 15, 0, 16},
      {t!(space), 0, 16, 0, 17},
      {t!(end), 0, 17, 0, 20},
      {t!(eof), 0, 20, 0, 20}

    assert_tokens "protected def foo; end",
      {t!(:protected), 0, 0, 0, 9},
      {t!(space), 0, 9, 0, 10},
      {t!(:def), 0, 10, 0, 13},
      {t!(space), 0, 13, 0, 14},
      {t!(ident), 0, 14, 0, 17},
      {t!(semicolon), 0, 17, 0, 18},
      {t!(space), 0, 18, 0, 19},
      {t!(end), 0, 19, 0, 22},
      {t!(eof), 0, 22, 0, 22}
  end

  it "parses module expressions" do
    assert_tokens <<-CR,
        module Yay
        end
        CR
      {t!(:module), 0, 0, 0, 6},
      {t!(space), 0, 6, 0, 7},
      {t!(const), 0, 7, 0, 10},
      {t!(newline), 0, 10, 0, 11},
      {t!(end), 1, 0, 1, 3},
      {t!(eof), 1, 3, 1, 3}
  end

  it "parses class expressions" do
    assert_tokens <<-CR,
        class Klass
        end
        CR
      {t!(:class), 0, 0, 0, 5},
      {t!(space), 0, 5, 0, 6},
      {t!(const), 0, 6, 0, 11},
      {t!(newline), 0, 11, 0, 12},
      {t!(end), 1, 0, 1, 3},
      {t!(eof), 1, 3, 1, 3}
  end

  it "parses struct expressions" do
    assert_tokens <<-CR,
        struct Strukt
        end
        CR
      {t!(:struct), 0, 0, 0, 6},
      {t!(space), 0, 6, 0, 7},
      {t!(const), 0, 7, 0, 13},
      {t!(newline), 0, 13, 0, 14},
      {t!(end), 1, 0, 1, 3},
      {t!(eof), 1, 3, 1, 3}
  end

  it "parses include/extend expressions" do
    assert_tokens <<-CR,
        include Base
        extend self
        CR
      {t!(:include), 0, 0, 0, 7},
      {t!(space), 0, 7, 0, 8},
      {t!(const), 0, 8, 0, 12},
      {t!(newline), 0, 12, 0, 13},
      {t!(:extend), 1, 0, 1, 6},
      {t!(space), 1, 6, 1, 7},
      {t!(self), 1, 7, 1, 11},
      {t!(eof), 1, 11, 1, 11}
  end

  it "parses enum expressions" do
    assert_tokens <<-CR,
        enum Enumn
        end
        CR
      {t!(:enum), 0, 0, 0, 4},
      {t!(space), 0, 4, 0, 5},
      {t!(const), 0, 5, 0, 10},
      {t!(newline), 0, 10, 0, 11},
      {t!(end), 1, 0, 1, 3},
      {t!(eof), 1, 3, 1, 3}
  end

  it "parses annotation expressions" do
    assert_tokens "annotation Def; end",
      {t!(:annotation), 0, 0, 0, 10},
      {t!(space), 0, 10, 0, 11},
      {t!(const), 0, 11, 0, 14},
      {t!(semicolon), 0, 14, 0, 15},
      {t!(space), 0, 15, 0, 16},
      {t!(end), 0, 16, 0, 19},
      {t!(eof), 0, 19, 0, 19}

    assert_tokens "@[Def]",
      {t!(annotation_open), 0, 0, 0, 2},
      {t!(const), 0, 2, 0, 5},
      {t!(right_bracket), 0, 5, 0, 6},
      {t!(eof), 0, 6, 0, 6}
  end

  it "parses require expressions" do
    assert_tokens %q(require "json"),
      {t!(:require), 0, 0, 0, 7},
      {t!(space), 0, 7, 0, 8},
      {t!(string), 0, 8, 0, 14},
      {t!(eof), 0, 14, 0, 14}
  end

  it "parses size keywords" do
    assert_tokens "sizeof instance_alignof offsetof pointerof instance_sizeof alignof",
      {t!(:sizeof), 0, 0, 0, 6},
      {t!(space), 0, 6, 0, 7},
      {t!(:instance_alignof), 0, 7, 0, 23},
      {t!(space), 0, 23, 0, 24},
      {t!(:offsetof), 0, 24, 0, 32},
      {t!(space), 0, 32, 0, 33},
      {t!(:pointerof), 0, 33, 0, 42},
      {t!(space), 0, 42, 0, 43},
      {t!(:instance_sizeof), 0, 43, 0, 58},
      {t!(space), 0, 58, 0, 59},
      {t!(:alignof), 0, 59, 0, 66},
      {t!(eof), 0, 66, 0, 66}
  end
end
