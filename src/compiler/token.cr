module Lucid::Compiler
  class Token
    enum Kind
      Space
      Newline

      Ident

      String
      Number
      Nil

      LeftParen
      RightParen
      Colon
      DoubleColon
      Comma

      Assign
      Equal
      Operator

      Module
      # Enum
      # Struct
      # Class
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
  end
end
