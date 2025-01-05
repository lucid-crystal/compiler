require "../spec_helper"

describe LC::Parser do
  context "namespace", tags: %w[parser namespace] do
    it "parses module defs" do
      {"module Foo\nend", "module Foo; end", "module Foo end"}.each do |code|
        mod = parse(code).should be_a LC::ModuleDef
        const = mod.name.should be_a LC::Const
        const.value.should eq "Foo"
      end
    end

    it "parses nested module defs" do
      mod = parse(<<-CR).should be_a LC::ModuleDef
        module Foo
          module Bar
          end
        end
        CR

      const = mod.name.should be_a LC::Const
      const.value.should eq "Foo"
      mod.types.size.should eq 1

      mod = mod.types[0].should be_a LC::ModuleDef
      const = mod.name.should be_a LC::Const
      const.value.should eq "Bar"
    end

    it "parses types inside namespaces" do
      mod = parse(<<-CR).should be_a LC::ModuleDef
        module Foo
          module Bar
            def baz : Nil
            end
          end

          alias Qux = Bar
        end
        CR

      const = mod.name.should be_a LC::Const
      const.value.should eq "Foo"
      mod.aliases.size.should eq 1

      aliased = mod.aliases[0].should be_a LC::Alias
      const = aliased.name.should be_a LC::Const
      const.value.should eq "Qux"

      const = aliased.type.should be_a LC::Const
      const.value.should eq "Bar"
      mod.types.size.should eq 1

      mod = mod.types[0].should be_a LC::ModuleDef
      const = mod.name.should be_a LC::Const
      const.value.should eq "Bar"
      mod.methods.size.should eq 1

      method = mod.methods[0]
      ident = method.name.should be_a LC::Ident
      ident.value.should eq "baz"

      const = method.return_type.should be_a LC::Const
      const.value.should eq "Nil"
      method.body.should be_empty
    end
  end
end
