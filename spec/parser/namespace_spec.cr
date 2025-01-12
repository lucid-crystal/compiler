require "../spec_helper"

describe LC::Parser do
  context "namespace", tags: %w[parser namespace] do
    it "parses valid include/extend expressions" do
      includer = parse("include Base").should be_a LC::Include
      includer.loc.to_tuple.should eq({0, 0, 0, 12})

      const = includer.type.should be_a LC::Const
      const.value.should eq "Base"

      extender = parse("extend self").should be_a LC::Extend
      extender.loc.to_tuple.should eq({0, 0, 0, 11})

      call = extender.type.should be_a LC::Call
      call.receiver.should be_a LC::Self
      call.args.should be_empty
    end

    it "parses invalid include/extend expressions" do
      includer = parse("include").should be_a LC::Include
      error = includer.type.should be_a LC::Error
      token = error.target.should be_a LC::Token

      token.kind.eof?.should be_true
      token.raw_value.should be_nil
      error.message.should eq "unexpected end of file"
    end

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

      mod.loc.to_tuple.should eq({0, 0, 3, 3})

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
          class Bar < Baz
            extend self

            def baz : Nil
            end
          end

          include Qux

          alias Qux = Bar
        end
        CR

      mod.loc.to_tuple.should eq({0, 0, 11, 3})

      const = mod.name.should be_a LC::Const
      const.value.should eq "Foo"
      mod.includes.size.should eq 1

      const = mod.includes[0].type.should be_a LC::Const
      const.value.should eq "Qux"
      mod.aliases.size.should eq 1

      aliased = mod.aliases[0].should be_a LC::Alias
      aliased.loc.to_tuple.should eq({10, 2, 10, 17})

      const = aliased.name.should be_a LC::Const
      const.value.should eq "Qux"

      const = aliased.type.should be_a LC::Const
      const.value.should eq "Bar"
      mod.types.size.should eq 1

      cls = mod.types[0].should be_a LC::ClassDef
      cls.loc.to_tuple.should eq({1, 2, 6, 5})

      const = cls.name.should be_a LC::Const
      const.value.should eq "Bar"

      const = cls.superclass.should be_a LC::Const
      const.value.should eq "Baz"
      cls.extends.size.should eq 1

      call = cls.extends[0].type.should be_a LC::Call
      call.receiver.should be_a LC::Self
      call.args.should be_empty
      cls.methods.size.should eq 1

      method = cls.methods[0]
      method.loc.to_tuple.should eq({4, 4, 5, 7})

      ident = method.name.should be_a LC::Ident
      ident.value.should eq "baz"

      const = method.return_type.should be_a LC::Const
      const.value.should eq "Nil"
      method.body.should be_empty
    end
  end
end
