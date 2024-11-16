require "../spec_helper"

describe LC::Parser do
  context "literals", tags: %w[parser literals] do
    it "parses string expressions" do
      assert_node LC::StringLiteral, %("hello world")
    end

    it "parses integer expressions" do
      assert_node LC::IntLiteral, "123_45"
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

    it "parses nil expressions" do
      assert_node LC::NilLiteral, "nil"
    end

    it "parses underscore expressions" do
      assert_node LC::Underscore, "_"
    end

    it "disallows calling underscore" do
      expect_raises(Exception, "underscore cannot be called as a method") do
        parse "_ foo"
      end
    end

    it "parses empty proc expressions" do
      {parse("-> { }"), parse("-> () { }")}.each do |node|
        node.should be_a LC::ProcLiteral
        node = node.as(LC::ProcLiteral)

        node.params.should be_empty
        node.body.should be_empty
      end
    end

    it "parses proc expressions with single arguments" do
      node = parse "-> (x : Int32) { }"
      node.should be_a LC::ProcLiteral
      node = node.as(LC::ProcLiteral)

      node.params.size.should eq 1
      param = node.params[0]

      param.name.should be_a LC::Ident
      param.name.as(LC::Ident).value.should eq "x"
      param.type.should be_a LC::Const
      param.type.as(LC::Const).value.should eq "Int32"

      node.body.should be_empty
    end

    it "parses proc expressions with multiple arguments" do
      node = parse "-> (a : Int32, b : Int32) { }"
      node.should be_a LC::ProcLiteral
      node = node.as(LC::ProcLiteral)

      node.params.size.should eq 2
      param = node.params[0]

      param.name.should be_a LC::Ident
      param.name.as(LC::Ident).value.should eq "a"
      param.type.should be_a LC::Const
      param.type.as(LC::Const).value.should eq "Int32"
      param = node.params[1]

      param.name.should be_a LC::Ident
      param.name.as(LC::Ident).value.should eq "b"
      param.type.should be_a LC::Const
      param.type.as(LC::Const).value.should eq "Int32"

      node.body.should be_empty
    end

    it "parses proc expressions with a body" do
      node = parse "-> do exit end"
      node.should be_a LC::ProcLiteral
      node = node.as(LC::ProcLiteral)

      node.params.should be_empty
      node.body.size.should eq 1
      expr = node.body[0]

      expr.should be_a LC::Call
      expr = expr.as(LC::Call)

      expr.receiver.should be_a LC::Ident
      expr.receiver.as(LC::Ident).value.should eq "exit"
      expr.args.should be_empty
    end

    it "parses multiline proc expressions" do
      node = parse <<-CR
        -> (
          a : Int32,
          b : Int32,
        )
        do
          a + b
        end
        CR

      node.should be_a LC::ProcLiteral
      node = node.as(LC::ProcLiteral)

      node.params.size.should eq 2
      param = node.params[0]

      param.name.should be_a LC::Ident
      param.name.as(LC::Ident).value.should eq "a"
      param.type.should be_a LC::Const
      param.type.as(LC::Const).value.should eq "Int32"
      param = node.params[1]

      param.name.should be_a LC::Ident
      param.name.as(LC::Ident).value.should eq "b"
      param.type.should be_a LC::Const
      param.type.as(LC::Const).value.should eq "Int32"

      node.body.size.should eq 1
      expr = node.body[0]

      expr.should be_a LC::Infix
      expr = expr.as(LC::Infix)

      expr.left.should be_a LC::Call
      node = expr.left.as(LC::Call)

      node.receiver.should be_a LC::Ident
      node.receiver.as(LC::Ident).value.should eq "a"

      expr.op.should eq LC::Infix::Operator::Add
      expr.right.should be_a LC::Call
      node = expr.right.as(LC::Call)

      node.receiver.should be_a LC::Ident
      node.receiver.as(LC::Ident).value.should eq "b"
    end
  end
end
