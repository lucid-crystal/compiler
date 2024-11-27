module Lucid::Compiler
  class Token
    enum Kind
      EOF
      Space
      Newline
      Comment

      Ident
      Const

      String
      Char
      Integer
      Float
      True
      False
      Nil

      LeftParen   # (
      RightParen  # )
      Comma       # ,
      Colon       # :
      DoubleColon # ::
      Semicolon   # ;
      Underscore  # _
      LeftBrace   # {
      RightBrace  # }

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
      Class
      Def
      Do
      End
      Enum
      Forall
      IsA
      # Lib
      Module
      Private
      Protected
      RespondsTo
      Self
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
      line_start, line_end = @loc.line
      io << line_start << ':' << line_end

      col_start, col_end = @loc.column
      io << '-' << col_start << ':' << col_end

      if @raw_value
        io << ", value: "
        @raw_value.inspect io
      end

      io << ')'
    end
  end
end
