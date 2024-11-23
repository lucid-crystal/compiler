require "../spec_helper"

describe LC::Parser do
  context "calls and paths", tags: %w[parser calls paths] do
    it "parses call expressions with no arguments" do
      call = parse("exit").should be_a LC::Call
      ident = call.receiver.should be_a LC::Ident

      ident.value.should eq "exit"
      call.args.size.should eq 0
    end

    it "parses delimited call expressions" do
      {parse("puts;"), parse("puts\n")}.each do |node|
        call = node.should be_a LC::Call
        ident = call.receiver.should be_a LC::Ident
        ident.value.should eq "puts"
      end
    end

    it "parses path call expressions" do
      call = parse("foo.bar.baz").should be_a LC::Call
      path = call.receiver.should be_a LC::Path
      path.names.size.should eq 3

      ident = path.names[0].should be_a LC::Ident
      ident.value.should eq "foo"

      ident = path.names[1].should be_a LC::Ident
      ident.value.should eq "bar"

      ident = path.names[2].should be_a LC::Ident
      ident.value.should eq "baz"
    end

    it "parses constant path expressions" do
      path = parse("Foo::Bar").should be_a LC::Path
      path.names.size.should eq 2

      const = path.names[0].should be_a LC::Const
      const.value.should eq "Foo"
      const.global?.should be_false

      const = path.names[1].should be_a LC::Const
      const.value.should eq "Bar"
      const.global?.should be_true
    end

    it "parses constant call expresions" do
      call = parse("::Foo.baz").should be_a LC::Call
      path = call.receiver.should be_a LC::Path
      path.names.size.should eq 2

      const = path.names[0].should be_a LC::Const
      const.value.should eq "Foo"
      const.global?.should be_true

      ident = path.names[1].should be_a LC::Ident
      ident.value.should eq "baz"
      ident.global?.should be_false
    end

    it "parses call expressions with single arguments" do
      call = parse(%(puts "hello world")).should be_a LC::Call
      ident = call.receiver.should be_a LC::Ident
      ident.value.should eq "puts"
      call.args.size.should eq 1

      str = call.args[0].should be_a LC::StringLiteral
      str.value.should eq "hello world"
    end

    it "parses call expressions with multiple arguments" do
      call = parse(%(puts "foo", "bar", "baz")).should be_a LC::Call

      ident = call.receiver.should be_a LC::Ident
      ident.value.should eq "puts"
      call.args.size.should eq 3

      str = call.args[0].should be_a LC::StringLiteral
      str.value.should eq "foo"

      str = call.args[1].should be_a LC::StringLiteral
      str.value.should eq "bar"

      str = call.args[2].should be_a LC::StringLiteral
      str.value.should eq "baz"
    end

    it "parses call expressions on multiple lines" do
      call = parse(<<-CR).should be_a LC::Call
        puts(
          "hello from",
          "the other side",
        )
        CR

      ident = call.receiver.should be_a LC::Ident
      ident.value.should eq "puts"
      call.args.size.should eq 2

      str = call.args[0].should be_a LC::StringLiteral
      str.value.should eq "hello from"

      str = call.args[1].should be_a LC::StringLiteral
      str.value.should eq "the other side"
    end

    it "parses nested call expressions" do
      call = parse(<<-CR).should be_a LC::Call
        puts(
          "hello, ",
          your_name,
        )
        CR

      ident = call.receiver.should be_a LC::Ident
      ident.value.should eq "puts"
      call.args.size.should eq 2

      str = call.args[0].should be_a LC::StringLiteral
      str.value.should eq "hello, "

      inner = call.args[1].should be_a LC::Call
      ident = inner.receiver.should be_a LC::Ident
      ident.value.should eq "your_name"
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
      call = parse("::property(name : String)").should be_a LC::Call
      ident = call.receiver.should be_a LC::Ident
      ident.value.should eq "property"
      ident.global?.should be_true
      call.args.size.should eq 1

      var = call.args[0].should be_a LC::Var
      name = var.name.should be_a LC::Ident
      name.value.should eq "name"

      const = var.type.should be_a LC::Const
      const.value.should eq "String"
      var.value.should be_nil
    end

    it "parses call expressions with a single variable assignment" do
      call = parse(%(::property(name = "dev"))).should be_a LC::Call
      ident = call.receiver.should be_a LC::Ident
      ident.value.should eq "property"
      ident.global?.should be_true
      call.args.size.should eq 1

      var = call.args[0].should be_a LC::Assign
      ident = var.target.should be_a LC::Ident
      ident.value.should eq "name"

      str = var.value.should be_a LC::StringLiteral
      str.value.should eq "dev"
    end

    it "parses call expressions with a single variable declaration and assignment" do
      call = parse(%(::property(name : String = "dev"))).should be_a LC::Call
      ident = call.receiver.should be_a LC::Ident
      ident.value.should eq "property"
      ident.global?.should be_true
      call.args.size.should eq 1

      var = call.args[0].should be_a LC::Var
      name = var.name.should be_a LC::Ident
      name.value.should eq "name"

      const = var.type.should be_a LC::Const
      const.value.should eq "String"

      str = var.value.should be_a LC::StringLiteral
      str.value.should eq "dev"
    end

    it "parses call expressions with multiple variable declarations" do
      call = parse("record Foo, bar : Int32, baz : String").should be_a LC::Call
      ident = call.receiver.should be_a LC::Ident
      ident.value.should eq "record"
      call.args.size.should eq 3

      const = call.args[0].should be_a LC::Const
      const.value.should eq "Foo"

      var = call.args[1].should be_a LC::Var
      name = var.name.should be_a LC::Ident
      name.value.should eq "bar"

      const = var.type.should be_a LC::Const
      const.value.should eq "Int32"
      var.value.should be_nil

      var = call.args[2].should be_a LC::Var
      name = var.name.should be_a LC::Ident
      name.value.should eq "baz"

      const = var.type.should be_a LC::Const
      const.value.should eq "String"
      var.value.should be_nil
    end

    it "parses call expressions with multiple variable assignments" do
      call = parse(%(record Foo, bar = 123, baz = "true")).should be_a LC::Call
      ident = call.receiver.should be_a LC::Ident
      ident.value.should eq "record"
      call.args.size.should eq 3

      const = call.args[0].should be_a LC::Const
      const.value.should eq "Foo"

      var = call.args[1].should be_a LC::Assign
      ident = var.target.should be_a LC::Ident
      ident.value.should eq "bar"

      int = var.value.should be_a LC::IntLiteral
      int.value.should eq 123

      var = call.args[2].should be_a LC::Assign
      ident = var.target.should be_a LC::Ident
      ident.value.should eq "baz"

      str = var.value.should be_a LC::StringLiteral
      str.value.should eq "true"
    end

    it "parses call expressions with multiple variable declarations and assignments" do
      call = parse(%(record Foo, bar : Int32 = 123, baz : String = "true")).should be_a LC::Call
      ident = call.receiver.should be_a LC::Ident
      ident.value.should eq "record"
      call.args.size.should eq 3

      const = call.args[0].should be_a LC::Const
      const.value.should eq "Foo"

      var = call.args[1].should be_a LC::Var
      ident = var.name.should be_a LC::Ident
      ident.value.should eq "bar"

      const = var.type.should be_a LC::Const
      const.value.should eq "Int32"

      int = var.value.should be_a LC::IntLiteral
      int.value.should eq 123

      var = call.args[2].should be_a LC::Var
      ident = var.name.should be_a LC::Ident
      ident.value.should eq "baz"

      const = var.type.should be_a LC::Const
      const.value.should eq "String"

      str = var.value.should be_a LC::StringLiteral
      str.value.should eq "true"
    end

    it "parses expressions ignoring semicolons" do
      call = parse(%(;;;;;;;puts "hello world";;;;;;;)).should be_a LC::Call
      ident = call.receiver.should be_a LC::Ident
      ident.value.should eq "puts"
      call.args.size.should eq 1

      str = call.args[0].should be_a LC::StringLiteral
      str.value.should eq "hello world"
    end
  end
end
