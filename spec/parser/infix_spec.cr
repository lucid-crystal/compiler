require "../spec_helper"

describe LC::Parser do
  context "infix", tags: %w[parser infix] do
    it "parses infix operator expressions" do
      node = parse_expr "1 + 1"

      node.should be_a LC::Infix
      node = node.as(LC::Infix)

      node.left.should be_a LC::IntLiteral
      node.left.as(LC::IntLiteral).value.should eq 1

      node.op.should eq LC::Infix::Operator::Add
      node.right.should be_a LC::IntLiteral
      node.right.as(LC::IntLiteral).value.should eq 1

      node = parse_expr "false & true"

      node.should be_a LC::Infix
      node = node.as(LC::Infix)

      node.left.should be_a LC::BoolLiteral
      node.left.as(LC::BoolLiteral).value.should be_false

      node.op.should eq LC::Infix::Operator::BitAnd
      node.right.should be_a LC::BoolLiteral
      node.right.as(LC::BoolLiteral).value.should be_true
    end

    it "parses grouped infix operator expressions" do
      node = parse_expr "4 + (16 / 2)"

      node.should be_a LC::Infix
      node = node.as(LC::Infix)

      node.left.should be_a LC::IntLiteral
      node.left.as(LC::IntLiteral).value.should eq 4

      node.op.should eq LC::Infix::Operator::Add
      node.right.should be_a LC::Infix
      expr = node.right.as(LC::Infix)

      expr.left.should be_a LC::IntLiteral
      expr.left.as(LC::IntLiteral).value.should eq 16

      expr.op.should eq LC::Infix::Operator::Divide
      expr.right.should be_a LC::IntLiteral
      expr.right.as(LC::IntLiteral).value.should eq 2

      node = parse_expr "1 + (2 ** 3) - (20 // -4)"

      node.should be_a LC::Infix
      node = node.as(LC::Infix)

      node.left.should be_a LC::IntLiteral
      node.left.as(LC::IntLiteral).value.should eq 1

      node.op.should eq LC::Infix::Operator::Add
      node.right.should be_a LC::Infix
      node = node.right.as(LC::Infix)

      node.left.should be_a LC::Infix
      expr = node.left.as(LC::Infix)

      expr.left.should be_a LC::IntLiteral
      expr.left.as(LC::IntLiteral).value.should eq 2

      expr.op.should eq LC::Infix::Operator::Power
      expr.right.should be_a LC::IntLiteral
      expr.right.as(LC::IntLiteral).value.should eq 3

      node.op.should eq LC::Infix::Operator::Subtract
      node.right.should be_a LC::Infix
      expr = node.right.as(LC::Infix)

      expr.left.should be_a LC::IntLiteral
      expr.left.as(LC::IntLiteral).value.should eq 20

      expr.op.should eq LC::Infix::Operator::DivFloor
      expr.right.should be_a LC::Prefix
      expr = expr.right.as(LC::Prefix)

      expr.op.should eq LC::Prefix::Operator::Minus
      expr.value.should be_a LC::IntLiteral
      expr.value.as(LC::IntLiteral).value.should eq 4
    end

    it "parses multiple ungrouped infix operator expressions" do
      node = parse_expr "8 << 16 | 2 ^ 3"

      node.should be_a LC::Infix
      node = node.as(LC::Infix)

      node.left.should be_a LC::IntLiteral
      node.left.as(LC::IntLiteral).value.should eq 8

      node.op.should eq LC::Infix::Operator::ShiftLeft
      node.right.should be_a LC::Infix
      node = node.right.as(LC::Infix)

      node.left.should be_a LC::IntLiteral
      node.left.as(LC::IntLiteral).value.should eq 16

      node.op.should eq LC::Infix::Operator::BitOr
      node.right.should be_a LC::Infix
      node = node.right.as(LC::Infix)

      node.left.should be_a LC::IntLiteral
      node.left.as(LC::IntLiteral).value.should eq 2

      node.op.should eq LC::Infix::Operator::Xor
      node.right.should be_a LC::IntLiteral
      node.right.as(LC::IntLiteral).value.should eq 3
    end

    it "parses logic infix operator expressions" do
      node = parse_expr "foo || bar && baz"
      node.should be_a LC::Infix
      node = node.as(LC::Infix)

      node.left.should be_a LC::Call
      expr = node.left.as(LC::Call)

      expr.receiver.should be_a LC::Ident
      expr.receiver.as(LC::Ident).value.should eq "foo"

      node.op.should eq LC::Infix::Operator::Or
      node.right.should be_a LC::Infix
      node = node.right.as(LC::Infix)

      node.left.should be_a LC::Call
      expr = node.left.as(LC::Call)

      expr.receiver.should be_a LC::Ident
      expr.receiver.as(LC::Ident).value.should eq "bar"

      node.op.should eq LC::Infix::Operator::And
      node.right.should be_a LC::Call
      expr = node.right.as(LC::Call)

      expr.receiver.should be_a LC::Ident
      expr.receiver.as(LC::Ident).value.should eq "baz"
    end
  end
end
