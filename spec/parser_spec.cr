require "./spec_helper"

describe Compiler::Parser do
  it "parses string expressions" do
    assert_node_sequence([Compiler::StringLiteral], %("hello world"))
  end

  it "parses number-integer expressions" do
    assert_node_sequence([Compiler::IntLiteral], %(123_45))
  end

  it "parses number-float expressions" do
    assert_node_sequence([Compiler::FloatLiteral], %(3.141_592))
  end

  it "parses nil expressions" do
    assert_node_sequence([Compiler::NilLiteral], %(nil))
  end

  it "parses assignment expressions" do
    assert_node_sequence([Compiler::Assign], %(x = 7))
  end

  it "parses variable declaration expresssions" do
    assert_node_sequence([Compiler::Var], %(x : Int32))
  end

  it "parses call expressions with single arguments" do
    assert_node_sequence([Compiler::Call], %(puts "hello world"))
  end

  it "parses call expressions with multiple arguments" do
    assert_node_sequence([Compiler::Call], %(puts "foo", "bar", "baz"))
  end
end
