require "../spec_helper"

describe LC::Parser do
  context "aliases" do
    it "parses alias statements" do
      type = parse("alias Bar = Foo").should be_a LC::Alias
      const = type.name.should be_a LC::Const
      const.value.should eq "Bar"

      const = type.type.should be_a LC::Const
      const.value.should eq "Foo"
    end

    it "parses invalid alias statements" do
      type = parse("alias foo = bar").should be_a LC::Alias
      error = type.name.should be_a LC::Error
      token = error.target.should be_a LC::Token

      token.kind.ident?.should be_true
      token.raw_value.should eq "foo"
      error.message.should eq "expected token 'const', not 'ident'"

      error = type.type.should be_a LC::Error
      token = error.target.should be_a LC::Token

      token.kind.ident?.should be_true
      token.raw_value.should eq "bar"
      error.message.should eq "expected token 'const', not 'ident'"

      type = parse("alias class = module").should be_a LC::Alias
      error = type.name.should be_a LC::Error
      token = error.target.should be_a LC::Token

      token.kind.class?.should be_true
      token.raw_value.should be_nil
      error.message.should eq "expected token 'const', not 'class'"

      error = type.type.should be_a LC::Error
      token = error.target.should be_a LC::Token

      token.kind.module?.should be_true
      token.raw_value.should be_nil
      error.message.should eq "expected token 'const', not 'module'"

      type = parse("alias =").should be_a LC::Alias
      error = type.name.should be_a LC::Error
      token = error.target.should be_a LC::Token

      token.kind.assign?.should be_true
      token.raw_value.should be_nil
      error.message.should eq "expected token 'const', not 'assign'"

      error = type.type.should be_a LC::Error
      token = error.target.should be_a LC::Token

      token.kind.eof?.should be_true
      token.raw_value.should be_nil
      error.message.should eq "unexpected end of file"

      type = parse("alias").should be_a LC::Alias
      error = type.name.should be_a LC::Error
      token = error.target.should be_a LC::Token

      token.kind.eof?.should be_true
      token.raw_value.should be_nil
      error.message.should eq "unexpected end of file"

      error = type.type.should be_a LC::Error
      token = error.target.should be_a LC::Token

      token.kind.eof?.should be_true
      token.raw_value.should be_nil
      error.message.should eq "unexpected end of file"
    end
  end
end
