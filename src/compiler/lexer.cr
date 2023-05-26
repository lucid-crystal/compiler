module Compiler
  class Lexer
    OPERATOR_SYMBOLS = {'+', '-', '*', '/', '='}

    @reader : Char::Reader
    @pool : StringPool
    @line : Int32
    @token : Token

    def initialize(source : String)
      @reader = Char::Reader.new source
      @pool = StringPool.new
      @line = 0
      @token = uninitialized Token
    end

    def run : Array(Token)
      tokens = [] of Token

      loop do
        next_token
        tokens << @token
        break if @token.kind.eof?
      end

      tokens
    end

    private def next_token : Nil
      @token = Token.new :eof, Location[@line, current_pos]

      case current_char
      when '\0'
        finalize_token
      when ' '
        lex_space
      when '\r'
        raise "expected '\\n' after '\\r'" unless next_char == '\n'
        next_char
        @token.kind = :newline
        finalize_token true
        @line += 1
      when '\n'
        next_char
        @token.kind = :newline
        finalize_token true
        @line += 1
      when '('
        next_char
        @token.kind = :left_paren
        finalize_token
      when ')'
        next_char
        @token.kind = :right_paren
        finalize_token
      when ':'
        if next_char == ':'
          next_char
          @token.kind = :double_colon
        else
          @token.kind = :colon
        end
        finalize_token
      when ','
        next_char
        @token.kind = :comma
        finalize_token
      when '='
        next_char
        @token.kind = :equal
        finalize_token
      when .in?(OPERATOR_SYMBOLS)
        lex_operator
      when '"'
        next_char
        @token.loc.increment_column_start
        lex_string_to '"'
        next_char
      when 'd'
        if next_char == 'e' && next_char == 'f'
          lex_keyword_or_ident :def
        else
          lex_ident
        end
      when 'e'
        if next_char == 'n'
          if next_char == 'd'
            lex_keyword_or_ident :end
          else
            current_char == 'u' && next_char == 'm'
            lex_keyword_or_ident :enum
          end
        else
          lex_ident
        end
      when 'n'
        if next_char == 'i' && next_char == 'l'
          lex_keyword_or_ident :nil
        else
          lex_ident
        end
      when 'm'
        if next_sequence?('o', 'd', 'u', 'l', 'e')
          lex_keyword_or_ident :module
        else
          lex_ident
        end
      when 'c'
        if next_sequence?('l', 'a', 's', 's')
          lex_keyword_or_ident :class
        else
          lex_ident
        end
      when 's'
        if next_sequence?('t', 'r', 'u', 'c', 't')
          lex_keyword_or_ident :struct
        else
          lex_ident
        end
      when .ascii_number?
        lex_number
      when .ascii_letter?
        lex_ident
      else
        raise "unexpected token #{current_char.inspect}"
      end
    end

    private def current_pos : Int32
      @reader.pos
    end

    private def current_char : Char
      @reader.current_char
    end

    private def next_char : Char
      @reader.next_char
    end

    private def peek_next_char : Char
      @reader.peek_next_char
    end

    private def finalize_token(with_value : Bool = false) : Nil
      @token.loc.line_end_at @line
      @token.loc.column_end_at current_pos

      if with_value
        start, end = @token.loc.column
        slice = Slice.new(@reader.string.to_unsafe + start, end - start)
        @token.value = @pool.get slice
      end
    end

    private def lex_space : Nil
      while current_char == ' '
        next_char
      end

      @token.kind = :space
      finalize_token true
    end

    private def lex_string_to(end_char : Char) : Nil
      escaped = false

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

      @token.kind = :string
      finalize_token true
    end

    private def lex_operator : Nil
      while current_char.in?(OPERATOR_SYMBOLS)
        next_char
      end

      @token.kind = :operator
      finalize_token true
    end

    private def lex_number : Nil
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

    private def lex_octal : Nil
    end

    private def lex_hexadecimal : Nil
    end

    private def lex_raw_number : Nil
      float = false

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
          raise "invalid float literal" if float
          float = true
        when .ascii_number?
          next
        else
          break
        end
      end

      @token.kind = :number
      finalize_token true
    end

    private def lex_ident : Nil
      while current_char.ascii_alphanumeric? || current_char.in?('_', '[', ']', '!', '?', '=')
        next_char
      end

      @token.kind = :ident
      finalize_token true
    end

    private def next_sequence?(*chars : Char)
      chars.all? { |c| next_char == c }
    end

    private def lex_keyword_or_ident(keyword : Token::Kind) : Nil
      char = peek_next_char
      if char.ascii_alphanumeric? || char.in?('_', '!', '?', '=')
        lex_ident
      else
        next_char
        @token.kind = keyword
        finalize_token
      end
    end
  end
end
