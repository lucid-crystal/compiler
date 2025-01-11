require "../spec_helper"

describe LC::Parser do
  context "requires" do
    it "parses require statements" do
      req = parse(%q(require "json")).should be_a LC::Require
      req.loc.to_tuple.should eq({0, 0, 0, 14})

      mod = req.mod.should be_a LC::StringLiteral
      mod.value.should eq "json"
    end

    it "parses invalid require statements" do
      req = parse("require class").should be_a LC::Require
      req.loc.to_tuple.should eq({0, 0, 0, 13})

      error = req.mod.should be_a LC::Error
      token = error.target.should be_a LC::Token

      token.kind.class?.should be_true
      token.raw_value.should be_nil
      error.message.should eq "require needs a string literal"
    end
  end
end
