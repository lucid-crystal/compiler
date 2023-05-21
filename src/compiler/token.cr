module Compiler
  class Token
    enum Type
      EOF
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
      Equal

      Def
      End
    end

    property type : Type
    property loc : Location
    @value : String?

    def initialize(@type : Type, @loc : Location)
    end

    def value : String
      @value.as(String)
    end

    def value=(@value : String?)
    end
  end
end
