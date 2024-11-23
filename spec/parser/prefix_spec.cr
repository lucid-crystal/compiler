require "../spec_helper"

describe LC::Parser do
  context "prefixes", tags: %w[parser prefix] do
    it "parses prefix operator expressions" do
      prefix = parse("!true").should be_a LC::Prefix
      prefix.op.should eq LC::Prefix::Operator::Not

      bool = prefix.value.should be_a LC::BoolLiteral
      bool.value.should be_true
    end

    it "parses double prefix operator expressions" do
      prefix = parse("!!false").should be_a LC::Prefix
      prefix.op.should eq LC::Prefix::Operator::Not

      prefix = prefix.value.should be_a LC::Prefix
      prefix.op.should eq LC::Prefix::Operator::Not

      bool = prefix.value.should be_a LC::BoolLiteral
      bool.value.should be_false
    end

    it "parses prefix operator expressions in calls" do
      call = parse("puts !foo").should be_a LC::Call
      receiver = call.receiver.should be_a LC::Ident
      receiver.value.should eq "puts"
      call.args.size.should eq 1

      prefix = call.args[0].should be_a LC::Prefix
      prefix.op.should eq LC::Prefix::Operator::Not

      call = prefix.value.should be_a LC::Call
      ident = call.receiver.should be_a LC::Ident
      ident.value.should eq "foo"
    end

    it "disallows prefix operators with incorrect syntax" do
      expect_raises(Exception) do
        parse "puts ! foo"
      end
    end
  end
end
