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

  it "parses call expressions with a single variable declaration" do
    node = parse_expr "::property(name : String)"

    node.should be_a LC::Call
    node = node.as(LC::Call)

    node.receiver.should be_a LC::Ident
    node.receiver.as(LC::Ident).value.should eq "property"
    node.receiver.as(LC::Ident).global?.should be_true

    node.args.size.should eq 1
    node.args[0].should be_a LC::Var
    var = node.args[0].as(LC::Var)

    var.name.should be_a LC::Ident
    var.name.as(LC::Ident).value.should eq "name"

    var.type.should be_a LC::Const
    var.type.as(LC::Const).value.should eq "String"
    var.value.should be_nil
  end

  it "parses call expressions with a single variable assignment" do
    node = parse_expr %(::property(name = "dev"))

    node.should be_a LC::Call
    node = node.as(LC::Call)

    node.receiver.should be_a LC::Ident
    node.receiver.as(LC::Ident).value.should eq "property"
    node.receiver.as(LC::Ident).global?.should be_true

    node.args.size.should eq 1
    node.args[0].should be_a LC::Assign
    var = node.args[0].as(LC::Assign)

    var.target.should be_a LC::Ident
    var.target.as(LC::Ident).value.should eq "name"

    var.value.should be_a LC::StringLiteral
    var.value.as(LC::StringLiteral).value.should eq "dev"
  end

  it "parses call expressions with a single variable declaration and assignment" do
    node = parse_expr %(::property(name : String = "dev"))

    node.should be_a LC::Call
    node = node.as(LC::Call)

    node.receiver.should be_a LC::Ident
    node.receiver.as(LC::Ident).value.should eq "property"
    node.receiver.as(LC::Ident).global?.should be_true

    node.args.size.should eq 1
    node.args[0].should be_a LC::Var
    var = node.args[0].as(LC::Var)

    var.name.should be_a LC::Ident
    var.name.as(LC::Ident).value.should eq "name"

    var.type.should be_a LC::Const
    var.type.as(LC::Const).value.should eq "String"

    var.value.should be_a LC::StringLiteral
    var.value.as(LC::StringLiteral).value.should eq "dev"
  end

  it "parses call expressions with multiple variable declarations" do
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

  it "parses call expressions with multiple variable assignments" do
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

  it "parses call expressions with multiple variable declarations and assignments" do
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

  it "parses prefix operator expressions" do
    node = parse_expr "!true"

    node.should be_a LC::Prefix
    node = node.as(LC::Prefix)

    node.op.should eq LC::Prefix::Operator::Not
    node.value.should be_a LC::BoolLiteral
    node.value.as(LC::BoolLiteral).value.should be_true
  end

  it "parses double prefix operator expressions" do
    node = parse_expr "!!false"

    node.should be_a LC::Prefix
    node = node.as(LC::Prefix)

    node.op.should eq LC::Prefix::Operator::Not
    node.value.should be_a LC::Prefix
    value = node.value.as(LC::Prefix)

    value.op.should eq LC::Prefix::Operator::Not
    value.value.should be_a LC::BoolLiteral
    value.value.as(LC::BoolLiteral).value.should be_false
  end

  it "parses prefix operator expressions in calls" do
    node = parse_expr "puts !foo"

    node.should be_a LC::Call
    node = node.as(LC::Call)

    node.receiver.should be_a LC::Ident
    node.receiver.as(LC::Ident).value.should eq "puts"

    node.args.size.should eq 1
    node.args[0].should be_a LC::Prefix
    arg = node.args[0].as(LC::Prefix)

    arg.op.should eq LC::Prefix::Operator::Not
    arg.value.should be_a LC::Call
    arg.value.as(LC::Call).receiver.should be_a LC::Ident
    arg.value.as(LC::Call).receiver.as(LC::Ident).value.should eq "foo"
  end

  it "disallows prefix operators with incorrect syntax" do
    expect_raises(Exception) do
      parse_expr "puts ! foo"
    end
  end

  it "parses method defs" do
    node = parse_stmt <<-CR
      def foo
      end
      CR

    node.should be_a LC::Def
    node = node.as(LC::Def)

    node.name.should be_a LC::Ident
    node.name.as(LC::Ident).value.should eq "foo"

    node.params.should be_empty
    node.return_type.should be_nil
    node.body.should be_empty
  end

  it "parses method defs with a return type" do
    node = parse_stmt <<-CR
      def foo() : Nil
      end
      CR

    node.should be_a LC::Def
    node = node.as(LC::Def)

    node.name.should be_a LC::Ident
    node.name.as(LC::Ident).value.should eq "foo"

    node.params.should be_empty
    node.return_type.should be_a LC::Const
    node.return_type.as(LC::Const).value.should eq "Nil"
    node.body.should be_empty
  end

  it "parses method defs with a body" do
    node = parse_stmt <<-CR
      def foo() : Nil
        puts "bar"
        puts "baz"
      end
      CR

    node.should be_a LC::Def
    node = node.as(LC::Def)

    node.name.should be_a LC::Ident
    node.name.as(LC::Ident).value.should eq "foo"

    node.params.should be_empty
    node.return_type.should be_a LC::Const
    node.return_type.as(LC::Const).value.should eq "Nil"

    node.body.size.should eq 2
    node.body[0].should be_a LC::Call
    expr = node.body[0].as(LC::Call)

    expr.receiver.should be_a LC::Ident
    expr.receiver.as(LC::Ident).value.should eq "puts"
    expr.args.size.should eq 1
    expr.args[0].should be_a LC::StringLiteral
    expr.args[0].as(LC::StringLiteral).value.should eq "bar"

    node.body[1].should be_a LC::Call
    expr = node.body[1].as(LC::Call)

    expr.receiver.should be_a LC::Ident
    expr.receiver.as(LC::Ident).value.should eq "puts"
    expr.args.size.should eq 1
    expr.args[0].should be_a LC::StringLiteral
    expr.args[0].as(LC::StringLiteral).value.should eq "baz"
  end

  it "parses method defs with a single line body" do
    node = parse_stmt %(def foo() puts "bar" end)

    node.should be_a LC::Def
    node = node.as(LC::Def)

    node.name.should be_a LC::Ident
    node.name.as(LC::Ident).value.should eq "foo"

    node.params.should be_empty
    node.return_type.should be_nil

    node.body.size.should eq 1
    node.body[0].should be_a LC::Call
    expr = node.body[0].as(LC::Call)

    expr.receiver.should be_a LC::Ident
    expr.receiver.as(LC::Ident).value.should eq "puts"
    expr.args.size.should eq 1
    expr.args[0].should be_a LC::StringLiteral
    expr.args[0].as(LC::StringLiteral).value.should eq "bar"
  end

  it "disallows method def single line body without parentheses or newline" do
    expect_raises(Exception, "expected a newline after def signature") do
      parse_stmt %(def foo puts "bar" end)
    end
  end

  it "parses method defs with a single parameter" do
    node = parse_stmt <<-CR
      def greet(name : String = "dev") : Nil
        puts "Hello, ", name
      end
      CR

    node.should be_a LC::Def
    node = node.as(LC::Def)

    node.name.should be_a LC::Ident
    node.name.as(LC::Ident).value.should eq "greet"

    node.params.size.should eq 1
    param = node.params[0]

    param.name.should be_a LC::Ident
    param.name.as(LC::Ident).value.should eq "name"

    param.type.should be_a LC::Const
    param.type.as(LC::Const).value.should eq "String"

    param.default_value.should be_a LC::StringLiteral
    param.default_value.as(LC::StringLiteral).value.should eq "dev"

    node.return_type.should be_a LC::Const
    node.return_type.as(LC::Const).value.should eq "Nil"

    node.body.size.should eq 1
    node.body[0].should be_a LC::Call
    expr = node.body[0].as(LC::Call)

    expr.receiver.should be_a LC::Ident
    expr.receiver.as(LC::Ident).value.should eq "puts"

    expr.args.size.should eq 2
    expr.args[0].should be_a LC::StringLiteral
    expr.args[0].as(LC::StringLiteral).value.should eq "Hello, "

    expr.args[1].should be_a LC::Call
    call = expr.args[1].as(LC::Call)

    call.receiver.should be_a LC::Ident
    call.receiver.as(LC::Ident).value.should eq "name"
    call.args.should be_empty
  end

  it "parses method defs with multiple parameters" do
    node = parse_stmt <<-CR
      def add(a : Int32, b : Int32) : Int32
        a + b
      end
      CR

    node.should be_a LC::Def
    node = node.as(LC::Def)

    node.name.should be_a LC::Ident
    node.name.as(LC::Ident).value.should eq "add"

    node.params.size.should eq 2
    param = node.params[0]

    param.name.should be_a LC::Ident
    param.name.as(LC::Ident).value.should eq "a"
    param.type.should be_a LC::Const
    param.type.as(LC::Const).value.should eq "Int32"
    param.default_value.should be_nil
    param = node.params[1]

    param.name.should be_a LC::Ident
    param.name.as(LC::Ident).value.should eq "b"
    param.type.should be_a LC::Const
    param.type.as(LC::Const).value.should eq "Int32"
    param.default_value.should be_nil

    node.return_type.should be_a LC::Const
    node.return_type.as(LC::Const).value.should eq "Int32"

    node.body.size.should eq 1
    node.body[0].should be_a LC::Infix
    expr = node.body[0].as(LC::Infix)

    expr.left.should be_a LC::Call
    value = expr.left.as(LC::Call)

    value.receiver.should be_a LC::Ident
    value.receiver.as(LC::Ident).value.should eq "a"
    value.args.should be_empty

    expr.op.should eq LC::Infix::Operator::Add
    expr.right.should be_a LC::Call
    value = expr.right.as(LC::Call)

    value.receiver.should be_a LC::Ident
    value.receiver.as(LC::Ident).value.should eq "b"
    value.args.should be_empty
  end
end
