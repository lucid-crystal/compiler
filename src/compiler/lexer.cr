module Lucid::Compiler
  class Lexer
    @reader : Char::Reader
    @pool : StringPool
    @line : Int32
    @column : Int32
    @loc : Location

    def self.run(source : String) : Array(Token)
      new(source).run
    end

    private def initialize(source : String)
      @reader = Char::Reader.new source
      @pool = StringPool.new
      @line = @column = 0
      @loc = Location[0, 0]
    end

    def run : Array(Token)
      tokens = [] of Token

      loop do
        break unless token = next_token
        tokens << token
      end

      tokens
    end

    private def next_token : Token?
      @loc = Location[@line, @column]

      case current_char
      when '\0'
        return
      when ' '
        lex_space
      when '\r'
        raise "expected '\\n' after '\\r'" unless next_char == '\n'
        next_char
        loc = location
        @line += 1
        @column = 0
        Token.new :newline, loc
      when '\n'
        next_char
        loc = location
        @line += 1
        @column = 0
        Token.new :newline, loc
      when '#'
        lex_comment
      when '('
        next_char
        Token.new :left_paren, location
      when ')'
        next_char
        Token.new :right_paren, location
      when ':'
        if next_char == ':'
          next_char
          Token.new :double_colon, location
        else
          Token.new :colon, location
        end
      when ','
        next_char
        Token.new :comma, location
      when '.'
        next_char
        Token.new :period, location
      when '='
        if next_char == '='
          if next_char == '='
            next_char
            Token.new :case_equal, location
          else
            Token.new :equal, location
          end
        else
          Token.new :assign, location
        end
      when '+'
        if next_char == '='
          next_char
          Token.new :plus_assign, location
        else
          Token.new :plus, location
        end
      when '-'
        if next_char == '='
          next_char
          Token.new :minus_assign, location
        else
          Token.new :minus, location
        end
      when '*'
        case next_char
        when '*'
          if next_char == '='
            next_char
            Token.new :double_star_assign, location
          else
            Token.new :double_star, location
          end
        when '='
          next_char
          Token.new :star_assign, location
        else
          Token.new :star, location
        end
      when '/'
        case next_char
        when '/'
          if next_char == '='
            next_char
            Token.new :double_slash_assign, location
          else
            Token.new :double_slash, location
          end
        when '='
          next_char
          Token.new :slash_assign, location
        else
          Token.new :slash, location
        end
      when '"'
        next_char
        @loc.increment_column_start
        value = read_string_to '"'
        next_char
        Token.new :string, location, value
      when 'c'
        start = current_pos
        if next_sequence?('l', 'a', 's', 's')
          lex_keyword_or_ident :class, start
        else
          lex_ident start
        end
      when 'd'
        start = current_pos
        if next_sequence?('e', 'f')
          lex_keyword_or_ident :def, start
        else
          lex_ident start
        end
      when 'e'
        start = current_pos
        if next_char == 'n'
          case next_char
          when 'd'
            lex_keyword_or_ident :end, start
          when 'u'
            if next_char == 'm'
              lex_keyword_or_ident :enum, start
            else
              lex_ident start
            end
          else
            lex_ident start
          end
        else
          lex_ident start
        end
      when 'f'
        start = current_pos
        if next_sequence?('a', 'l', 's', 'e')
          lex_keyword_or_ident :false, start
        else
          lex_ident start
        end
      when 'i'
        start = current_pos
        if next_sequence?('s', '_', 'a', '?')
          lex_keyword_or_ident :is_a, start
        else
          lex_ident start
        end
      when 'n'
        start = current_pos
        if next_sequence?('i', 'l')
          lex_keyword_or_ident :nil, start
        else
          lex_ident start
        end
      when 'm'
        start = current_pos
        if next_sequence?('o', 'd', 'u', 'l', 'e')
          lex_keyword_or_ident :module, start
        else
          lex_ident start
        end
      when 's'
        start = current_pos
        if next_sequence?('t', 'r', 'u', 'c', 't')
          lex_keyword_or_ident :struct, start
        else
          lex_ident start
        end
      when 't'
        start = current_pos
        if next_sequence?('r', 'u', 'e')
          lex_keyword_or_ident :true, start
        else
          lex_ident start
        end
      when .ascii_number?
        lex_number
      when .ascii_letter?
        lex_ident
      else
        raise "unexpected token #{current_char.inspect}"
      end
    end

    private def current_char : Char
      @reader.current_char
    end

    private def current_pos : Int32
      @reader.pos
    end

    private def next_char : Char
      @column += 1
      @reader.next_char
    end

    private def next_sequence?(*chars : Char) : Bool
      chars.all? { |c| next_char == c }
    end

    private def location : Location
      @loc.line_end_at @line
      @loc.column_end_at @column
      @loc
    end

    private def lex_space : Token
      start = current_pos
      while current_char == ' '
        next_char
      end

      Token.new :space, location, read_string_from start
    end

    private def lex_comment : Token
      start = current_pos

      until current_char.in?('\0', '\r', '\n')
        next_char
      end

      Token.new :comment, location, read_string_from start
    end

    private def lex_ident(start : Int32 = current_pos) : Token
      kind = current_char.uppercase? ? Token::Kind::Const : Token::Kind::Ident

      while current_char.ascii_alphanumeric? || current_char.in?('_', '[', ']', '!', '?', '=')
        next_char
      end

      Token.new kind, location, read_string_from start
    end

    private def lex_keyword_or_ident(keyword : Token::Kind, start : Int32 = current_pos) : Token
      char = @reader.peek_next_char

      if char.ascii_alphanumeric? || char.in?('_', '!', '?', '=')
        lex_ident start
      else
        next_char
        Token.new keyword, location
      end
    end

    private def lex_number : Token
      if current_char == '0'
        case next_char
        when 'o'
          lex_octal
        when 'x'
          lex_hexadecimal
        else
          lex_raw_number
        end
      else
        lex_raw_number
      end
    end

    private def lex_octal : Token
      raise "not implemented"
    end

    private def lex_hexadecimal : Token
      raise "not implemented"
    end

    private def lex_raw_number : Token
      start = current_pos
      kind = Token::Kind::Integer

      loop do
        case next_char
        when 'f'
          case next_char
          when '3'
            raise "invalid float literal" unless next_char == '2'
            break
          when '6'
            raise "invalid float literal" unless next_char == '4'
            break
          else
            raise "invalid float literal"
          end
        when 'i'
          case next_char
          when '8'
            break
          when '1'
            case next_char
            when '2'
              raise "invalid integer literal" unless next_char == '8'
            when '6'
              break
            else
              raise "invalid integer literal"
            end
            break
          when '3'
            raise "invalid integer literal" unless next_char == '2'
          when '6'
            raise "invalid integer literal" unless next_char == '4'
          else
            raise "invalid integer literal"
          end
        when '_'
          next
        when '.'
          raise "invalid float literal" if kind.float?
          kind = Token::Kind::Float
        when .ascii_number?
          next
        else
          break
        end
      end

      Token.new kind, location, read_string_from start
    end

    private def read_string_from(start : Int32) : String
      @pool.get Slice.new(@reader.string.to_unsafe + start, current_pos - start)
    end

    private def read_string_to(end_char : Char) : String
      escaped = false
      start = current_pos

      loop do
        case current_char
        when '\\'
          escaped = !escaped
        when end_char
          break unless escaped
          escaped = false
        end
        next_char
      end

      read_string_from start
    end
  end
end
