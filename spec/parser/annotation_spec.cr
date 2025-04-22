require "../spec_helper"

describe LC::Parser do
  context "annotations" do
    it "parses annotation statements" do
      anno = parse("annotation Foo end").should be_a LC::AnnotationDef
      anno.loc.to_tuple.should eq({0, 0, 0, 18})

      const = anno.name.should be_a LC::Const
      const.value.should eq "Foo"

      anno = parse("annotation Bar; end").should be_a LC::AnnotationDef
      anno.loc.to_tuple.should eq({0, 0, 0, 19})

      const = anno.name.should be_a LC::Const
      const.value.should eq "Bar"

      anno = parse(<<-CR).should be_a LC::AnnotationDef
        annotation Baz::Qux
        end
        CR

      anno.loc.to_tuple.should eq({0, 0, 1, 3})

      path = anno.name.should be_a LC::Path
      path.names.size.should eq 2

      const = path.names[0].should be_a LC::Const
      const.value.should eq "Baz"

      const = path.names[1].should be_a LC::Const
      const.value.should eq "Qux"
    end

    it "parses annotation statements ignoring comments" do
      anno = parse(<<-CR).should be_a LC::AnnotationDef
        annotation Field
          # in here some useful comments
          # about whatever this thing actually does
        end
        CR

      anno.loc.to_tuple.should eq({0, 0, 3, 3})

      const = anno.name.should be_a LC::Const
      const.value.should eq "Field"
    end

    it "parses annotation expressions" do
      anno = parse("@[Foo::Bar]").should be_a LC::Annotation
      anno.loc.to_tuple.should eq({0, 0, 0, 11})

      path = anno.call.should be_a LC::Path
      path.names.size.should eq 2

      const = path.names[0].should be_a LC::Const
      const.value.should eq "Foo"

      const = path.names[1].should be_a LC::Const
      const.value.should eq "Bar"
    end
  end
end
