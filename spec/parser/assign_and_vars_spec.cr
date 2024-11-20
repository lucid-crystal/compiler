require "../spec_helper"

describe LC::Parser do
  context "assign and vars", tags: %w[parser assign vars] do
    it "parses assignment expressions" do
      node = parse("x = 7").should be_a LC::Assign
      target = node.target.should be_a LC::Ident
      target.value.should eq "x"

      value = node.value.should be_a LC::IntLiteral
      value.value.should eq 7
    end

    it "parses uninitialized variable declaration expressions" do
      node = parse("x : Int32").should be_a LC::Var

      name = node.name.should be_a LC::Ident
      name.value.should eq "x"
      node.uninitialized?.should be_true

      type = node.type.should be_a LC::Const
      type.value.should eq "Int32"

      node.value.should be_nil
    end

    it "parses initialized variable declaration expressions" do
      node = parse("y : Int32 = 123").should be_a LC::Var

      name = node.name.should be_a LC::Ident
      name.value.should eq "y"
      node.uninitialized?.should be_false

      type = node.type.should be_a LC::Const
      type.value.should eq "Int32"

      node.value.should be_a LC::IntLiteral
      node.value.as(LC::IntLiteral).value.should eq 123
    end
  end
end
