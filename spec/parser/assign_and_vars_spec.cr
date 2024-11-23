require "../spec_helper"

describe LC::Parser do
  context "assign and vars", tags: %w[parser assign vars] do
    it "parses assignment expressions" do
      assign = parse("x = 7").should be_a LC::Assign
      target = assign.target.should be_a LC::Ident
      target.value.should eq "x"

      int = assign.value.should be_a LC::IntLiteral
      int.value.should eq 7
    end

    it "parses uninitialized variable declaration expressions" do
      var = parse("x : Int32").should be_a LC::Var

      name = var.name.should be_a LC::Ident
      name.value.should eq "x"
      var.uninitialized?.should be_true

      type = var.type.should be_a LC::Const
      type.value.should eq "Int32"

      var.value.should be_nil
    end

    it "parses initialized variable declaration expressions" do
      var = parse("y : Int32 = 123").should be_a LC::Var

      name = var.name.should be_a LC::Ident
      name.value.should eq "y"
      var.uninitialized?.should be_false

      type = var.type.should be_a LC::Const
      type.value.should eq "Int32"

      int = var.value.should be_a LC::IntLiteral
      int.value.should eq 123
    end
  end
end
