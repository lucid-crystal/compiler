require "../spec_helper"

describe LC::Parser do
  context "assign and vars", tags: %w[parser assign vars] do
    it "parses assignment expressions" do
      node = parse "x = 7"
      node.should be_a LC::Assign
      node = node.as(LC::Assign)

      node.target.should be_a LC::Ident
      node.target.as(LC::Ident).value.should eq "x"

      node.value.should be_a LC::IntLiteral
      node.value.as(LC::IntLiteral).value.should eq 7
    end

    it "parses uninitialized variable declaration expressions" do
      node = parse "x : Int32"
      node.should be_a LC::Var
      node = node.as(LC::Var)

      node.name.should be_a LC::Ident
      node.name.as(LC::Ident).value.should eq "x"
      node.uninitialized?.should be_true

      node.type.should be_a LC::Const
      node.type.as(LC::Const).value.should eq "Int32"

      node.value.should be_nil
    end

    it "parses initialized variable declaration expressions" do
      node = parse "y : Int32 = 123"
      node.should be_a LC::Var
      node = node.as(LC::Var)

      node.name.should be_a LC::Ident
      node.name.as(LC::Ident).value.should eq "y"
      node.uninitialized?.should be_false

      node.type.should be_a LC::Const
      node.type.as(LC::Const).value.should eq "Int32"

      node.value.should be_a LC::IntLiteral
      node.value.as(LC::IntLiteral).value.should eq 123
    end
  end
end
