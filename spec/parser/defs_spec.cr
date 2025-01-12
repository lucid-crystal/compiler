require "../spec_helper"

describe LC::Parser do
  context "defs", tags: %w[parser defs] do
    it "parses method defs" do
      node = parse(<<-CR).should be_a LC::Def
        def foo
        end
        CR

      node.loc.to_tuple.should eq({0, 0, 1, 3})

      ident = node.name.should be_a LC::Ident
      ident.value.should eq "foo"

      node.params.should be_empty
      node.return_type.should be_nil
      node.body.should be_empty

      node = parse(<<-CR).should be_a LC::Def
        def foo; end
        CR

      node.loc.to_tuple.should eq({0, 0, 0, 12})

      ident = node.name.should be_a LC::Ident
      ident.value.should eq "foo"

      node.params.should be_empty
      node.return_type.should be_nil
      node.body.should be_empty
    end

    it "parses method defs with a return type" do
      node = parse(<<-CR).should be_a LC::Def
        def foo() : Nil
        end
        CR

      node.loc.to_tuple.should eq({0, 0, 1, 3})

      ident = node.name.should be_a LC::Ident
      ident.value.should eq "foo"
      node.params.should be_empty

      const = node.return_type.should be_a LC::Const
      const.value.should eq "Nil"
      node.body.should be_empty

      node = parse(<<-CR).should be_a LC::Def
        def foo : Nil; end
        CR

      node.loc.to_tuple.should eq({0, 0, 0, 18})

      node.name.should be_a LC::Ident
      node.name.as(LC::Ident).value.should eq "foo"

      node.params.should be_empty
      node.return_type.should be_a LC::Const
      node.return_type.as(LC::Const).value.should eq "Nil"
      node.body.should be_empty
    end

    it "parses method defs with a body (1)" do
      node = parse <<-CR
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

    it "parses method defs with a body (2)" do
      node = parse <<-CR
        def test : Nil
          foo
          bar
          baz
        end
        CR

      node.should be_a LC::Def
      node = node.as(LC::Def)

      node.name.should be_a LC::Ident
      node.name.as(LC::Ident).value.should eq "test"

      node.params.should be_empty
      node.return_type.should be_a LC::Const
      node.return_type.as(LC::Const).value.should eq "Nil"

      node.body.size.should eq 3
      node.body[0].should be_a LC::Call
      expr = node.body[0].as(LC::Call)

      expr.receiver.should be_a LC::Ident
      expr.receiver.as(LC::Ident).value.should eq "foo"
      expr = node.body[1].as(LC::Call)

      expr.receiver.should be_a LC::Ident
      expr.receiver.as(LC::Ident).value.should eq "bar"
      expr = node.body[2].as(LC::Call)

      expr.receiver.should be_a LC::Ident
      expr.receiver.as(LC::Ident).value.should eq "baz"
    end

    it "parses method defs with a single line body" do
      node = parse "def foo() puts end"
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
      expr.args.should be_empty

      node = parse %(def foo() puts "bar" end)
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

    it "errors on method def single line body without parentheses, newline or semicolon" do
      method = parse(%(def foo puts "bar" end)).should be_a LC::Def
      error = method.name.should be_a LC::Error
      ident = error.target.should be_a LC::Ident

      ident.value.should eq "foo"
      error.message.should eq %(expected a newline or semicolon after def signature; got "puts")

      method.return_type.should be_nil
      method.body.size.should eq 1
      call = method.body[0].should be_a LC::Call
      ident = call.receiver.should be_a LC::Ident

      ident.value.should eq "puts"
      call.args.size.should eq 1
      str = call.args[0].should be_a LC::StringLiteral

      str.value.should eq "bar"
    end

    it "errors on method defs with undelimited parameters" do
      method = parse("def foo(bar baz qux); end").should be_a LC::Def
      ident = method.name.should be_a LC::Ident

      ident.value.should eq "foo"
      method.params.size.should eq 2
      param = method.params[0]
      ident = param.name.should be_a LC::Ident

      ident.value.should eq "bar"
      ident = param.internal_name.should be_a LC::Ident

      ident.value.should eq "baz"
      param.type.should be_nil
      param.default_value.should be_nil
      param = method.params[1]
      error = param.name.should be_a LC::Error
      token = error.target.should be_a LC::Token

      token.kind.ident?.should be_true
      token.raw_value.should eq "qux"
      error.message.should eq %(expected a comma or right parenthesis; got "qux")
    end

    it "parses method defs with a single parameter" do
      node = parse <<-CR
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
      node = parse <<-CR
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

    it "parses method defs with external parameter names" do
      node = parse <<-CR
        def write(to file : IO) : Nil
        end
        CR

      node.should be_a LC::Def
      node = node.as(LC::Def)

      node.name.should be_a LC::Ident
      node.name.as(LC::Ident).value.should eq "write"

      node.params.size.should eq 1
      param = node.params[0]

      param.name.should be_a LC::Ident
      param.name.as(LC::Ident).value.should eq "to"
      param.internal_name.should be_a LC::Ident
      param.internal_name.as(LC::Ident).value.should eq "file"
      param.type.should be_a LC::Const
      param.type.as(LC::Const).value.should eq "IO"

      node.return_type.should be_a LC::Const
      node.return_type.as(LC::Const).value.should eq "Nil"
    end

    it "errors on method def external names for block parameters" do
      method = parse("def write(&to file); end").should be_a LC::Def
      ident = method.name.should be_a LC::Ident
      ident.value.should eq "write"
      method.params.size.should eq 1

      param = method.params[0]
      error = param.name.should be_a LC::Error
      ident = error.target.should be_a LC::Ident
      ident.value.should eq "to"
      error.message.should eq "block parameters cannot have external names"

      ident = param.internal_name.should be_a LC::Ident
      ident.value.should eq "file"
      param.block?.should be_true
    end

    it "parses method defs with free variables" do
      node = parse <<-CR
        def foo(x : T, y : U) forall T, U
        end
        CR

      node.should be_a LC::Def
      node = node.as(LC::Def)

      node.name.should be_a LC::Ident
      node.name.as(LC::Ident).value.should eq "foo"

      node.params.size.should eq 2
      param = node.params[0]

      param.name.should be_a LC::Ident
      param.name.as(LC::Ident).value.should eq "x"
      param.type.should be_a LC::Const
      param.type.as(LC::Const).value.should eq "T"
      param = node.params[1]

      param.name.should be_a LC::Ident
      param.name.as(LC::Ident).value.should eq "y"
      param.type.should be_a LC::Const
      param.type.as(LC::Const).value.should eq "U"

      node.return_type.should be_nil
      node.free_vars.size.should eq 2

      const = node.free_vars[0].should be_a LC::Const
      const.value.should eq "T"

      const = node.free_vars[1].should be_a LC::Const
      const.value.should eq "U"
    end

    it "errors on method defs with invalid free variables" do
      method = parse("def foo : T forall 3; end").should be_a LC::Def
      ident = method.name.should be_a LC::Ident

      ident.value.should eq "foo"
      const = method.return_type.should be_a LC::Const

      const.value.should eq "T"
      method.free_vars.size.should eq 1
      error = method.free_vars[0].should be_a LC::Error
      token = error.target.should be_a LC::Token

      token.kind.integer?.should be_true
      token.raw_value.should eq "3"
      error.message.should eq "expected token 'const', not 'integer'"

      method = parse("def foo : U forall T::U; end").should be_a LC::Def
      ident = method.name.should be_a LC::Ident

      ident.value.should eq "foo"
      const = method.return_type.should be_a LC::Const

      const.value.should eq "U"
      method.free_vars.size.should eq 1
      error = method.free_vars[0].should be_a LC::Error
      path = error.target.should be_a LC::Path

      path.names.size.should eq 2
      const = path.names[0].should be_a LC::Const

      const.value.should eq "T"
      const = path.names[1].should be_a LC::Const

      const.value.should eq "U"
      error.message.should eq "free variables cannot be paths"
    end

    it "parses abstract method defs" do
      node = parse "abstract def read(slice : Bytes) : Int32"
      node.should be_a LC::Def
      node = node.as(LC::Def)

      node.name.should be_a LC::Ident
      node.name.as(LC::Ident).value.should eq "read"

      node.params.size.should eq 1
      param = node.params[0]

      param.name.should be_a LC::Ident
      param.name.as(LC::Ident).value.should eq "slice"
      param.type.should be_a LC::Const
      param.type.as(LC::Const).value.should eq "Bytes"

      node.return_type.should be_a LC::Const
      node.return_type.as(LC::Const).value.should eq "Int32"

      node.body.should be_empty
      node.private?.should be_false
      node.protected?.should be_false
      node.abstract?.should be_true
    end

    it "parses private method defs" do
      node = parse <<-CR
        private def read_impl(slice : Bytes) : Int32
          does_something_cool
        end
        CR

      node.should be_a LC::Def
      node = node.as(LC::Def)

      node.name.should be_a LC::Ident
      node.name.as(LC::Ident).value.should eq "read_impl"

      node.params.size.should eq 1
      param = node.params[0]

      param.name.should be_a LC::Ident
      param.name.as(LC::Ident).value.should eq "slice"
      param.type.should be_a LC::Const
      param.type.as(LC::Const).value.should eq "Bytes"

      node.return_type.should be_a LC::Const
      node.return_type.as(LC::Const).value.should eq "Int32"

      node.body.size.should eq 1
      node.body[0].should be_a LC::Call
      expr = node.body[0].as(LC::Call)

      expr.receiver.should be_a LC::Ident
      expr.receiver.as(LC::Ident).value.should eq "does_something_cool"

      node.private?.should be_true
      node.protected?.should be_false
      node.abstract?.should be_false
    end

    it "parses protected method defs" do
      node = parse <<-CR
        protected def does_something_cool : Nil
        end
        CR

      node.should be_a LC::Def
      node = node.as(LC::Def)

      node.name.should be_a LC::Ident
      node.name.as(LC::Ident).value.should eq "does_something_cool"

      node.params.should be_empty
      node.return_type.should be_a LC::Const
      node.return_type.as(LC::Const).value.should eq "Nil"
      node.body.should be_empty

      node.private?.should be_false
      node.protected?.should be_true
      node.abstract?.should be_false
    end

    it "parses private abstract method defs" do
      node = parse "private abstract def select_impl : Nil"

      node.should be_a LC::Def
      node = node.as(LC::Def)

      node.name.should be_a LC::Ident
      node.name.as(LC::Ident).value.should eq "select_impl"

      node.params.should be_empty
      node.return_type.should be_a LC::Const
      node.return_type.as(LC::Const).value.should eq "Nil"
      node.body.should be_empty

      node.private?.should be_true
      node.protected?.should be_false
      node.abstract?.should be_true
    end

    it "parses protected abstract method defs" do
      node = parse "protected abstract def execute : Bool"

      node.should be_a LC::Def
      node = node.as(LC::Def)

      node.name.should be_a LC::Ident
      node.name.as(LC::Ident).value.should eq "execute"

      node.params.should be_empty
      node.return_type.should be_a LC::Const
      node.return_type.as(LC::Const).value.should eq "Bool"
      node.body.should be_empty

      node.private?.should be_false
      node.protected?.should be_true
      node.abstract?.should be_true
    end

    it "errors on duplicate visibility keywords on method defs" do
      nodes = parse_all "private private def foo; end"
      nodes.size.should eq 2

      error = nodes[0].should be_a LC::Error
      token = error.target.should be_a LC::Token

      token.kind.private?.should be_true
      token.raw_value.should be_nil
      error.message.should eq "unexpected token 'private'"

      method = nodes[1].should be_a LC::Def
      ident = method.name.should be_a LC::Ident

      ident.value.should eq "foo"
      method.private?.should be_true
      method.protected?.should be_false
      method.abstract?.should be_false

      nodes = parse_all "protected protected def bar; end"
      nodes.size.should eq 2

      error = nodes[0].should be_a LC::Error
      token = error.target.should be_a LC::Token

      token.kind.protected?.should be_true
      token.raw_value.should be_nil
      error.message.should eq "unexpected token 'protected'"

      method = nodes[1].should be_a LC::Def
      ident = method.name.should be_a LC::Ident

      ident.value.should eq "bar"
      method.private?.should be_false
      method.protected?.should be_true
      method.abstract?.should be_false

      nodes = parse_all "abstract abstract def baz"
      nodes.size.should eq 2

      error = nodes[0].should be_a LC::Error
      token = error.target.should be_a LC::Token

      token.kind.abstract?.should be_true
      token.raw_value.should be_nil
      error.message.should eq "unexpected token 'abstract'"

      method = nodes[1].should be_a LC::Def
      ident = method.name.should be_a LC::Ident

      ident.value.should eq "baz"
      method.private?.should be_false
      method.protected?.should be_false
      method.abstract?.should be_true
    end

    it "errors on private-protected keywords on method defs" do
      nodes = parse_all "private protected def foo; end"
      nodes.size.should eq 2

      error = nodes[0].should be_a LC::Error
      token = error.target.should be_a LC::Token

      token.kind.protected?.should be_true
      token.raw_value.should be_nil
      error.message.should eq "cannot apply private and protected visibility"

      method = nodes[1].should be_a LC::Def
      ident = method.name.should be_a LC::Ident

      ident.value.should eq "foo"
      method.private?.should be_false
      method.protected?.should be_true
      method.abstract?.should be_false
    end
  end
end
