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

      ident = node.name.should be_a LC::Ident
      ident.value.should eq "foo"
      node.params.should be_empty

      const = node.return_type.should be_a LC::Const
      const.value.should eq "Nil"
      node.body.should be_empty
    end

    it "parses method defs with a body (1)" do
      node = parse(<<-CR).should be_a LC::Def
        def foo() : Nil
          puts "bar"
          puts "baz"
        end
        CR

      ident = node.name.should be_a LC::Ident
      ident.value.should eq "foo"
      node.params.should be_empty

      const = node.return_type.should be_a LC::Const
      const.value.should eq "Nil"
      node.body.size.should eq 2

      call = node.body[0].should be_a LC::Call
      ident = call.receiver.should be_a LC::Ident
      ident.value.should eq "puts"
      call.args.size.should eq 1

      str = call.args[0].should be_a LC::StringLiteral
      str.value.should eq "bar"

      call = node.body[1].should be_a LC::Call
      ident = call.receiver.should be_a LC::Ident
      ident.value.should eq "puts"
      call.args.size.should eq 1

      str = call.args[0].should be_a LC::StringLiteral
      str.value.should eq "baz"
    end

    it "parses method defs with a body (2)" do
      node = parse(<<-CR).should be_a LC::Def
        def test : Nil
          foo
          bar
          baz
        end
        CR

      ident = node.name.should be_a LC::Ident
      ident.value.should eq "test"
      node.params.should be_empty

      const = node.return_type.should be_a LC::Const
      const.value.should eq "Nil"
      node.body.size.should eq 3

      call = node.body[0].should be_a LC::Call
      ident = call.receiver.should be_a LC::Ident
      ident.value.should eq "foo"

      call = node.body[1].should be_a LC::Call
      ident = call.receiver.should be_a LC::Ident
      ident.value.should eq "bar"

      call = node.body[2].should be_a LC::Call
      ident = call.receiver.should be_a LC::Ident
      ident.value.should eq "baz"
    end

    it "parses method defs with a single line body" do
      node = parse("def foo() puts end").should be_a LC::Def
      ident = node.name.should be_a LC::Ident

      ident.value.should eq "foo"
      node.params.should be_empty
      node.return_type.should be_nil
      node.body.size.should eq 1

      call = node.body[0].should be_a LC::Call
      ident = call.receiver.should be_a LC::Ident
      ident.value.should eq "puts"
      call.args.should be_empty

      node = parse(%(def foo() puts "bar" end)).should be_a LC::Def
      ident = node.name.should be_a LC::Ident

      ident.value.should eq "foo"
      node.params.should be_empty
      node.return_type.should be_nil
      node.body.size.should eq 1

      call = node.body[0].should be_a LC::Call
      ident = call.receiver.should be_a LC::Ident
      ident.value.should eq "puts"
      call.args.size.should eq 1

      str = call.args[0].should be_a LC::StringLiteral
      str.value.should eq "bar"
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
      node = parse(<<-CR).should be_a LC::Def
        def greet(name : String = "dev") : Nil
          puts "Hello, ", name
        end
        CR

      ident = node.name.should be_a LC::Ident
      ident.value.should eq "greet"
      node.params.size.should eq 1

      param = node.params[0]
      ident = param.name.should be_a LC::Ident
      ident.value.should eq "name"

      const = param.type.should be_a LC::Const
      const.value.should eq "String"

      str = param.default_value.should be_a LC::StringLiteral
      str.value.should eq "dev"

      const = node.return_type.should be_a LC::Const
      const.value.should eq "Nil"
      node.body.size.should eq 1

      call = node.body[0].should be_a LC::Call
      ident = call.receiver.should be_a LC::Ident
      ident.value.should eq "puts"
      call.args.size.should eq 2

      str = call.args[0].should be_a LC::StringLiteral
      str.value.should eq "Hello, "

      call = call.args[1].should be_a LC::Call
      ident = call.receiver.should be_a LC::Ident
      ident.value.should eq "name"
      call.args.should be_empty
    end

    it "parses method defs with multiple parameters" do
      node = parse(<<-CR).should be_a LC::Def
        def add(a : Int32, b : Int32) : Int32
          a + b
        end
        CR

      ident = node.name.should be_a LC::Ident
      ident.value.should eq "add"
      node.params.size.should eq 2

      param = node.params[0]
      ident = param.name.should be_a LC::Ident
      ident.value.should eq "a"

      const = param.type.should be_a LC::Const
      const.value.should eq "Int32"
      param.default_value.should be_nil

      param = node.params[1]
      ident = param.name.should be_a LC::Ident
      ident.value.should eq "b"

      const = param.type.should be_a LC::Const
      const.value.should eq "Int32"
      param.default_value.should be_nil

      const = node.return_type.should be_a LC::Const
      const.value.should eq "Int32"
      node.body.size.should eq 1

      infix = node.body[0].should be_a LC::Infix
      left = infix.left.should be_a LC::Call
      ident = left.receiver.should be_a LC::Ident

      ident.value.should eq "a"
      left.args.should be_empty
      infix.op.should eq LC::Infix::Operator::Add

      right = infix.right.should be_a LC::Call
      ident = right.receiver.should be_a LC::Ident
      ident.value.should eq "b"
      right.args.should be_empty
    end

    it "parses method defs with external parameter names" do
      node = parse(<<-CR).should be_a LC::Def
        def write(to file : IO) : Nil
        end
        CR

      ident = node.name.should be_a LC::Ident
      ident.value.should eq "write"
      node.params.size.should eq 1

      param = node.params[0]
      ident = param.name.should be_a LC::Ident
      ident.value.should eq "to"

      ident = param.internal_name.should be_a LC::Ident
      ident.value.should eq "file"

      const = param.type.should be_a LC::Const
      const.value.should eq "IO"

      const = node.return_type.should be_a LC::Const
      const.value.should eq "Nil"
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
      node = parse(<<-CR).should be_a LC::Def
        def foo(x : T, y : U) forall T, U
        end
        CR

      ident = node.name.should be_a LC::Ident
      ident.value.should eq "foo"
      node.params.size.should eq 2

      param = node.params[0]
      ident = param.name.should be_a LC::Ident
      ident.value.should eq "x"

      const = param.type.should be_a LC::Const
      const.value.should eq "T"

      param = node.params[1]
      ident = param.name.should be_a LC::Ident
      ident.value.should eq "y"

      const = param.type.should be_a LC::Const
      const.value.should eq "U"
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
      mod = parse("abstract def read(slice : Bytes) : Int32").should be_a LC::TypeModifier
      mod.kind.abstract?.should be_true

      node = mod.expr.should be_a LC::Def
      ident = node.name.should be_a LC::Ident
      ident.value.should eq "read"
      node.params.size.should eq 1

      param = node.params[0]
      ident = param.name.should be_a LC::Ident
      ident.value.should eq "slice"

      const = param.type.should be_a LC::Const
      const.value.should eq "Bytes"

      const = node.return_type.should be_a LC::Const
      const.value.should eq "Int32"

      node.body.should be_empty
      node.abstract?.should be_true
    end

    it "parses private method defs" do
      mod = parse(<<-CR).should be_a LC::TypeModifier
        private def read_impl(slice : Bytes) : Int32
          does_something_cool
        end
        CR

      mod.kind.private?.should be_true

      node = mod.expr.should be_a LC::Def
      ident = node.name.should be_a LC::Ident
      ident.value.should eq "read_impl"
      node.params.size.should eq 1

      param = node.params[0]
      ident = param.name.should be_a LC::Ident
      ident.value.should eq "slice"

      const = param.type.should be_a LC::Const
      const.value.should eq "Bytes"

      const = node.return_type.should be_a LC::Const
      const.value.should eq "Int32"
      node.body.size.should eq 1

      call = node.body[0].should be_a LC::Call
      ident = call.receiver.should be_a LC::Ident
      ident.value.should eq "does_something_cool"
    end

    it "parses protected method defs" do
      mod = parse(<<-CR).should be_a LC::TypeModifier
        protected def does_something_cool : Nil
        end
        CR

      mod.kind.protected?.should be_true

      node = mod.expr.should be_a LC::Def
      ident = node.name.should be_a LC::Ident
      ident.value.should eq "does_something_cool"
      node.params.should be_empty

      const = node.return_type.should be_a LC::Const
      const.value.should eq "Nil"
      node.body.should be_empty
    end

    it "parses private abstract method defs" do
      mod = parse("private abstract def select_impl : Nil").should be_a LC::TypeModifier
      mod.kind.private?.should be_true

      mod = mod.expr.should be_a LC::TypeModifier
      mod.kind.abstract?.should be_true

      node = mod.expr.should be_a LC::Def
      ident = node.name.should be_a LC::Ident
      ident.value.should eq "select_impl"
      node.params.should be_empty

      const = node.return_type.should be_a LC::Const
      const.value.should eq "Nil"

      node.body.should be_empty
      node.abstract?.should be_true
    end

    it "parses protected abstract method defs" do
      mod = parse("protected abstract def execute : Bool").should be_a LC::TypeModifier
      mod.kind.protected?.should be_true

      mod = mod.expr.should be_a LC::TypeModifier
      mod.kind.abstract?.should be_true

      node = mod.expr.should be_a LC::Def
      ident = node.name.should be_a LC::Ident
      ident.value.should eq "execute"
      node.params.should be_empty

      const = node.return_type.should be_a LC::Const
      const.value.should eq "Bool"

      node.body.should be_empty
      node.abstract?.should be_true
    end

    it "errors on duplicate visibility keywords on method defs" do
      mod = parse("private private def foo; end").should be_a LC::TypeModifier
      mod.kind.private?.should be_true

      error = mod.expr.should be_a LC::Error
      error.message.should eq "cannot apply private to private"

      mod = error.target.should be_a LC::TypeModifier
      mod.kind.private?.should be_true

      node = mod.expr.should be_a LC::Def
      ident = node.name.should be_a LC::Ident
      ident.value.should eq "foo"

      mod = parse("protected protected def bar; end").should be_a LC::TypeModifier
      mod.kind.protected?.should be_true

      error = mod.expr.should be_a LC::Error
      error.message.should eq "cannot apply protected to protected"

      mod = error.target.should be_a LC::TypeModifier
      mod.kind.protected?.should be_true

      node = mod.expr.should be_a LC::Def
      ident = node.name.should be_a LC::Ident
      ident.value.should eq "bar"

      mod = parse("abstract abstract def baz").should be_a LC::TypeModifier
      mod.kind.abstract?.should be_true

      error = mod.expr.should be_a LC::Error
      error.message.should eq "cannot apply abstract to abstract"

      mod = error.target.should be_a LC::TypeModifier
      mod.kind.abstract?.should be_true

      node = mod.expr.should be_a LC::Def
      ident = node.name.should be_a LC::Ident
      ident.value.should eq "baz"
    end

    it "errors on private-protected keywords on method defs" do
      mod = parse("private protected def foo; end").should be_a LC::TypeModifier
      mod.kind.private?.should be_true

      error = mod.expr.should be_a LC::Error
      error.message.should eq "cannot apply private to protected"

      mod = error.target.should be_a LC::TypeModifier
      mod.kind.protected?.should be_true

      node = mod.expr.should be_a LC::Def
      ident = node.name.should be_a LC::Ident
      ident.value.should eq "foo"
    end
  end
end
