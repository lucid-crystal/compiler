require "../spec_helper"

describe LC::Parser do
  context "requires" do
    it "parses require statements" do
      req = parse(%q(require "json")).should be_a LC::Require
      mod = req.mod.should be_a LC::StringLiteral
      mod.value.should eq "json"
    end
  end
end
