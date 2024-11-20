require "../spec_helper"

describe LC::Parser do
  context "calls and paths", tags: %w[parser calls paths] do
    it "parses call expressions with no arguments" do
      node = parse("exit").should be_a LC::Call
      receiver = node.receiver.should be_a LC::Ident

      receiver.value.should eq "exit"
      node.args.size.should eq 0
    end

    it "parses delimited call expressions" do
      {parse("puts;"), parse("puts\n")}.each do |node|
        node = node.should be_a LC::Call
        receiver = node.receiver.should be_a LC::Ident
        receiver.value.should eq "puts"
      end
    end

    it "parses path call expressions" do
      node = parse("foo.bar.baz").should be_a LC::Call
      receiver = node.receiver.should be_a LC::Path
      receiver.names.size.should eq 3

      ident = receiver.names[0].should be_a LC::Ident
      ident.value.should eq "foo"

      ident = receiver.names[1].should be_a LC::Ident
      ident.value.should eq "bar"

      ident = receiver.names[2].should be_a LC::Ident
      ident.value.should eq "baz"
    end

    it "parses constant path expressions" do
      node = parse("Foo::Bar").should be_a LC::Path
      node.names.size.should eq 2

      const = node.names[0].should be_a LC::Const
      const.value.should eq "Foo"
      const.global?.should be_false

      const = node.names[1].should be_a LC::Const
      const.value.should eq "Bar"
      const.global?.should be_true
    end

    it "parses constant call expresions" do
      node = parse("::Foo.baz").should be_a LC::Call
      receiver = node.receiver.should be_a LC::Path
      receiver.names.size.should eq 2

      const = receiver.names[0].should be_a LC::Const
      const.value.should eq "Foo"
      const.global?.should be_true

      ident = receiver.names[1].should be_a LC::Ident
      ident.value.should eq "baz"
      ident.global?.should be_false
    end

    it "parses call expressions with single arguments" do
      node = parse(%(puts "hello world")).should be_a LC::Call
      receiver = node.receiver.should be_a LC::Ident
      receiver.value.should eq "puts"
      node.args.size.should eq 1

      str = node.args[0].should be_a LC::StringLiteral
      str.value.should eq "hello world"
    end

    it "parses call expressions with multiple arguments" do
      node = parse(%(puts "foo", "bar", "baz")).should be_a LC::Call

      receiver = node.receiver.should be_a LC::Ident
      receiver.value.should eq "puts"
      node.args.size.should eq 3

      str = node.args[0].should be_a LC::StringLiteral
      str.value.should eq "foo"

      str = node.args[1].should be_a LC::StringLiteral
      str.value.should eq "bar"

      str = node.args[2].should be_a LC::StringLiteral
      str.value.should eq "baz"
    end

    it "parses call expressions on multiple lines" do
      node = parse(<<-CR).should be_a LC::Call
        puts(
          "hello from",
          "the other side",
        )
        CR

      receiver = node.receiver.should be_a LC::Ident
      receiver.value.should eq "puts"
      node.args.size.should eq 2

      str = node.args[0].should be_a LC::StringLiteral
      str.value.should eq "hello from"

      str = node.args[1].should be_a LC::StringLiteral
      str.value.should eq "the other side"
    end

    it "parses nested call expressions" do
      node = parse(<<-CR).should be_a LC::Call
        puts(
          "hello, ",
          your_name,
        )
        CR

      receiver = node.receiver.should be_a LC::Ident
      receiver.value.should eq "puts"
      node.args.size.should eq 2

      str = node.args[0].should be_a LC::StringLiteral
      str.value.should eq "hello, "

      call = node.args[1].should be_a LC::Call
      receiver = call.receiver.should be_a LC::Ident
      receiver.value.should eq "your_name"
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
      node = parse("::property(name : String)").should be_a LC::Call
      receiver = node.receiver.should be_a LC::Ident
      receiver.value.should eq "property"
      receiver.global?.should be_true
      node.args.size.should eq 1

      var = node.args[0].should be_a LC::Var
      name = var.name.should be_a LC::Ident
      name.value.should eq "name"

      const = var.type.should be_a LC::Const
      const.value.should eq "String"
      var.value.should be_nil
    end

    it "parses call expressions with a single variable assignment" do
      node = parse(%(::property(name = "dev"))).should be_a LC::Call
      receiver = node.receiver.should be_a LC::Ident
      receiver.value.should eq "property"
      receiver.global?.should be_true
      node.args.size.should eq 1

      var = node.args[0].should be_a LC::Assign
      ident = var.target.should be_a LC::Ident
      ident.value.should eq "name"

      str = var.value.should be_a LC::StringLiteral
      str.value.should eq "dev"
    end

    it "parses call expressions with a single variable declaration and assignment" do
      node = parse(%(::property(name : String = "dev"))).should be_a LC::Call
      receiver = node.receiver.should be_a LC::Ident
      receiver.value.should eq "property"
      receiver.global?.should be_true
      node.args.size.should eq 1

      var = node.args[0].should be_a LC::Var
      name = var.name.should be_a LC::Ident
      name.value.should eq "name"

      const = var.type.should be_a LC::Const
      const.value.should eq "String"

      str = var.value.should be_a LC::StringLiteral
      str.value.should eq "dev"
    end

    it "parses call expressions with multiple variable declarations" do
      node = parse("record Foo, bar : Int32, baz : String").should be_a LC::Call
      receiver = node.receiver.should be_a LC::Ident
      receiver.value.should eq "record"
      node.args.size.should eq 3

      const = node.args[0].should be_a LC::Const
      const.value.should eq "Foo"

      var = node.args[1].should be_a LC::Var
      name = var.name.should be_a LC::Ident
      name.value.should eq "bar"

      const = var.type.should be_a LC::Const
      const.value.should eq "Int32"
      var.value.should be_nil

      var = node.args[2].should be_a LC::Var
      name = var.name.should be_a LC::Ident
      name.value.should eq "baz"

      const = var.type.should be_a LC::Const
      const.value.should eq "String"
      var.value.should be_nil
    end

    it "parses call expressions with multiple variable assignments" do
      node = parse(%(record Foo, bar = 123, baz = "true")).should be_a LC::Call
      receiver = node.receiver.should be_a LC::Ident
      receiver.value.should eq "record"
      node.args.size.should eq 3

      const = node.args[0].should be_a LC::Const
      const.value.should eq "Foo"

      var = node.args[1].should be_a LC::Assign
      ident = var.target.should be_a LC::Ident
      ident.value.should eq "bar"

      int = var.value.should be_a LC::IntLiteral
      int.value.should eq 123

      var = node.args[2].should be_a LC::Assign
      ident = var.target.should be_a LC::Ident
      ident.value.should eq "baz"

      str = var.value.should be_a LC::StringLiteral
      str.value.should eq "true"
    end

    it "parses call expressions with multiple variable declarations and assignments" do
      node = parse(%(record Foo, bar : Int32 = 123, baz : String = "true")).should be_a LC::Call
      receiver = node.receiver.should be_a LC::Ident
      receiver.value.should eq "record"
      node.args.size.should eq 3

      const = node.args[0].should be_a LC::Const
      const.value.should eq "Foo"

      var = node.args[1].should be_a LC::Var
      ident = var.name.should be_a LC::Ident
      ident.value.should eq "bar"

      const = var.type.should be_a LC::Const
      const.value.should eq "Int32"

      int = var.value.should be_a LC::IntLiteral
      int.value.should eq 123

      var = node.args[2].should be_a LC::Var
      ident = var.name.should be_a LC::Ident
      ident.value.should eq "baz"

      const = var.type.should be_a LC::Const
      const.value.should eq "String"

      str = var.value.should be_a LC::StringLiteral
      str.value.should eq "true"
    end

    it "parses expressions ignoring semicolons" do
      node = parse(%(;;;;;;;puts "hello world";;;;;;;)).should be_a LC::Call
      receiver = node.receiver.should be_a LC::Ident
      receiver.value.should eq "puts"
      node.args.size.should eq 1

      str = node.args[0].should be_a LC::StringLiteral
      str.value.should eq "hello world"
    end
  end
end
