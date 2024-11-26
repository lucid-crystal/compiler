require "../spec_helper"

describe LC::Parser do
  context "infix", tags: %w[parser infix] do
    it "parses infix operator expressions" do
      infix = parse("1 + 1").should be_a LC::Infix
      left = infix.left.should be_a LC::IntLiteral
      left.value.should eq 1
      infix.op.should eq LC::Infix::Operator::Add

      right = infix.right.should be_a LC::IntLiteral
      right.value.should eq 1

      infix = parse("false & true").should be_a LC::Infix
      left = infix.left.should be_a LC::BoolLiteral
      left.value.should be_false
      infix.op.should eq LC::Infix::Operator::BitAnd

      right = infix.right.should be_a LC::BoolLiteral
      right.value.should be_true
    end

    it "parses grouped infix operator expressions" do
      node = parse("4 + (16 / 2)").should be_a LC::Infix
      int = node.left.should be_a LC::IntLiteral
      int.value.should eq 4

      node.op.should eq LC::Infix::Operator::Add
      expr = node.right.should be_a LC::Infix

      int = expr.left.should be_a LC::IntLiteral
      int.value.should eq 16

      expr.op.should eq LC::Infix::Operator::Divide
      int = expr.right.should be_a LC::IntLiteral
      int.value.should eq 2

      node = parse("1 + (2 ** 3) - (20 // -4)").should be_a LC::Infix
      int = node.left.should be_a LC::IntLiteral
      int.value.should eq 1

      node.op.should eq LC::Infix::Operator::Add
      node = node.right.should be_a LC::Infix

      expr = node.left.should be_a LC::Infix

      int = expr.left.should be_a LC::IntLiteral
      int.value.should eq 2

      expr.op.should eq LC::Infix::Operator::Power
      int = expr.right.should be_a LC::IntLiteral
      int.value.should eq 3

      node.op.should eq LC::Infix::Operator::Subtract
      expr = node.right.should be_a LC::Infix

      int = expr.left.should be_a LC::IntLiteral
      int.value.should eq 20

      expr.op.should eq LC::Infix::Operator::DivFloor
      expr = expr.right.should be_a LC::Prefix

      expr.op.should eq LC::Prefix::Operator::Minus
      int = expr.value.should be_a LC::IntLiteral
      int.value.should eq 4
    end

    it "parses multiple ungrouped infix operator expressions" do
      node = parse("8 << 16 | 2 ^ 3").should be_a LC::Infix
      int = node.left.should be_a LC::IntLiteral
      int.value.should eq 8

      node.op.should eq LC::Infix::Operator::ShiftLeft
      node = node.right.should be_a LC::Infix

      int = node.left.should be_a LC::IntLiteral
      int.value.should eq 16

      node.op.should eq LC::Infix::Operator::BitOr
      node = node.right.should be_a LC::Infix

      int = node.left.should be_a LC::IntLiteral
      int.value.should eq 2

      node.op.should eq LC::Infix::Operator::Xor
      int = node.right.should be_a LC::IntLiteral
      int.value.should eq 3
    end

    it "parses logic infix operator expressions" do
      node = parse("foo || bar && baz").should be_a LC::Infix
      expr = node.left.should be_a LC::Call
      ident = expr.receiver.should be_a LC::Ident
      ident.value.should eq "foo"
      node.op.should eq LC::Infix::Operator::Or

      node = node.right.should be_a LC::Infix
      expr = node.left.should be_a LC::Call
      ident = expr.receiver.should be_a LC::Ident
      ident.value.should eq "bar"
      node.op.should eq LC::Infix::Operator::And

      expr = node.right.should be_a LC::Call
      ident = expr.receiver.should be_a LC::Ident
      ident.value.should eq "baz"
    end
  end
end
