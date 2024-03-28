require "./spec_helper"

describe Lucid::Compiler::Parser do
  it "parses string expressions" do
    assert_node Lucid::Compiler::StringLiteral, %("hello world")
  end

  it "parses integer expressions" do
    assert_node Lucid::Compiler::IntLiteral, "123_45"
  end

  it "parses float expressions" do
    assert_node Lucid::Compiler::FloatLiteral, "3.141_592"
  end

  it "parses nil expressions" do
    assert_node Lucid::Compiler::NilLiteral, "nil"
  end

  it "parses assignment expressions" do
    node = parse("x = 7")[0]
    node.should be_a Lucid::Compiler::Assign
    node = node.as(Lucid::Compiler::Assign)

    node.target.should be_a Lucid::Compiler::Ident
    node.target.as(Lucid::Compiler::Ident).value.should eq "x"

    node.value.should be_a Lucid::Compiler::IntLiteral
    node.value.as(Lucid::Compiler::IntLiteral).value.should eq 7
  end

  it "parses variable declaration expresssions" do
    node = parse("x : Int32")[0]
    node.should be_a Lucid::Compiler::Var
    node = node.as(Lucid::Compiler::Var)

    node.name.should be_a Lucid::Compiler::Ident
    node.name.as(Lucid::Compiler::Ident).value.should eq "x"

    # FIXME: parsed as a Call and expected to be an Ident when really it's a Const
    # node.type.should be_a Lucid::Compiler::Ident
    # node.type.as(Lucid::Compiler::Ident).value.should eq "Int32"

    node.value.should be_nil
    node.uninitialized?.should be_true
  end

  it "parses call expressions with no arguments" do
    node = parse("exit")[0]
    node.should be_a Lucid::Compiler::Call
    node = node.as(Lucid::Compiler::Call)

    node.receiver.should be_a Lucid::Compiler::Ident
    node.receiver.as(Lucid::Compiler::Ident).value.should eq "exit"
    node.args.size.should eq 0
  end

  it "parses path call expressions" do
    node = parse("foo.bar.baz")[0]
    node.should be_a Lucid::Compiler::Call
    node = node.as(Lucid::Compiler::Call)

    node.receiver.should be_a Lucid::Compiler::Path
    names = node.receiver.as(Lucid::Compiler::Path).names

    names.size.should eq 3
    names[0].should be_a Lucid::Compiler::Ident
    names[0].as(Lucid::Compiler::Ident).value.should eq "foo"

    names[1].should be_a Lucid::Compiler::Ident
    names[1].as(Lucid::Compiler::Ident).value.should eq "bar"

    names[2].should be_a Lucid::Compiler::Ident
    names[2].as(Lucid::Compiler::Ident).value.should eq "baz"
  end

  it "parses call expressions with single arguments" do
    node = parse(%(puts "hello world"))[0]
    node.should be_a Lucid::Compiler::Call
    node = node.as(Lucid::Compiler::Call)

    node.receiver.should be_a Lucid::Compiler::Ident
    node.receiver.as(Lucid::Compiler::Ident).value.should eq "puts"

    node.args.size.should eq 1
    node.args[0].should be_a Lucid::Compiler::StringLiteral
    node.args[0].as(Lucid::Compiler::StringLiteral).value.should eq "hello world"
  end

  it "parses call expressions with multiple arguments" do
    node = parse(%(puts "foo", "bar", "baz"))[0]
    node.should be_a Lucid::Compiler::Call
    node = node.as(Lucid::Compiler::Call)

    node.receiver.should be_a Lucid::Compiler::Ident
    node.receiver.as(Lucid::Compiler::Ident).value.should eq "puts"

    node.args.size.should eq 3
    node.args[0].should be_a Lucid::Compiler::StringLiteral
    node.args[0].as(Lucid::Compiler::StringLiteral).value.should eq "foo"

    node.args[1].should be_a Lucid::Compiler::StringLiteral
    node.args[1].as(Lucid::Compiler::StringLiteral).value.should eq "bar"

    node.args[2].should be_a Lucid::Compiler::StringLiteral
    node.args[2].as(Lucid::Compiler::StringLiteral).value.should eq "baz"
  end

  it "parses call expressions on multiple lines" do
    node = parse(<<-CR)[0]
      puts(
        "hello from",
        "the other side",
      )
      CR

    node.should be_a Lucid::Compiler::Call
    node = node.as(Lucid::Compiler::Call)

    node.receiver.should be_a Lucid::Compiler::Ident
    node.receiver.as(Lucid::Compiler::Ident).value.should eq "puts"

    node.args.size.should eq 2
    node.args[0].should be_a Lucid::Compiler::StringLiteral
    node.args[0].as(Lucid::Compiler::StringLiteral).value.should eq "hello from"

    node.args[1].should be_a Lucid::Compiler::StringLiteral
    node.args[1].as(Lucid::Compiler::StringLiteral).value.should eq "the other side"
  end

  # TODO: use refined exceptions for these

  it "raises on undelimited arguments for calls" do
    expect_raises(Exception, "expected a comma after the last argument") do
      parse %(puts "foo" "bar")
    end
  end

  it "raises on unclosed parentheses for calls" do
    expect_raises(Exception, "expected closing parenthesis for call") do
      parse %[puts("foo", "bar"]
    end
  end
end
