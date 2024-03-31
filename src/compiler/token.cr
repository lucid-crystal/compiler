module Lucid::Compiler
  class Token
    enum Kind
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

      LeftParen
      RightParen
      Colon
      DoubleColon
      Comma
      Period

      Plus        # +
      Minus       # -
      Star        # *
      Slash       # /
      DoubleStar  # **
      DoubleSlash # //

      Assign            # =
      Equal             # ==
      CaseEqual         # ===
      PlusAssign        # +=
      MinusAssign       # -=
      StarAssign        # *=
      SlashAssign       # /=
      DoubleStarAssign  # **=
      DoubleSlashAssign # //=

      IsA
      RespondsTo

      Module
      Enum
      Struct
      Class
      Def
      End
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
      @kind.in?(Kind::Plus..Kind::DoubleSlashAssign)
    end

    def assign? : Bool
      @kind.in?(Kind::Assign..Kind::DoubleSlashAssign)
    end
  end
end
