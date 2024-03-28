require "./spec_helper"

describe Lucid::Compiler::Parser do
  it "parses string expressions" do
    assert_node Lucid::Compiler::StringLiteral, %("hello world")
  end

  it "parses number-integer expressions" do
    assert_node Lucid::Compiler::IntLiteral, "123_45"
  end

  it "parses number-float expressions" do
    assert_node Lucid::Compiler::FloatLiteral, "3.141_592"
  end

  it "parses nil expressions" do
    assert_node Lucid::Compiler::NilLiteral, "nil"
  end

  it "parses assignment expressions" do
    node = parse("x = 7")[0]
    node.should be_a Lucid::Compiler::Assign
    node = node.as(Lucid::Compiler::Assign)

    node.name.should eq "x"
    node.value.should be_a Lucid::Compiler::IntLiteral
    node.value.as(Lucid::Compiler::IntLiteral).value.should eq 7
  end

  it "parses variable declaration expresssions" do
    node = parse("x : Int32")[0]
    node.should be_a Lucid::Compiler::Var
    node = node.as(Lucid::Compiler::Var)

    node.name.should eq "x"      # TODO: transform into Lucid::Compiler::Path
    node.type.should be_a String # TODO: transform into Lucid::Compiler::Path
    node.type.should eq "Int32"
    node.value.should be_nil
    node.uninitialized?.should be_true
  end

  it "parses call expressions with single arguments" do
    node = parse(%(puts "hello world"))[0]
    node.should be_a Lucid::Compiler::Call
    node = node.as(Lucid::Compiler::Call)

    node.name.should eq "puts"
    node.args.size.should eq 1
    node.args[0].should be_a Lucid::Compiler::StringLiteral
    node.args[0].as(Lucid::Compiler::StringLiteral).value.should eq "hello world"
  end

  it "parses call expressions with multiple arguments" do
    node = parse(%(puts "foo", "bar", "baz"))[0]
    node.should be_a Lucid::Compiler::Call
    node = node.as(Lucid::Compiler::Call)

    node.name.should eq "puts" # TODO: transform into Lucid::Compiler::Ident
    node.args.size.should eq 3
    node.args[0].should be_a Lucid::Compiler::StringLiteral
    node.args[0].as(Lucid::Compiler::StringLiteral).value.should eq "foo"

    node.args[1].should be_a Lucid::Compiler::StringLiteral
    node.args[1].as(Lucid::Compiler::StringLiteral).value.should eq "bar"

    node.args[2].should be_a Lucid::Compiler::StringLiteral
    node.args[2].as(Lucid::Compiler::StringLiteral).value.should eq "baz"
  end
end
