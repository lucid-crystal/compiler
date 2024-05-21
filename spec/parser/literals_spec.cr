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

    it "parses boolean expressions" do
      assert_node LC::BoolLiteral, "true"
      assert_node LC::BoolLiteral, "false"
    end

    it "parses nil expressions" do
      assert_node LC::NilLiteral, "nil"
    end
  end
end
