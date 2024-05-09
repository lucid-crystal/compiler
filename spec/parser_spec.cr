require "./spec_helper"

describe LC::Parser do
  it "parses string expressions" do
    assert_node LC::StringLiteral, %("hello world")
  end

  it "parses integer expressions" do
    assert_node LC::IntLiteral, "123_45"
  end

  it "parses float expressions" do
    assert_node LC::FloatLiteral, "3.141_592"
  end

  it "parses boolean expressions" do
    assert_node LC::BoolLiteral, "true"
    assert_node LC::BoolLiteral, "false"
  end

  it "parses nil expressions" do
    assert_node LC::NilLiteral, "nil"
  end

  it "parses assignment expressions" do
    node = parse_expr "x = 7"
    node.should be_a LC::Assign
    node = node.as(LC::Assign)

    node.target.should be_a LC::Ident
    node.target.as(LC::Ident).value.should eq "x"

    node.value.should be_a LC::IntLiteral
    node.value.as(LC::IntLiteral).value.should eq 7
  end

  it "parses uninitialized variable declaration expressions" do
    node = parse_expr "x : Int32"
    node.should be_a LC::Var
    node = node.as(LC::Var)

    node.name.should be_a LC::Ident
    node.name.as(LC::Ident).value.should eq "x"
    node.uninitialized?.should be_true

    node.type.should be_a LC::Const
    node.type.as(LC::Const).value.should eq "Int32"

    node.value.should be_nil
  end

  it "parses initialized variable declaration expressions" do
    node = parse_expr "y : Int32 = 123"
    node.should be_a LC::Var
    node = node.as(LC::Var)

    node.name.should be_a LC::Ident
    node.name.as(LC::Ident).value.should eq "y"
    node.uninitialized?.should be_false

    node.type.should be_a LC::Const
    node.type.as(LC::Const).value.should eq "Int32"

    node.value.should be_a LC::IntLiteral
    node.value.as(LC::IntLiteral).value.should eq 123
  end

  it "parses call expressions with no arguments" do
    node = parse_expr "exit"
    node.should be_a LC::Call
    node = node.as(LC::Call)

    node.receiver.should be_a LC::Ident
    node.receiver.as(LC::Ident).value.should eq "exit"
    node.args.size.should eq 0
  end

  it "parses path call expressions" do
    node = parse_expr "foo.bar.baz"
    node.should be_a LC::Call
    node = node.as(LC::Call)

    node.receiver.should be_a LC::Path
    names = node.receiver.as(LC::Path).names

    names.size.should eq 3
    names[0].should be_a LC::Ident
    names[0].as(LC::Ident).value.should eq "foo"

    names[1].should be_a LC::Ident
    names[1].as(LC::Ident).value.should eq "bar"

    names[2].should be_a LC::Ident
    names[2].as(LC::Ident).value.should eq "baz"
  end

  it "parses constant path expressions" do
    node = parse_expr "Foo::Bar"
    node.should be_a LC::Path
    node = node.as(LC::Path)

    node.names.size.should eq 2
    node.names[0].should be_a LC::Const
    node.names[0].as(LC::Const).value.should eq "Foo"
    node.names[0].as(LC::Const).global?.should be_false

    node.names[1].should be_a LC::Const
    node.names[1].as(LC::Const).value.should eq "Bar"
    node.names[1].as(LC::Const).global?.should be_true
  end

  it "parses constant call expresions" do
    node = parse_expr "::Foo.baz"
    node.should be_a LC::Call
    node = node.as(LC::Call)

    node.receiver.should be_a LC::Path
    names = node.receiver.as(LC::Path).names

    names.size.should eq 2
    names[0].should be_a LC::Const
    names[0].as(LC::Const).value.should eq "Foo"
    names[0].as(LC::Const).global?.should be_true

    names[1].should be_a LC::Ident
    names[1].as(LC::Ident).value.should eq "baz"
    names[1].as(LC::Ident).global?.should be_false
  end

  it "parses call expressions with single arguments" do
    node = parse_expr %(puts "hello world")
    node.should be_a LC::Call
    node = node.as(LC::Call)

    node.receiver.should be_a LC::Ident
    node.receiver.as(LC::Ident).value.should eq "puts"

    node.args.size.should eq 1
    node.args[0].should be_a LC::StringLiteral
    node.args[0].as(LC::StringLiteral).value.should eq "hello world"
  end

  it "parses call expressions with multiple arguments" do
    node = parse_expr %(puts "foo", "bar", "baz")
    node.should be_a LC::Call
    node = node.as(LC::Call)

    node.receiver.should be_a LC::Ident
    node.receiver.as(LC::Ident).value.should eq "puts"

    node.args.size.should eq 3
    node.args[0].should be_a LC::StringLiteral
    node.args[0].as(LC::StringLiteral).value.should eq "foo"

    node.args[1].should be_a LC::StringLiteral
    node.args[1].as(LC::StringLiteral).value.should eq "bar"

    node.args[2].should be_a LC::StringLiteral
    node.args[2].as(LC::StringLiteral).value.should eq "baz"
  end

  it "parses call expressions on multiple lines" do
    node = parse_expr <<-CR
      puts(
        "hello from",
        "the other side",
      )
      CR

    node.should be_a LC::Call
    node = node.as(LC::Call)

    node.receiver.should be_a LC::Ident
    node.receiver.as(LC::Ident).value.should eq "puts"

    node.args.size.should eq 2
    node.args[0].should be_a LC::StringLiteral
    node.args[0].as(LC::StringLiteral).value.should eq "hello from"

    node.args[1].should be_a LC::StringLiteral
    node.args[1].as(LC::StringLiteral).value.should eq "the other side"
  end

  it "parses nested call expressions" do
    node = parse_expr <<-CR
      puts(
        "hello, ",
        your_name,
      )
      CR

    node.should be_a LC::Call
    node = node.as(LC::Call)

    node.receiver.should be_a LC::Ident
    node.receiver.as(LC::Ident).value.should eq "puts"

    node.args.size.should eq 2
    node.args[0].should be_a LC::StringLiteral
    node.args[0].as(LC::StringLiteral).value.should eq "hello, "

    node.args[1].should be_a LC::Call
    inner = node.args[1].as(LC::Call)

    inner.receiver.should be_a LC::Ident
    inner.receiver.as(LC::Ident).value.should eq "your_name"
  end

  # TODO: use refined exceptions for these

  it "raises on undelimited arguments for calls" do
    expect_raises(Exception, "expected a comma after the last argument") do
      parse_expr %(puts "foo" "bar")
    end
  end

  it "raises on unclosed parentheses for calls" do
    expect_raises(Exception, "expected closing parenthesis for call") do
      parse_expr %[puts("foo", "bar"]
    end
  end

  it "parses call expressions with variable declarations" do
    node = parse_expr "record Foo, bar : Int32, baz : String"

    node.should be_a LC::Call
    node = node.as(LC::Call)

    node.receiver.should be_a LC::Ident
    node.receiver.as(LC::Ident).value.should eq "record"

    node.args.size.should eq 3
    node.args[0].should be_a LC::Const
    node.args[0].as(LC::Const).value.should eq "Foo"

    node.args[1].should be_a LC::Var
    var = node.args[1].as(LC::Var)
    var.name.should be_a LC::Ident
    var.name.as(LC::Ident).value.should eq "bar"

    var.type.should be_a LC::Const
    var.type.as(LC::Const).value.should eq "Int32"
    var.value.should be_nil

    node.args[2].should be_a LC::Var
    var = node.args[2].as(LC::Var)
    var.name.should be_a LC::Ident
    var.name.as(LC::Ident).value.should eq "baz"

    var.type.should be_a LC::Const
    var.type.as(LC::Const).value.should eq "String"
    var.value.should be_nil
  end

  it "parses call expressions with variable assignments" do
    node = parse_expr %(record Foo, bar = 123, baz = "true")

    node.should be_a LC::Call
    node = node.as(LC::Call)

    node.receiver.should be_a LC::Ident
    node.receiver.as(LC::Ident).value.should eq "record"

    node.args.size.should eq 3
    node.args[0].should be_a LC::Const
    node.args[0].as(LC::Const).value.should eq "Foo"

    node.args[1].should be_a LC::Assign
    var = node.args[1].as(LC::Assign)
    var.target.should be_a LC::Ident
    var.target.as(LC::Ident).value.should eq "bar"

    var.value.should be_a LC::IntLiteral
    var.value.as(LC::IntLiteral).value.should eq 123

    node.args[2].should be_a LC::Assign
    var = node.args[2].as(LC::Assign)
    var.target.should be_a LC::Ident
    var.target.as(LC::Ident).value.should eq "baz"

    var.value.should be_a LC::StringLiteral
    var.value.as(LC::StringLiteral).value.should eq "true"
  end

  it "parses call expressions with variable declarations" do
    node = parse_expr %(record Foo, bar : Int32 = 123, baz : String = "true")

    node.should be_a LC::Call
    node = node.as(LC::Call)

    node.receiver.should be_a LC::Ident
    node.receiver.as(LC::Ident).value.should eq "record"

    node.args.size.should eq 3
    node.args[0].should be_a LC::Const
    node.args[0].as(LC::Const).value.should eq "Foo"

    node.args[1].should be_a LC::Var
    var = node.args[1].as(LC::Var)
    var.name.should be_a LC::Ident
    var.name.as(LC::Ident).value.should eq "bar"

    var.type.should be_a LC::Const
    var.type.as(LC::Const).value.should eq "Int32"

    var.value.should be_a LC::IntLiteral
    var.value.as(LC::IntLiteral).value.should eq 123

    node.args[2].should be_a LC::Var
    var = node.args[2].as(LC::Var)
    var.name.should be_a LC::Ident
    var.name.as(LC::Ident).value.should eq "baz"

    var.type.should be_a LC::Const
    var.type.as(LC::Const).value.should eq "String"

    var.value.should be_a LC::StringLiteral
    var.value.as(LC::StringLiteral).value.should eq "true"
  end
end
