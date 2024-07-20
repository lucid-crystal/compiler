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
      # Alias
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

      # ameba:disable Naming/PredicateName
      def is_nil? : Bool
        self == Kind::Nil
      end
    end

    getter kind : Kind
    getter loc : Location
    @value : String?

    def initialize(@kind : Kind, @loc : Location, @value : String? = nil)
    end

    def value : String
      @value.as(String)
    end

    def value=(@value : String?)
    end

    def operator? : Bool
      @kind.in?(Kind::Bang..Kind::Tilde)
    end

    def to_s(io : IO) : Nil
      if @value
        @value.inspect io
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

      if @value
        io << ", value: "
        @value.inspect io
      end

      io << ')'
    end
  end
end
