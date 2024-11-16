require "../spec_helper"

describe LC::Parser do
  context "prefixes", tags: %w[parser prefix] do
    it "parses prefix operator expressions" do
      node = parse "!true"

      node.should be_a LC::Prefix
      node = node.as(LC::Prefix)

      node.op.should eq LC::Prefix::Operator::Not
      node.value.should be_a LC::BoolLiteral
      node.value.as(LC::BoolLiteral).value.should be_true
    end

    it "parses double prefix operator expressions" do
      node = parse "!!false"

      node.should be_a LC::Prefix
      node = node.as(LC::Prefix)

      node.op.should eq LC::Prefix::Operator::Not
      node.value.should be_a LC::Prefix
      value = node.value.as(LC::Prefix)

      value.op.should eq LC::Prefix::Operator::Not
      value.value.should be_a LC::BoolLiteral
      value.value.as(LC::BoolLiteral).value.should be_false
    end

    it "parses prefix operator expressions in calls" do
      node = parse "puts !foo"

      node.should be_a LC::Call
      node = node.as(LC::Call)

      node.receiver.should be_a LC::Ident
      node.receiver.as(LC::Ident).value.should eq "puts"

      node.args.size.should eq 1
      node.args[0].should be_a LC::Prefix
      arg = node.args[0].as(LC::Prefix)

      arg.op.should eq LC::Prefix::Operator::Not
      arg.value.should be_a LC::Call
      arg.value.as(LC::Call).receiver.should be_a LC::Ident
      arg.value.as(LC::Call).receiver.as(LC::Ident).value.should eq "foo"
    end

    it "disallows prefix operators with incorrect syntax" do
      expect_raises(Exception) do
        parse "puts ! foo"
      end
    end
  end
end
