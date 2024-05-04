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
      Colon       # :
      DoubleColon # ::
      Comma       # ,
      Period      # .

      Plus        # +
      Minus       # -
      Star        # *
      DoubleStar  # **
      Slash       # /
      DoubleSlash # //

      Assign            # =
      Equal             # ==
      CaseEqual         # ===
      PlusAssign        # +=
      MinusAssign       # -=
      StarAssign        # *=
      DoubleStarAssign  # **=
      SlashAssign       # /=
      DoubleSlashAssign # //=

      IsA        # is_a?
      RespondsTo # responds_to?

      Module
      Enum
      Struct
      Class
      Def
      End

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
      @kind.in?(Kind::Plus..Kind::DoubleSlash)
    end

    def assign? : Bool
      @kind.in?(Kind::Assign..Kind::DoubleSlashAssign)
    end

    def to_s(io : IO) : Nil
      if @value
        @value.inspect io
      else
        io << @kind.to_s.underscore
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
