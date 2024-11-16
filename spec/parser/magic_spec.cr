require "../spec_helper"

describe LC::Parser do
  context "magic vars" do
    it "parses magic line expressions" do
      node = parse <<-EXPR


      a = __LINE__
      EXPR

      node.should be_a LC::Assign
      node = node.as(LC::Assign)

      node.value.should be_a LC::IntLiteral
      node.value.as(LC::IntLiteral).value.should eq 3
    end

    it "parses magic file expressions" do
      node = parse <<-EXPR, file: "my_file.cr"
      a = __FILE__
      EXPR

      node.should be_a LC::Assign
      node = node.as(LC::Assign)

      node.value.should be_a LC::StringLiteral
      node.value.as(LC::StringLiteral).value.should eq "my_file.cr"
    end

    it "parses magic dir expressions" do
      node = parse <<-EXPR, dir: "my_dir"
      a = __DIR__
      EXPR

      node.should be_a LC::Assign
      node = node.as(LC::Assign)

      node.value.should be_a LC::StringLiteral
      node.value.as(LC::StringLiteral).value.should eq "my_dir"
    end

    pending "parses magic endline expressions" do
      parse <<-EXPR
        def my_func(a = __END_LINE__)
        end
        EXPR
    end

    pending "fails to parse endline not as a default param value" do
      parse <<-EXPR
        a = __END_LINE__
        EXPR
    end
  end
end
