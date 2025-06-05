require "../spec_helper"

describe LC::Parser do
  context "literals", tags: %w[parser literals] do
    it "parses string expressions" do
      assert_node LC::StringLiteral, %("hello world")

      expect_raises(Exception, "unterminated string literal") do
        assert_node LC::RegexLiteral, %("foo)
      end
    end

    it "parses regex expressions" do
      assert_node LC::RegexLiteral, "/foo bar/"
      assert_node LC::RegexLiteral, "%r(foo bar)"

      expect_raises(Exception, "unterminated regular expression") do
        assert_node LC::RegexLiteral, "/bar"
      end
    end
    it "parses interpolated string expressions" do
      lit = parse(%q("foo #{bar}")).should be_a LC::StringInterpolation
      lit.loc.to_tuple.should eq({0, 0, 0, 12})
      lit.parts.size.should eq 3

      str = lit.parts[0].should be_a LC::StringLiteral
      str.value.should eq "foo "

      call = lit.parts[1].should be_a LC::Call
      ident = call.receiver.should be_a LC::Ident
      ident.value.should eq "bar"

      str = lit.parts[2].should be_a LC::StringLiteral
      str.value.should be_empty

      lit = parse(%q("foo #{bar} baz #{qux} quack")).should be_a LC::StringInterpolation
      lit.loc.to_tuple.should eq({0, 0, 0, 29})
      lit.parts.size.should eq 5

      str = lit.parts[0].should be_a LC::StringLiteral
      str.value.should eq "foo "

      call = lit.parts[1].should be_a LC::Call
      ident = call.receiver.should be_a LC::Ident
      ident.value.should eq "bar"

      str = lit.parts[2].should be_a LC::StringLiteral
      str.value.should eq " baz "

      call = lit.parts[3].should be_a LC::Call
      ident = call.receiver.should be_a LC::Ident
      ident.value.should eq "qux"

      str = lit.parts[4].should be_a LC::StringLiteral
      str.value.should eq " quack"
    end

    it "parses nested interpolated string expressions" do
      lit = parse(%q("foo #{"bar #{baz}"} qux")).should be_a LC::StringInterpolation
      lit.loc.to_tuple.should eq({0, 0, 0, 25})
      lit.parts.size.should eq 3

      str = lit.parts[0].should be_a LC::StringLiteral
      str.value.should eq "foo "

      inner = lit.parts[1].should be_a LC::StringInterpolation
      inner.loc.to_tuple.should eq({0, 7, 0, 19})
      inner.parts.size.should eq 3

      str = inner.parts[0].should be_a LC::StringLiteral
      str.value.should eq "bar "

      call = inner.parts[1].should be_a LC::Call
      ident = call.receiver.should be_a LC::Ident
      ident.value.should eq "baz"

      str = inner.parts[2].should be_a LC::StringLiteral
      str.value.should be_empty

      str = lit.parts[2].should be_a LC::StringLiteral
      str.value.should eq " qux"
    end

    it "parses command literals" do
      call = parse("`foo bar`").should be_a LC::Call
      call.loc.to_tuple.should eq({0, 0, 0, 9})

      ident = call.receiver.should be_a LC::Ident
      ident.loc.to_tuple.should eq({0, 0, 0, 9})
      ident.value.should eq "`"
      call.args.size.should eq 1

      str = call.args[0].should be_a LC::StringLiteral
      str.value.should eq "foo bar"

      call = parse(%q[%x(foo #{bar})]).should be_a LC::Call
      call.loc.to_tuple.should eq({0, 0, 0, 14})

      ident = call.receiver.should be_a LC::Ident
      ident.loc.to_tuple.should eq({0, 0, 0, 14})
      ident.value.should eq "`"
      call.args.size.should eq 1

      lit = call.args[0].should be_a LC::StringInterpolation
      lit.loc.to_tuple.should eq({0, 0, 0, 14})
      lit.parts.size.should eq 3

      str = lit.parts[0].should be_a LC::StringLiteral
      str.value.should eq "foo "

      call = lit.parts[1].should be_a LC::Call
      ident = call.receiver.should be_a LC::Ident
      ident.value.should eq "bar"

      str = lit.parts[2].should be_a LC::StringLiteral
      str.value.should eq ""
    end

    it "parses heredocs" do
      lit = parse(<<-CR).should be_a LC::StringInterpolation
        <<-FOO
          bar
          baz
          FOO
        CR

      lit.parts.size.should eq 1
      str = lit.parts[0].should be_a LC::StringLiteral
      str.value.should eq "bar\nbaz"

      lit = parse(<<-CR).should be_a LC::StringInterpolation
        <<-oof
          foo
          oof
        CR

      lit.parts.size.should eq 1
      str = lit.parts[0].should be_a LC::StringLiteral
      str.value.should eq "foo"

      # lit = parse(<<-'CR').should be_a LC::StringInterpolation
      #   <<-BAR
      #     #{foo}
      #     BAR
      #   CR

      # lit.parts.should eq 3
      # str = lit.parts[0].should be_a LC::StringLiteral
      # str.value.should be_empty

      # ident = lit.parts[1].should be_a LC::Ident
      # ident.value.should eq "foo"

      # str = lit.parts[2].should be_a LC::StringLiteral
      # str.value.should be_empty
    end

    it "parses integer expressions" do
      assert_node LC::IntLiteral, "123_45"
    end

    it "parses integer suffixes" do
      int = parse("1234").should be_a LC::IntLiteral
      int.base.dynamic?.should be_true

      int = parse("123_i8").should be_a LC::IntLiteral
      int.base.i8?.should be_true

      int = parse("123_u32").should be_a LC::IntLiteral
      int.base.u32?.should be_true

      int = parse("123_i128").should be_a LC::IntLiteral
      int.base.i128?.should be_true

      float = parse("123_f32").should be_a LC::FloatLiteral
      float.base.f32?.should be_true

      float = parse("123_f64").should be_a LC::FloatLiteral
      float.base.f64?.should be_true
    end

    it "parses float expressions" do
      assert_node LC::FloatLiteral, "3.141_592"
    end

    it "parses binary expressions" do
      assert_node LC::IntLiteral, "0b001001"
    end

    it "parses hex expressions" do
      assert_node LC::IntLiteral, "0xABCD"
      assert_node LC::IntLiteral, "0xABCDF32" # Hex are always ints
    end

    it "parses octal expressions" do
      assert_node LC::IntLiteral, "0o1234567"
    end

    it "parses boolean expressions" do
      assert_node LC::BoolLiteral, "true"
      assert_node LC::BoolLiteral, "false"
    end

    it "parses char expressions" do
      assert_node LC::CharLiteral, "'\\0'"
      assert_node LC::CharLiteral, "'9'"
      assert_node LC::CharLiteral, "'@'"
      assert_node LC::CharLiteral, "'Á'"
      assert_node LC::CharLiteral, "'ǅ'"
    end

    it "parses symbol expressions" do
      assert_node LC::SymbolLiteral, ":a"
      assert_node LC::SymbolLiteral, ":i0"
      assert_node LC::SymbolLiteral, ":foo?"
      assert_node LC::SymbolLiteral, ":bar!"
      assert_node LC::SymbolLiteral, %(:"foo bar")

      %i[! != !~ % & &* &** &+ &- * ** + - / // < <= <=> == === =~ ^ | ~].each do |op|
        assert_node LC::SymbolLiteral, op.inspect
      end
    end

    it "parses array literal expressions" do
      arr = parse("[1, 2]").should be_a LC::ArrayLiteral
      arr.loc.to_tuple.should eq({0, 0, 0, 6})
      arr.of_type.should be_nil
      arr.percent_literal?.should be_false
      arr.values.size.should eq 2

      int = arr.values[0].should be_a LC::IntLiteral
      int.value.should eq 1

      int = arr.values[1].should be_a LC::IntLiteral
      int.value.should eq 2

      arr = parse("[] of Nil").should be_a LC::ArrayLiteral
      arr.loc.to_tuple.should eq({0, 0, 0, 9})
      arr.values.should be_empty
      arr.percent_literal?.should be_false

      const = arr.of_type.should be_a LC::Const
      const.value.should eq "Nil"
    end

    it "parses nested array literal expressions" do
      arr = parse("[[1, 2], 3]").should be_a LC::ArrayLiteral
      arr.loc.to_tuple.should eq({0, 0, 0, 11})
      arr.percent_literal?.should be_false
      arr.of_type.should be_nil
      arr.values.size.should eq 2

      inner = arr.values[0].should be_a LC::ArrayLiteral
      inner.loc.to_tuple.should eq({0, 1, 0, 7})
      inner.percent_literal?.should be_false
      inner.of_type.should be_nil
      inner.values.size.should eq 2

      int = inner.values[0].should be_a LC::IntLiteral
      int.value.should eq 1

      int = inner.values[1].should be_a LC::IntLiteral
      int.value.should eq 2

      int = arr.values[1].should be_a LC::IntLiteral
      int.value.should eq 3
    end

    it "errors on invalid array literals" do
      error = parse("[1, 2").should be_a LC::Error
      error.message.should eq "missing closing bracket for array literal"

      arr = error.target.should be_a LC::ArrayLiteral
      arr.percent_literal?.should be_false
      arr.of_type.should be_nil
      arr.values.size.should eq 2

      int = arr.values[0].should be_a LC::IntLiteral
      int.value.should eq 1

      int = arr.values[1].should be_a LC::IntLiteral
      int.value.should eq 2

      error = parse("[]").should be_a LC::Error
      error.message.should eq "an empty array literal must have an explicit type"

      arr = error.target.should be_a LC::ArrayLiteral
      arr.percent_literal?.should be_false
      arr.of_type.should be_nil
      arr.values.should be_empty
    end

    it "parses tuple literal expressions" do
      tuple = parse("{foo}").should be_a LC::TupleLiteral
      tuple.loc.to_tuple.should eq({0, 0, 0, 5})
      tuple.types.should be_empty
      tuple.values.size.should eq 1

      call = tuple.values[0].should be_a LC::Call
      call.loc.to_tuple.should eq({0, 1, 0, 4})

      ident = call.receiver.should be_a LC::Ident
      ident.value.should eq "foo"

      tuple = parse(%[{"foo", "bar"}]).should be_a LC::TupleLiteral
      tuple.loc.to_tuple.should eq({0, 0, 0, 14})
      tuple.types.should be_empty
      tuple.values.size.should eq 2

      str = tuple.values[0].should be_a LC::StringLiteral
      str.value.should eq "foo"

      str = tuple.values[1].should be_a LC::StringLiteral
      str.value.should eq "bar"
    end

    it "errors on invalid tuple literals" do
      error = parse("{foo,").should be_a LC::Error
      error.message.should eq "missing closing brace for tuple literal"

      tuple = error.target.should be_a LC::TupleLiteral
      tuple.types.should be_empty
      tuple.values.size.should eq 1

      call = tuple.values[0].should be_a LC::Call
      ident = call.receiver.should be_a LC::Ident
      ident.value.should eq "foo"
    end

    it "parses hash literal expressions" do
      hash = parse(%({"foo" => "bar"})).should be_a LC::HashLiteral
      hash.loc.to_tuple.should eq({0, 0, 0, 16})
      hash.of_type.should be_nil
      hash.entries.size.should eq 1

      entry = hash.entries[0].should be_a LC::HashLiteral::Entry
      entry.loc.to_tuple.should eq({0, 1, 0, 15})

      str = entry.key.should be_a LC::StringLiteral
      str.value.should eq "foo"

      str = entry.value.should be_a LC::StringLiteral
      str.value.should eq "bar"

      hash = parse(%({1 => "one", 2 => "two"})).should be_a LC::HashLiteral
      hash.loc.to_tuple.should eq({0, 0, 0, 24})
      hash.of_type.should be_nil
      hash.entries.size.should eq 2

      entry = hash.entries[0].should be_a LC::HashLiteral::Entry
      entry.loc.to_tuple.should eq({0, 1, 0, 11})

      int = entry.key.should be_a LC::IntLiteral
      int.value.should eq 1

      str = entry.value.should be_a LC::StringLiteral
      str.value.should eq "one"

      entry = hash.entries[1].should be_a LC::HashLiteral::Entry
      entry.loc.to_tuple.should eq({0, 13, 0, 23})

      int = entry.key.should be_a LC::IntLiteral
      int.value.should eq 2

      str = entry.value.should be_a LC::StringLiteral
      str.value.should eq "two"

      hash = parse(%({true => false} of Bool => Bool)).should be_a LC::HashLiteral
      hash.loc.to_tuple.should eq({0, 0, 0, 31})
      hash.entries.size.should eq 1

      entry = hash.entries[0].should be_a LC::HashLiteral::Entry
      entry.loc.to_tuple.should eq({0, 1, 0, 14})

      str = entry.key.should be_a LC::BoolLiteral
      str.value.should be_true

      str = entry.value.should be_a LC::BoolLiteral
      str.value.should be_false

      entry = hash.of_type.should be_a LC::HashLiteral::Entry
      entry.loc.to_tuple.should eq({0, 19, 0, 31})

      const = entry.key.should be_a LC::Const
      const.value.should eq "Bool"

      const = entry.value.should be_a LC::Const
      const.value.should eq "Bool"

      hash = parse("{} of Int32 => String").should be_a LC::HashLiteral
      hash.loc.to_tuple.should eq({0, 0, 0, 21})
      hash.entries.should be_empty

      entry = hash.of_type.should be_a LC::HashLiteral::Entry
      entry.loc.to_tuple.should eq({0, 6, 0, 21})

      const = entry.key.should be_a LC::Const
      const.value.should eq "Int32"

      const = entry.value.should be_a LC::Const
      const.value.should eq "String"
    end

    it "parses string/symbol array percent literals" do
      arr = parse("%w(foo bar)").should be_a LC::ArrayLiteral
      arr.loc.to_tuple.should eq({0, 0, 0, 11})
      arr.percent_literal?.should be_true
      arr.values.size.should eq 2

      str = arr.values[0].should be_a LC::StringLiteral
      str.loc.to_tuple.should eq({0, 0, 0, 11})
      str.value.should eq "foo"

      str = arr.values[1].should be_a LC::StringLiteral
      str.loc.to_tuple.should eq({0, 0, 0, 11})
      str.value.should eq "bar"

      const = arr.of_type.should be_a LC::Const
      const.loc.to_tuple.should eq({0, 0, 0, 11})
      const.value.should eq "String"
      const.global?.should be_true

      arr = parse("%i<baz qux>").should be_a LC::ArrayLiteral
      arr.loc.to_tuple.should eq({0, 0, 0, 11})
      arr.percent_literal?.should be_true
      arr.values.size.should eq 2

      str = arr.values[0].should be_a LC::SymbolLiteral
      str.loc.to_tuple.should eq({0, 0, 0, 11})
      str.value.should eq "baz"

      str = arr.values[1].should be_a LC::SymbolLiteral
      str.loc.to_tuple.should eq({0, 0, 0, 11})
      str.value.should eq "qux"

      const = arr.of_type.should be_a LC::Const
      const.loc.to_tuple.should eq({0, 0, 0, 11})
      const.value.should eq "Symbol"
      const.global?.should be_true

      arr = parse(%q[%i{~ <> \ }]).should be_a LC::ArrayLiteral
      arr.loc.to_tuple.should eq({0, 0, 0, 11})
      arr.percent_literal?.should be_true
      arr.values.size.should eq 3

      str = arr.values[0].should be_a LC::SymbolLiteral
      str.loc.to_tuple.should eq({0, 0, 0, 11})
      str.value.should eq "~"

      str = arr.values[1].should be_a LC::SymbolLiteral
      str.loc.to_tuple.should eq({0, 0, 0, 11})
      str.value.should eq "<>"

      str = arr.values[2].should be_a LC::SymbolLiteral
      str.loc.to_tuple.should eq({0, 0, 0, 11})
      str.value.should eq " "

      const = arr.of_type.should be_a LC::Const
      const.loc.to_tuple.should eq({0, 0, 0, 11})
      const.value.should eq "Symbol"
      const.global?.should be_true
    end

    it "parses symbol key expressions" do
      assert_node LC::SymbolKey, "foo:"
      assert_node LC::SymbolKey, %("foo bar":)
    end

    it "parses nil expressions" do
      assert_node LC::NilLiteral, "nil"
    end

    it "parses underscore expressions" do
      assert_node LC::Underscore, "_"
    end

    it "errors on calling underscore" do
      call = parse("_ foo").should be_a LC::Call
      call.loc.to_tuple.should eq({0, 0, 0, 5})

      error = call.receiver.should be_a LC::Error
      error.target.should be_a LC::Underscore
      error.message.should eq "underscore cannot be called as a method"
      call.args.size.should eq 1

      call = call.args[0].should be_a LC::Call
      ident = call.receiver.should be_a LC::Ident
      ident.value.should eq "foo"
    end

    it "parses empty proc expressions" do
      proc = parse("-> { }").should be_a LC::ProcLiteral
      proc.loc.to_tuple.should eq({0, 0, 0, 6})
      proc.params.should be_empty
      proc.body.should be_empty

      proc = parse("-> () { }").should be_a LC::ProcLiteral
      proc.loc.to_tuple.should eq({0, 0, 0, 9})
      proc.params.should be_empty
      proc.body.should be_empty
    end

    it "parses proc expressions with single arguments" do
      proc = parse("-> (x : Int32) { }").should be_a LC::ProcLiteral
      proc.loc.to_tuple.should eq({0, 0, 0, 18})
      proc.params.size.should eq 1

      param = proc.params[0]
      ident = param.name.should be_a LC::Ident
      ident.value.should eq "x"

      const = param.type.should be_a LC::Const
      const.value.should eq "Int32"
      proc.body.should be_empty
    end

    it "parses proc expressions with multiple arguments" do
      proc = parse("-> (a : Int32, b : Int32) { }").should be_a LC::ProcLiteral
      proc.loc.to_tuple.should eq({0, 0, 0, 29})
      proc.params.size.should eq 2

      param = proc.params[0]
      ident = param.name.should be_a LC::Ident
      ident.value.should eq "a"

      const = param.type.should be_a LC::Const
      const.value.should eq "Int32"

      param = proc.params[1]
      ident = param.name.should be_a LC::Ident
      ident.value.should eq "b"

      const = param.type.should be_a LC::Const
      const.value.should eq "Int32"
      proc.body.should be_empty
    end

    it "parses proc expressions with a body" do
      proc = parse("-> do exit end").should be_a LC::ProcLiteral
      proc.loc.to_tuple.should eq({0, 0, 0, 14})
      proc.params.should be_empty
      proc.body.size.should eq 1

      expr = proc.body[0].should be_a LC::Call
      ident = expr.receiver.should be_a LC::Ident
      ident.value.should eq "exit"
      expr.args.should be_empty
    end

    it "parses multiline proc expressions" do
      proc = parse(<<-CR).should be_a LC::ProcLiteral
        -> (
          a : Int32,
          b : Int32,
        )
        do
          a + b
        end
        CR

      proc.loc.to_tuple.should eq({0, 0, 6, 3})
      proc.params.size.should eq 2

      param = proc.params[0]
      ident = param.name.should be_a LC::Ident
      ident.value.should eq "a"

      const = param.type.should be_a LC::Const
      const.value.should eq "Int32"

      param = proc.params[1]
      ident = param.name.should be_a LC::Ident
      ident.value.should eq "b"

      const = param.type.should be_a LC::Const
      const.value.should eq "Int32"
      proc.body.size.should eq 1

      expr = proc.body[0].should be_a LC::Infix
      left = expr.left.should be_a LC::Call
      ident = left.receiver.should be_a LC::Ident
      ident.value.should eq "a"
      expr.op.should eq LC::Infix::Operator::Add

      node = expr.right.should be_a LC::Call
      ident = node.receiver.should be_a LC::Ident
      ident.value.should eq "b"
    end

    it "parses grouped expressions" do
      group = parse("(1 + 2)").should be_a LC::GroupedExpression
      group.loc.to_tuple.should eq({0, 0, 0, 7})

      infix = group.expr.should be_a LC::Infix
      int = infix.left.should be_a LC::IntLiteral
      int.value.should eq 1
      infix.op.should eq LC::Infix::Operator::Add

      int = infix.right.should be_a LC::IntLiteral
      int.value.should eq 2

      group = parse("(foo bar)").should be_a LC::GroupedExpression
      group.loc.to_tuple.should eq({0, 0, 0, 9})

      call = group.expr.should be_a LC::Call
      ident = call.receiver.should be_a LC::Ident
      ident.value.should eq "foo"
      call.args.size.should eq 1

      call = call.args[0].should be_a LC::Call
      ident = call.receiver.should be_a LC::Ident
      ident.value.should eq "bar"
      call.args.should be_empty
    end
  end
end
