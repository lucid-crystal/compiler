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
    property loc : Location
    @value : String?

    def initialize(@type : Type, @loc : Location)
    end

    def value : String
      @value.not_nil!
    end

    def value=(@value : String?)
    end
  end
end
