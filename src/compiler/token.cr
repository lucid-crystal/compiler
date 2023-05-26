module Compiler
  class Token
    enum Kind
      EOF
      Space
      Newline
      Comment

      Ident

      String
      Number
      Nil

      LeftParen
      RightParen
      Colon
      DoubleColon
      Comma
      Period

      IsA
      RespondsTo

      Equal
      Operator

      Module
      Enum
      Struct
      Class
      Def
      End
    end

    property kind : Kind
    property loc : Location
    @value : String?

    def initialize(@kind : Kind, @loc : Location)
    end

    def value : String
      @value.as(String)
    end

    def value=(@value : String?)
    end
  end
end
