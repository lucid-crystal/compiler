require "../spec_helper"

describe LC::Parser do
  context "prefixes", tags: %w[parser prefix] do
    it "parses prefix operator expressions" do
      prefix = parse("!true").should be_a LC::Prefix
      prefix.loc.to_tuple.should eq({0, 0, 0, 5})
      prefix.op.should eq LC::Prefix::Operator::Not

      bool = prefix.value.should be_a LC::BoolLiteral
      bool.value.should be_true
    end

    it "parses double prefix operator expressions" do
      prefix = parse("!!false").should be_a LC::Prefix
      prefix.loc.to_tuple.should eq({0, 0, 0, 7})
      prefix.op.should eq LC::Prefix::Operator::Not

      prefix = prefix.value.should be_a LC::Prefix
      prefix.op.should eq LC::Prefix::Operator::Not

      bool = prefix.value.should be_a LC::BoolLiteral
      bool.value.should be_false
    end

    it "parses prefix operator expressions in calls" do
      call = parse("puts !foo").should be_a LC::Call
      call.loc.to_tuple.should eq({0, 0, 0, 9})

      receiver = call.receiver.should be_a LC::Ident
      receiver.value.should eq "puts"
      call.args.size.should eq 1

      prefix = call.args[0].should be_a LC::Prefix
      prefix.op.should eq LC::Prefix::Operator::Not

      call = prefix.value.should be_a LC::Call
      ident = call.receiver.should be_a LC::Ident
      ident.value.should eq "foo"
    end

    it "parses prefix operators with incorrect syntax as errors" do
      error = parse("puts ! foo").should be_a LC::Error
      error.loc.to_tuple.should eq({0, 0, 0, 10})

      infix = error.target.should be_a LC::Infix
      left = infix.left.should be_a LC::Call
      ident = left.receiver.should be_a LC::Ident

      ident.value.should eq "puts"
      infix.op.invalid?.should be_true
      right = infix.right.should be_a LC::Call
      ident = right.receiver.should be_a LC::Ident

      ident.value.should eq "foo"
      error.message.should eq "invalid infix operator 'Bang'"
    end
  end
end
