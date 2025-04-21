require "../spec_helper"

describe LC::Parser do
  context "literals", tags: %w[parser literals] do
    it "parses string expressions" do
      assert_node LC::StringLiteral, %("hello world")
    end

    it "parses integer expressions" do
      assert_node LC::IntLiteral, "123_45"
    end

    it "parses integer suffixes" do
      int = parse("1234").should be_a LC::IntLiteral
      int.base.dynamic?.should be_true

      int = parse("123_i8").should be_a LC::IntLiteral
      int.base.i8?.should be_true

      int = parse("123_u32").should be_a LC::IntLiteral
      int.base.u32?.should be_true

      int = parse("123_i128").should be_a LC::IntLiteral
      int.base.i128?.should be_true

      float = parse("123_f32").should be_a LC::FloatLiteral
      float.base.f32?.should be_true

      float = parse("123_f64").should be_a LC::FloatLiteral
      float.base.f64?.should be_true
    end

    it "parses float expressions" do
      assert_node LC::FloatLiteral, "3.141_592"
    end

    it "parses binary expressions" do
      assert_node LC::IntLiteral, "0b001001"
    end

    it "parses hex expressions" do
      assert_node LC::IntLiteral, "0xABCD"
      assert_node LC::IntLiteral, "0xABCDF32" # Hex are always ints
    end

    it "parses octal expressions" do
      assert_node LC::IntLiteral, "0o1234567"
    end

    it "parses boolean expressions" do
      assert_node LC::BoolLiteral, "true"
      assert_node LC::BoolLiteral, "false"
    end

    it "parses char expressions" do
      assert_node LC::CharLiteral, "'\\0'"
      assert_node LC::CharLiteral, "'9'"
      assert_node LC::CharLiteral, "'@'"
      assert_node LC::CharLiteral, "'Á'"
      assert_node LC::CharLiteral, "'ǅ'"
    end

    it "parses symbol expressions" do
      assert_node LC::SymbolLiteral, ":a"
      assert_node LC::SymbolLiteral, ":i0"
      assert_node LC::SymbolLiteral, ":foo?"
      assert_node LC::SymbolLiteral, ":bar!"
      assert_node LC::SymbolLiteral, %(:"foo bar")

      %i[! != !~ % & &* &** &+ &- * ** + - / // < <= <=> == === =~ ^ | ~].each do |op|
        assert_node LC::SymbolLiteral, op.inspect
      end
    end

    it "parses symbol key expressions" do
      assert_node LC::SymbolKey, "foo:"
      assert_node LC::SymbolKey, %("foo bar":)
    end

    it "parses nil expressions" do
      assert_node LC::NilLiteral, "nil"
    end

    it "parses underscore expressions" do
      assert_node LC::Underscore, "_"
    end

    it "errors on calling underscore" do
      call = parse("_ foo").should be_a LC::Call
      call.loc.to_tuple.should eq({0, 0, 0, 5})

      error = call.receiver.should be_a LC::Error
      error.target.should be_a LC::Underscore
      error.message.should eq "underscore cannot be called as a method"
      call.args.size.should eq 1

      call = call.args[0].should be_a LC::Call
      ident = call.receiver.should be_a LC::Ident
      ident.value.should eq "foo"
    end

    it "parses empty proc expressions" do
      proc = parse("-> { }").should be_a LC::ProcLiteral
      proc.loc.to_tuple.should eq({0, 0, 0, 6})
      proc.params.should be_empty
      proc.body.should be_empty

      proc = parse("-> () { }").should be_a LC::ProcLiteral
      proc.loc.to_tuple.should eq({0, 0, 0, 9})
      proc.params.should be_empty
      proc.body.should be_empty
    end

    it "parses proc expressions with single arguments" do
      proc = parse("-> (x : Int32) { }").should be_a LC::ProcLiteral
      proc.loc.to_tuple.should eq({0, 0, 0, 18})
      proc.params.size.should eq 1

      param = proc.params[0]
      ident = param.name.should be_a LC::Ident
      ident.value.should eq "x"

      const = param.type.should be_a LC::Const
      const.value.should eq "Int32"
      proc.body.should be_empty
    end

    it "parses proc expressions with multiple arguments" do
      proc = parse("-> (a : Int32, b : Int32) { }").should be_a LC::ProcLiteral
      proc.loc.to_tuple.should eq({0, 0, 0, 29})
      proc.params.size.should eq 2

      param = proc.params[0]
      ident = param.name.should be_a LC::Ident
      ident.value.should eq "a"

      const = param.type.should be_a LC::Const
      const.value.should eq "Int32"

      param = proc.params[1]
      ident = param.name.should be_a LC::Ident
      ident.value.should eq "b"

      const = param.type.should be_a LC::Const
      const.value.should eq "Int32"
      proc.body.should be_empty
    end

    it "parses proc expressions with a body" do
      proc = parse("-> do exit end").should be_a LC::ProcLiteral
      proc.loc.to_tuple.should eq({0, 0, 0, 14})
      proc.params.should be_empty
      proc.body.size.should eq 1

      expr = proc.body[0].should be_a LC::Call
      ident = expr.receiver.should be_a LC::Ident
      ident.value.should eq "exit"
      expr.args.should be_empty
    end

    it "parses multiline proc expressions" do
      proc = parse(<<-CR).should be_a LC::ProcLiteral
        -> (
          a : Int32,
          b : Int32,
        )
        do
          a + b
        end
        CR

      proc.loc.to_tuple.should eq({0, 0, 6, 3})
      proc.params.size.should eq 2

      param = proc.params[0]
      ident = param.name.should be_a LC::Ident
      ident.value.should eq "a"

      const = param.type.should be_a LC::Const
      const.value.should eq "Int32"

      param = proc.params[1]
      ident = param.name.should be_a LC::Ident
      ident.value.should eq "b"

      const = param.type.should be_a LC::Const
      const.value.should eq "Int32"
      proc.body.size.should eq 1

      expr = proc.body[0].should be_a LC::Infix
      left = expr.left.should be_a LC::Call
      ident = left.receiver.should be_a LC::Ident
      ident.value.should eq "a"
      expr.op.should eq LC::Infix::Operator::Add

      node = expr.right.should be_a LC::Call
      ident = node.receiver.should be_a LC::Ident
      ident.value.should eq "b"
    end
  end
end
