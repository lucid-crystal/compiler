module Lucid::Compiler
  class Token
    enum Kind
      EOF
      Space
      Newline
      Comment

      Ident
      Const
      InstanceVar
      ClassVar

      String
      StringStart
      StringPart
      StringEnd
      Char
      Symbol
      QuotedSymbol
      SymbolKey
      Integer
      Float
      IntegerBadSuffix
      FloatBadSuffix
      True
      False
      Nil

      LeftParen      # (
      RightParen     # )
      Comma          # ,
      Colon          # :
      DoubleColon    # ::
      Semicolon      # ;
      Underscore     # _
      LeftBrace      # {
      RightBrace     # }
      AnnotationOpen # @[
      LeftBracket    # [
      RightBracket   # ]

      Bang             # !
      NotEqual         # !=
      PatternUnmatch   # !~
      Modulo           # %
      BitAnd           # &
      And              # &&
      BinaryStar       # &*
      BinaryDoubleStar # &**
      BinaryPlus       # &+
      BinaryMinus      # &-
      Shorthand        # &.
      Star             # *
      DoubleStar       # **
      Plus             # +
      Minus            # -
      Proc             # ->
      Period           # .
      DoublePeriod     # ..
      TriplePeriod     # ...
      Slash            # /
      DoubleSlash      # //
      Lesser           # <
      ShiftLeft        # <<
      LesserEqual      # <=
      Comparison       # <=>
      Equal            # ==
      CaseEqual        # ===
      Rocket           # =>
      PatternMatch     # =~
      Greater          # >
      ShiftRight       # >>
      GreaterEqual     # >=
      Question         # ?
      Caret            # ^
      Backtick         # `
      BitOr            # |
      Or               # ||
      Tilde            # ~

      Assign            # =
      ModuloAssign      # %=
      BitAndAssign      # &=
      AndAssign         # &&=
      BinaryStarAssign  # &*=
      BinaryPlusAssign  # &+=
      BinaryMinusAssign # &-=
      StarAssign        # *=
      DoubleStarAssign  # **=
      PlusAssign        # +=
      MinusAssign       # -=
      SlashAssign       # /=
      DoubleSlashAssign # //=
      ShiftLeftAssign   # <<=
      ShiftRightAssign  # >>=
      CaretAssign       # ^=
      BitOrAssign       # |=
      OrAssign          # ||=

      Abstract
      Alias
      Alignof
      Annotation
      Class
      Def
      Do
      End
      Enum
      Extend
      Forall
      Include
      InstanceAlignof
      InstanceSizeof
      IsA
      # Lib
      Module
      Offsetof
      Pointerof
      Private
      Protected
      RespondsTo
      Self
      Sizeof
      Struct
      Require

      # Magic Constants
      MagicLine    # __LINE__
      MagicEndLine # __END_LINE__
      MagicFile    # __FILE__
      MagicDir     # __DIR__

      # ameba:disable Naming/PredicateName
      def is_nil? : Bool
        self == Kind::Nil
      end

      def keyword? : Bool
        self.in?(
          Abstract, Alias, Annotation, Class, Def, Do, End, Enum, Extend,
          Forall, Include, Module, Private, Protected, Struct, Require
        )
      end

      def pseudo? : Bool
        self.in?(Alignof, InstanceAlignof, InstanceSizeof, Offsetof, Pointerof, Sizeof)
      end
    end

    getter kind : Kind
    getter loc : Location
    getter raw_value : String | Int64 | Float64 | Char | Nil

    def initialize(@kind : Kind, @loc : Location, @raw_value : String | Int64 | Float64 | Char | Nil = nil)
    end

    def str_value : String
      @raw_value.as(String)
    end

    def char_value : Char
      @raw_value.as(Char)
    end

    def operator? : Bool
      @kind.in?(Kind::Bang..Kind::Tilde)
    end

    def to_s(io : IO) : Nil
      if @raw_value
        @raw_value.inspect io
      else
        io << '\'' << @kind.to_s.underscore << '\''
      end
    end

    def inspect(io : IO) : Nil
      io << "Token(kind: "
      @kind.inspect io

      io << ", loc: "
      line_start, col_start, line_end, col_end = @loc.to_tuple
      io << line_start << ':' << col_start << '-' << line_end << ':' << col_end

      if @raw_value
        io << ", value: "
        @raw_value.inspect io
      end

      io << ')'
    end
  end
end
