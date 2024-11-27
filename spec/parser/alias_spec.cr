require "../spec_helper"

describe LC::Parser do
  # TODO: this definitely requires more vigorous testing
  context "aliases" do
    it "parses alias statements" do
      type = parse("alias Bar = Foo").should be_a LC::Alias
      const = type.name.should be_a LC::Const
      const.value.should eq "Bar"

      const = type.type.should be_a LC::Const
      const.value.should eq "Foo"
    end
  end
end
