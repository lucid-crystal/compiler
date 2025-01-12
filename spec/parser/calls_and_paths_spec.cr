require "../spec_helper"

describe LC::Parser do
  context "calls and paths", tags: %w[parser calls paths] do
    it "parses call expressions with no arguments" do
      call = parse("exit").should be_a LC::Call
      call.loc.to_tuple.should eq({0, 0, 0, 4})

      ident = call.receiver.should be_a LC::Ident

      ident.value.should eq "exit"
      call.args.size.should eq 0
    end

    it "parses call expressions with keyword names" do
      call = parse("::alias").should be_a LC::Call
      call.loc.to_tuple.should eq({0, 0, 0, 7})

      ident = call.receiver.should be_a LC::Ident
      ident.value.should eq "alias"
      call.args.should be_empty

      call = parse(%(::require("my_file.cr"))).should be_a LC::Call
      call.loc.to_tuple.should eq({0, 0, 0, 23})

      ident = call.receiver.should be_a LC::Ident
      ident.value.should eq "require"
      call.args.size.should eq 1

      str = call.args[0].should be_a LC::StringLiteral
      str.value.should eq "my_file.cr"
    end

    it "parses delimited call expressions" do
      {parse("puts;"), parse("puts\n")}.each do |node|
        call = node.should be_a LC::Call
        ident = call.receiver.should be_a LC::Ident
        ident.value.should eq "puts"
      end
    end

    it "parses instance variables" do
      call = parse("@foo").should be_a LC::Call
      call.loc.to_tuple.should eq({0, 0, 0, 4})

      ivar = call.receiver.should be_a LC::InstanceVar
      ivar.value.should eq "foo"
      call.args.should be_empty
    end

    it "parses class variables" do
      call = parse("@@bar").should be_a LC::Call
      call.loc.to_tuple.should eq({0, 0, 0, 5})

      cvar = call.receiver.should be_a LC::ClassVar
      cvar.value.should eq "bar"
      call.args.should be_empty
    end

    it "parses path call expressions" do
      call = parse("foo.bar.baz").should be_a LC::Call
      call.loc.to_tuple.should eq({0, 0, 0, 11})

      path = call.receiver.should be_a LC::Path
      path.names.size.should eq 3

      ident = path.names[0].should be_a LC::Ident
      ident.value.should eq "foo"

      ident = path.names[1].should be_a LC::Ident
      ident.value.should eq "bar"

      ident = path.names[2].should be_a LC::Ident
      ident.value.should eq "baz"
    end

    it "parses path call expressions with keyword names" do
      call = parse("self.self.self").should be_a LC::Call
      call.loc.to_tuple.should eq({0, 0, 0, 14})

      path = call.receiver.should be_a LC::Path
      path.names.size.should eq 3

      3.times do |i|
        path.names[i - 1].should be_a LC::Self
      end

      call = parse("this.abstract.type").should be_a LC::Call
      call.loc.to_tuple.should eq({0, 0, 0, 18})

      path = call.receiver.should be_a LC::Path
      path.names.size.should eq 3

      ident = path.names[0].should be_a LC::Ident
      ident.value.should eq "this"

      ident = path.names[1].should be_a LC::Ident
      ident.value.should eq "abstract"

      ident = path.names[2].should be_a LC::Ident
      ident.value.should eq "type"
    end

    it "parses constant path expressions" do
      path = parse("Foo::Bar").should be_a LC::Path
      path.loc.to_tuple.should eq({0, 0, 0, 8})
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
      call.loc.to_tuple.should eq({0, 0, 0, 9})

      path = call.receiver.should be_a LC::Path
      path.names.size.should eq 2

      const = path.names[0].should be_a LC::Const
      const.value.should eq "Foo"
      const.global?.should be_true

      ident = path.names[1].should be_a LC::Ident
      ident.value.should eq "baz"
      ident.global?.should be_false
    end

    it "parses constant call expressions with keyword names" do
      call = parse("Foo.class").should be_a LC::Call
      call.loc.to_tuple.should eq({0, 0, 0, 9})

      path = call.receiver.should be_a LC::Path
      path.names.size.should eq 2

      const = path.names[0].should be_a LC::Const
      const.value.should eq "Foo"

      ident = path.names[1].should be_a LC::Ident
      ident.value.should eq "class"

      call = parse("::Bar::Baz.end").should be_a LC::Call
      call.loc.to_tuple.should eq({0, 0, 0, 14})

      path = call.receiver.should be_a LC::Path
      path.names.size.should eq 3

      const = path.names[0].should be_a LC::Const
      const.value.should eq "Bar"

      const = path.names[1].should be_a LC::Const
      const.value.should eq "Baz"

      ident = path.names[2].should be_a LC::Ident
      ident.value.should eq "end"
    end

    it "parses call expressions ending with special tokens" do
      infix = parse("call==").should be_a LC::Infix
      infix.loc.to_tuple.should eq({0, 0, 0, 6})

      call = infix.left.should be_a LC::Call
      ident = call.receiver.should be_a LC::Ident

      ident.value.should eq "call"
      infix.op.equal?.should be_true
      error = infix.right.should be_a LC::Error
      token = error.target.should be_a LC::Token

      token.kind.eof?.should be_true
      token.raw_value.should be_nil
      error.message.should eq "cannot parse expression 'eof'"
    end

    it "parses invalid calls as errors" do
      call = parse(%(foo."bar")).should be_a LC::Call
      call.loc.to_tuple.should eq({0, 0, 0, 9})

      path = call.receiver.should be_a LC::Path
      path.names.size.should eq 2

      ident = path.names[0].should be_a LC::Ident
      ident.value.should eq "foo"

      error = path.names[1].should be_a LC::Error
      token = error.target.should be_a LC::Token
      token.kind.string?.should be_true
      token.raw_value.should eq "bar"
      error.message.should eq %(unexpected token "bar")

      path = parse("Foo::'a'::Bar").should be_a LC::Path
      path.loc.to_tuple.should eq({0, 0, 0, 13})

      path.names.size.should eq 3

      const = path.names[0].should be_a LC::Const
      const.value.should eq "Foo"

      error = path.names[1].should be_a LC::Error
      token = error.target.should be_a LC::Token
      token.kind.char?.should be_true
      token.raw_value.should eq 'a'
      error.message.should eq %(unexpected token 'a')

      const = path.names[2].should be_a LC::Const
      const.value.should eq "Bar"

      call = parse("Foo.bar::Baz").should be_a LC::Call
      call.loc.to_tuple.should eq({0, 0, 0, 12})

      path = call.receiver.should be_a LC::Path
      path.names.size.should eq 4

      const = path.names[0].should be_a LC::Const
      const.value.should eq "Foo"

      ident = path.names[1].should be_a LC::Ident
      ident.value.should eq "bar"

      error = path.names[2].should be_a LC::Error
      token = error.target.should be_a LC::Token
      token.kind.double_colon?.should be_true
      token.raw_value.should be_nil
      error.message.should eq "unexpected token 'double_colon'"

      error = path.names[3].should be_a LC::Error
      const = error.target.should be_a LC::Const
      const.value.should eq "Baz"
      const.global?.should be_true
      error.message.should eq %(unexpected token "Baz")
    end

    it "parses call expressions with single arguments" do
      call = parse(%(puts "hello world")).should be_a LC::Call
      call.loc.to_tuple.should eq({0, 0, 0, 18})

      ident = call.receiver.should be_a LC::Ident
      ident.value.should eq "puts"
      call.args.size.should eq 1

      str = call.args[0].should be_a LC::StringLiteral
      str.value.should eq "hello world"
    end

    it "parses call expressions with multiple arguments" do
      call = parse(%(puts "foo", "bar", "baz")).should be_a LC::Call
      call.loc.to_tuple.should eq({0, 0, 0, 24})

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

      call.loc.to_tuple.should eq({0, 0, 3, 1})

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

      call.loc.to_tuple.should eq({0, 0, 3, 1})

      ident = call.receiver.should be_a LC::Ident
      ident.value.should eq "puts"
      call.args.size.should eq 2

      str = call.args[0].should be_a LC::StringLiteral
      str.value.should eq "hello, "

      inner = call.args[1].should be_a LC::Call
      ident = inner.receiver.should be_a LC::Ident
      ident.value.should eq "your_name"
    end

    # TODO: also test fail-first exceptions here

    it "parses undelimited call arguments" do
      call = parse(%(puts "foo" "bar")).should be_a LC::Call
      call.loc.to_tuple.should eq({0, 0, 0, 16})
      call.args.size.should eq 2

      str = call.args[0].should be_a LC::StringLiteral
      str.value.should eq "foo"

      error = call.args[1].should be_a LC::Error
      str = error.target.should be_a LC::StringLiteral
      str.value.should eq "bar"
      error.message.should eq "expected a comma after the last argument"
    end

    it "parses trailing commas in call arguments as errors" do
      call = parse("puts foo,").should be_a LC::Call
      call.loc.to_tuple.should eq({0, 0, 0, 9})
      call.args.size.should eq 2

      inner = call.args[0].should be_a LC::Call
      ident = inner.receiver.should be_a LC::Ident
      ident.value.should eq "foo"
      inner.args.should be_empty

      error = call.args[1].should be_a LC::Error
      token = error.target.should be_a LC::Token

      token.kind.comma?.should be_true
      token.raw_value.should be_nil
      error.message.should eq "invalid trailing comma in call"
    end

    it "parses duplicate commas in call arguments as errors" do
      call = parse("puts foo,,").should be_a LC::Call
      call.loc.to_tuple.should eq({0, 0, 0, 10})
      call.args.size.should eq 2

      inner = call.args[0].should be_a LC::Call
      ident = inner.receiver.should be_a LC::Ident
      ident.value.should eq "foo"
      inner.args.should be_empty

      error = call.args[1].should be_a LC::Error
      token = error.target.should be_a LC::Token

      token.kind.comma?.should be_true
      token.raw_value.should be_nil
      error.message.should eq "unexpected token ','"
    end

    it "parses unclosed parenthesis calls as errors" do
      error = parse(%[puts("foo", "bar"]).should be_a LC::Error
      error.loc.to_tuple.should eq({0, 0, 0, 17})

      call = error.target.should be_a LC::Call
      ident = call.receiver.should be_a LC::Ident

      ident.value.should eq "puts"
      call.args.size.should eq 2
      str = call.args[0].should be_a LC::StringLiteral

      str.value.should eq "foo"
      str = call.args[1].should be_a LC::StringLiteral

      str.value.should eq "bar"
      error.message.should eq "expected closing parenthesis for call"
    end

    it "parses call expressions with a single variable declaration" do
      call = parse("::property(name : String)").should be_a LC::Call
      call.loc.to_tuple.should eq({0, 0, 0, 25})

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
      call.loc.to_tuple.should eq({0, 0, 0, 24})

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
      call.loc.to_tuple.should eq({0, 0, 0, 33})

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
      call.loc.to_tuple.should eq({0, 0, 0, 37})

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
      call.loc.to_tuple.should eq({0, 0, 0, 35})

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
      call.loc.to_tuple.should eq({0, 0, 0, 52})

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
      call.loc.to_tuple.should eq({0, 7, 0, 25})

      ident = call.receiver.should be_a LC::Ident
      ident.value.should eq "puts"
      call.args.size.should eq 1

      str = call.args[0].should be_a LC::StringLiteral
      str.value.should eq "hello world"
    end
  end
end
