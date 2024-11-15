require "../spec_helper"

describe LC::Parser do
  context "calls and paths", tags: %w[parser calls paths] do
    it "parses call expressions with no arguments" do
      node = parse "exit"
      node.should be_a LC::Call
      node = node.as(LC::Call)

      node.receiver.should be_a LC::Ident
      node.receiver.as(LC::Ident).value.should eq "exit"
      node.args.size.should eq 0
    end

    it "parses delimited call expressions" do
      {parse("puts;"), parse("puts\n")}.each do |node|
        node.should be_a LC::Call
        node = node.as(LC::Call)

        node.receiver.should be_a LC::Ident
        node.receiver.as(LC::Ident).value.should eq "puts"
      end
    end

    it "parses path call expressions" do
      node = parse "foo.bar.baz"
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
      node = parse "Foo::Bar"
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
      node = parse "::Foo.baz"
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
      node = parse %(puts "hello world")
      node.should be_a LC::Call
      node = node.as(LC::Call)

      node.receiver.should be_a LC::Ident
      node.receiver.as(LC::Ident).value.should eq "puts"

      node.args.size.should eq 1
      node.args[0].should be_a LC::StringLiteral
      node.args[0].as(LC::StringLiteral).value.should eq "hello world"
    end

    it "parses call expressions with multiple arguments" do
      node = parse %(puts "foo", "bar", "baz")
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
      node = parse <<-CR
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
      node = parse <<-CR
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
        parse %(puts "foo" "bar")
      end
    end

    it "raises on unclosed parentheses for calls" do
      expect_raises(Exception, "expected closing parenthesis for call") do
        parse %[puts("foo", "bar"]
      end
    end

    it "parses call expressions with a single variable declaration" do
      node = parse "::property(name : String)"

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
      node = parse %(::property(name = "dev"))

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
      node = parse %(::property(name : String = "dev"))

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
      node = parse "record Foo, bar : Int32, baz : String"

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
      node = parse %(record Foo, bar = 123, baz = "true")

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
      node = parse %(record Foo, bar : Int32 = 123, baz : String = "true")

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

    it "parses expressions ignoring semicolons" do
      node = parse %(;;;;;;;puts "hello world";;;;;;;)

      node.should be_a LC::Call
      node = node.as(LC::Call)

      node.receiver.should be_a LC::Ident
      node.receiver.as(LC::Ident).value.should eq "puts"

      node.args.size.should eq 1
      node.args[0].should be_a LC::StringLiteral
      node.args[0].as(LC::StringLiteral).value.should eq "hello world"
    end
  end
end
