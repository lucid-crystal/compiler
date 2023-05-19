module Compiler
  class Token
    enum Type
      EOF
      Space
      Newline

      String

      LeftParen
      RightParen

      Ident

      Def
      End
    end

    property type : Type
    property value : String
    property loc : Location

    def initialize(@type : Type, @loc : Location)
      @value = ""
    end
  end
end
