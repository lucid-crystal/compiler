require "../spec_helper"

describe LC::Parser do
  context "requires" do
    it "parses require statements" do
      node = parse %q(require "json")
      node.should be_a LC::Require
      node = node.as(LC::Require)

      node.mod.should be_a LC::StringLiteral
      node.mod.as(LC::StringLiteral).value.should eq "json"
    end
  end
end
