module Lucid::Compiler
  class Lexer
    @reader : Char::Reader
    @pool : StringPool
    @line : Int32
    @column : Int32
    @loc : Location
    @string_nest : Array(Char)

    def self.run(source : String, filename : String = "STDIN", dirname : String = "") : Array(Token)
      new(source, filename, dirname).run
    end

    private def initialize(source : String, @filename : String, @dirname : String)
      @reader = Char::Reader.new source
      @pool = StringPool.new
      @line = @column = 0
      @loc = Location[0, 0, 0, 0]
      @string_nest = [] of Char
    end

    def run : Array(Token)
      tokens = [] of Token

      loop do
        tokens << (token = next_token)
        break if token.kind.eof?
      end

      tokens
    end

    private def next_token : Token
      @loc = Location[@line, @column, @line, @column]

      case current_char
      when '\0'
        Token.new :eof, @loc
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
      when '@'
        if peek_char == '['
          next_char
          next_char
          return Token.new :annotation_open, location
        end

        start = current_pos + 1
        kind = Token::Kind::InstanceVar

        if next_char == '@'
          kind = Token::Kind::ClassVar
          start += 1
          next_char
        end

        while current_char.ascii_alphanumeric? || current_char == '_'
          next_char
        end

        Token.new kind, location, read_string_from start
      when '['
        next_char
        Token.new :left_bracket, location
      when ']'
        next_char
        Token.new :right_bracket, location
      when '('
        next_char
        Token.new :left_paren, location
      when ')'
        next_char
        Token.new :right_paren, location
      when '{'
        next_char
        Token.new :left_brace, location
      when '}'
        next_char
        if @string_nest.empty?
          Token.new :right_brace, location
        else
          lex_string_part @string_nest[-1]
        end
      when ','
        next_char
        Token.new :comma, location
      when ':'
        case next_char
        when ':'
          next_char
          Token.new :double_colon, location
        when '"'
          next_char
          value = read_string_to '"'
          next_char
          Token.new :quoted_symbol, location, value
        when ' '
          Token.new :colon, location
        else
          lex_symbol
        end
      when ';'
        next_char
        Token.new :semicolon, location
      when '_'
        start = current_pos - 1
        case next_char
        when '_'
          case next_char
          when 'F'
            if next_sequence?('I', 'L', 'E', '_', '_')
              next_char
              Token.new :magic_file, location, @filename
            else
              lex_ident start
            end
          when 'E'
            if next_sequence?('N', 'D', '_', 'L', 'I', 'N', 'E', '_', '_')
              next_char
              # TODO(nobody): assign this value later,
              # it should be the corresponding `end`, and is
              # only allowed as a default param value
              Token.new :magic_end_line, location
            else
              lex_ident start
            end
          when 'D'
            if next_sequence?('I', 'R', '_', '_')
              next_char
              Token.new :magic_dir, location, @dirname
            else
              lex_ident start
            end
          when 'L'
            if next_sequence?('I', 'N', 'E', '_', '_')
              next_char
              Token.new :magic_line, location, (@line + 1).to_i64
            else
              lex_ident start
            end
          else
            lex_ident start
          end
        when .ascii_alphanumeric?
          lex_ident start
        else
          Token.new :underscore, location
        end
      when '!'
        case next_char
        when '='
          next_char
          Token.new :not_equal, location
        when '~'
          next_char
          Token.new :pattern_unmatch, location
        else
          Token.new :bang, location
        end
      when '%'
        if next_char == '='
          next_char
          Token.new :modulo_assign, location
        else
          Token.new :modulo, location
        end
      when '&'
        case next_char
        when '&'
          if next_char == '='
            next_char
            Token.new :and_assign, location
          else
            Token.new :and, location
          end
        when '*'
          case next_char
          when '*'
            next_char
            Token.new :binary_double_star, location
          when '='
            next_char
            Token.new :binary_star_assign, location
          else
            Token.new :binary_star, location
          end
        when '+'
          if next_char == '='
            next_char
            Token.new :binary_plus_assign, location
          else
            Token.new :binary_plus, location
          end
        when '-'
          if next_char == '='
            next_char
            Token.new :binary_minus_assign, location
          else
            Token.new :binary_minus, location
          end
        when '.'
          next_char
          Token.new :shorthand, location
        else
          Token.new :bit_and, location
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
      when '+'
        if next_char == '='
          next_char
          Token.new :plus_assign, location
        else
          Token.new :plus, location
        end
      when '-'
        case next_char
        when '='
          next_char
          Token.new :minus_assign, location
        when '>'
          next_char
          Token.new :proc, location
        else
          Token.new :minus, location
        end
      when '.'
        if next_char == '.'
          if next_char == '.'
            next_char
            Token.new :triple_period, location
          else
            Token.new :double_period, location
          end
        else
          Token.new :period, location
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
      when '<'
        case next_char
        when '='
          if next_char == '>'
            next_char
            Token.new :comparison, location
          else
            Token.new :lesser_equal, location
          end
        when '<'
          if next_char == '='
            next_char
            Token.new :shift_left_assign, location
          else
            Token.new :shift_left, location
          end
        else
          Token.new :lesser, location
        end
      when '='
        case next_char
        when '='
          if next_char == '='
            next_char
            Token.new :case_equal, location
          else
            Token.new :equal, location
          end
        when '>'
          next_char
          Token.new :rocket, location
        when '~'
          next_char
          Token.new :pattern_match, location
        else
          Token.new :assign, location
        end
      when '>'
        case next_char
        when '='
          next_char
          Token.new :greater_equal, location
        when '>'
          if next_char == '='
            next_char
            Token.new :shift_right_assign, location
          else
            Token.new :shift_right, location
          end
        else
          Token.new :greater, location
        end
      when '?'
        next_char
        Token.new :question, location
      when '^'
        next_char
        Token.new :caret, location
      when '`'
        next_char
        Token.new :backtick, location
      when '|'
        case next_char
        when '|'
          if next_char == '='
            next_char
            Token.new :or_assign, location
          else
            Token.new :or, location
          end
        when '='
          next_char
          Token.new :bit_or_assign, location
        else
          Token.new :bit_or, location
        end
      when '~'
        next_char
        Token.new :tilde, location
      when '"'
        next_char
        lex_string_or_symbol_key '"'
      when '\''
        case next_char
        when '\0'
          raise "unterminated char literal"
        when '\\'
          case next_char
          when '\0'
            raise "unterminated char literal"
          when '\\'
            value = '\\'
          when '\''
            value = '\''
          when 'a'
            value = '\a'
          when 'b'
            value = '\b'
          when 'e'
            value = '\e'
          when 'f'
            value = '\f'
          when 'n'
            value = '\n'
          when 'r'
            value = '\r'
          when 't'
            value = '\t'
          when 'u'
            value = read_unicode_escape false
          when 'v'
            value = '\v'
          when '0'
            value = '\0'
          else
            raise "invalid char escape sequence '\\#{current_char}'"
          end
        when '\''
          raise "invalid char literal (did you mean '\\''?)"
        else
          value = current_char
        end

        unless next_char == '\''
          raise "unterminated char literal, use double quotes for strings"
        end

        next_char
        Token.new :char, location, value
      when 'a'
        start = current_pos
        case next_char
        when 'b'
          if next_sequence?('s', 't', 'r', 'a', 'c', 't')
            lex_keyword_or_ident :abstract, start
          else
            lex_ident start
          end
        when 'l'
          if next_char == 'i'
            case next_char
            when 'a'
              if next_char == 's'
                lex_keyword_or_ident :alias, start
              else
                lex_ident start
              end
            when 'g'
              if next_sequence?('n', 'o', 'f')
                lex_keyword_or_ident :alignof, start
              else
                lex_ident start
              end
            else
              lex_ident start
            end
          else
            lex_ident start
          end
        when 'n'
          if next_sequence?('n', 'o', 't', 'a', 't', 'i', 'o', 'n')
            lex_keyword_or_ident :annotation, start
          else
            lex_ident start
          end
        else
          lex_ident start
        end
      when 'c'
        start = current_pos
        if next_sequence?('l', 'a', 's', 's')
          lex_keyword_or_ident :class, start
        else
          lex_ident start
        end
      when 'd'
        start = current_pos
        case next_char
        when 'e'
          if next_char == 'f'
            lex_keyword_or_ident :def, start
          else
            lex_ident start
          end
        when 'o'
          lex_keyword_or_ident :do, start
        else
          lex_ident start
        end
      when 'e'
        start = current_pos
        case next_char
        when 'n'
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
        when 'x'
          if next_sequence?('t', 'e', 'n', 'd')
            lex_keyword_or_ident :extend, start
          else
            lex_ident start
          end
        else
          lex_ident start
        end
      when 'f'
        start = current_pos
        case next_char
        when 'a'
          if next_sequence?('l', 's', 'e')
            lex_keyword_or_ident :false, start
          else
            lex_ident start
          end
        when 'o'
          if next_sequence?('r', 'a', 'l', 'l')
            lex_keyword_or_ident :forall, start
          else
            lex_ident start
          end
        else
          lex_ident start
        end
      when 'i'
        start = current_pos
        case next_char
        when 'n'
          case next_char
          when 'c'
            if next_sequence?('l', 'u', 'd', 'e')
              lex_keyword_or_ident :include, start
            else
              lex_ident start
            end
          when 's'
            if next_sequence?('t', 'a', 'n', 'c', 'e', '_')
              case next_char
              when 'a'
                if next_sequence?('l', 'i', 'g', 'n', 'o', 'f')
                  lex_keyword_or_ident :instance_alignof, start
                else
                  lex_ident start
                end
              when 's'
                if next_sequence?('i', 'z', 'e', 'o', 'f')
                  lex_keyword_or_ident :instance_sizeof, start
                else
                  lex_ident start
                end
              else
                lex_ident start
              end
            else
              lex_ident start
            end
          else
            lex_ident start
          end
        when 's'
          if next_sequence?('_', 'a', '?')
            lex_keyword_or_ident :is_a, start
          else
            lex_ident start
          end
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
      when 'n'
        start = current_pos
        if next_sequence?('i', 'l')
          lex_keyword_or_ident :nil, start
        else
          lex_ident start
        end
      when 'o'
        start = current_pos
        if next_sequence?('f', 'f', 's', 'e', 't', 'o', 'f')
          lex_keyword_or_ident :offsetof, start
        else
          lex_ident start
        end
      when 'p'
        start = current_pos
        case next_char
        when 'o'
          if next_sequence?('i', 'n', 't', 'e', 'r', 'o', 'f')
            lex_keyword_or_ident :pointerof, start
          else
            lex_ident start
          end
        when 'r'
          case next_char
          when 'i'
            if next_sequence?('v', 'a', 't', 'e')
              lex_keyword_or_ident :private, start
            else
              lex_ident start
            end
          when 'o'
            if next_sequence?('t', 'e', 'c', 't', 'e', 'd')
              lex_keyword_or_ident :protected, start
            else
              lex_ident start
            end
          else
            lex_ident start
          end
        else
          lex_ident start
        end
      when 'r'
        start = current_pos
        if next_sequence?('e', 'q', 'u', 'i', 'r', 'e')
          lex_keyword_or_ident :require, start
        else
          lex_ident start
        end
      when 's'
        start = current_pos
        case next_char
        when 'e'
          if next_sequence?('l', 'f')
            lex_keyword_or_ident :self, start
          else
            lex_ident start
          end
        when 'i'
          if next_sequence?('z', 'e', 'o', 'f')
            lex_keyword_or_ident :sizeof, start
          else
            lex_ident start
          end
        when 't'
          if next_sequence?('r', 'u', 'c', 't')
            lex_keyword_or_ident :struct, start
          else
            lex_ident start
          end
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

    private def peek_char : Char
      @reader.peek_next_char
    end

    private def next_sequence?(*chars : Char) : Bool
      chars.all? { |c| next_char == c }
    end

    private def location : Location
      @loc.end_at(@line, @column)
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

      loop do
        case current_char
        when .ascii_alphanumeric?, '_'
          next_char
        when '?'
          next_char
          break
        when '!', '='
          next_char unless peek_char == '='
          break
        when ':'
          unless peek_char == ':'
            kind = Token::Kind::SymbolKey
          end
          break
        else
          break
        end
      end

      if kind.symbol_key?
        value = read_string_from start
        next_char
        Token.new kind, location, value
      else
        Token.new kind, location, read_string_from start
      end
    end

    private def lex_symbol : Token
      start = current_pos

      if current_char.ascii_letter?
        loop do
          case current_char
          when .ascii_alphanumeric?, '_'
            next_char
          when '?'
            next_char
            break
          when '!', '='
            next_char unless peek_char == '='
            break
          else
            break
          end
        end

        value = read_string_from start
      else
        case current_char
        when '%', '+', '-', '^', '|', '~'
          value = current_char.to_s
          next_char
        when '!'
          case next_char
          when '='
            value = "!="
            next_char
          when '~'
            value = "!~"
            next_char
          else
            value = "!"
          end
        when '&'
          case next_char
          when '*'
            if next_char == '*'
              value = "&**"
              next_char
            else
              value = "&*"
            end
          when '+'
            value = "&+"
            next_char
          when '-'
            value = "&-"
            next_char
          else
            value = "&"
          end
        when '*'
          if next_char == '*'
            value = "**"
            next_char
          else
            value = "*"
          end
        when '/'
          if next_char == '/'
            value = "//"
            next_char
          else
            value = "/"
          end
        when '<'
          case next_char
          when '<'
            value = "<<"
            next_char
          when '='
            if next_char == '>'
              value = "<=>"
              next_char
            else
              value = "<="
            end
          else
            value = "<"
          end
        when '='
          case next_char
          when '='
            if next_char == '='
              value = "==="
              next_char
            else
              value = "=="
            end
          when '~'
            value = "=~"
            next_char
          else
            value = "="
          end
        when '>'
          case next_char
          when '>'
            value = ">>"
            next_char
          when '='
            value = ">="
            next_char
          else
            value = ">"
          end
        else
          raise "unexpected character for symbol literal #{current_char.inspect}"
        end
      end

      Token.new :symbol, location, value
    end

    private def lex_keyword_or_ident(keyword : Token::Kind, start : Int32 = current_pos) : Token
      char = peek_char

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
        when 'b'
          lex_binary
        else
          lex_raw_number
        end
      else
        lex_raw_number
      end
    end

    private def lex_octal : Token
      start = current_pos + 1
      kind = Token::Kind::Integer

      loop do
        case next_char
        when '0'..'7'
          next
        when '8', '9', '.'
          raise "invalid octal literal"
        when 'i', 'u'
          raise "not implemented"
        else
          break
        end
      end

      value = read_string_from(start).to_i64(base: 8)
      Token.new kind, location, value
    end

    private def lex_hexadecimal : Token
      start = current_pos + 1
      kind = Token::Kind::Integer

      loop do
        case next_char
        when .hex?, '_'
          next
        when '.'
          raise "invalid hexadecimal literal"
        when 'i', 'u'
          raise "not implemented"
        else
          break
        end
      end

      value = read_string_from(start).to_i64(base: 16)
      Token.new kind, location, value
    end

    private def lex_binary : Token
      start = current_pos + 1
      kind = Token::Kind::Integer

      loop do
        case next_char
        when '0', '1', '_'
          next
        when '.'
          raise "invalid binary literal"
        when 'i', 'u'
          raise "not implemented"
        else
          break
        end
      end

      value = read_string_from(start).to_i64(base: 2)
      Token.new kind, location, value
    end

    private def lex_raw_number : Token
      start = current_pos
      kind = Token::Kind::Integer

      loop do
        case next_char
        when 'f'
          kind = Token::Kind::Float
          case next_char
          when '3'
            if next_char == '2' && !peek_char.ascii_number?
              next_char
            else
              kind = Token::Kind::FloatBadSuffix
              while next_char.ascii_number?
                # skip
              end
            end
            break
          when '6'
            if next_char == '4' && !peek_char.ascii_number?
              next_char
            else
              kind = Token::Kind::FloatBadSuffix
              while next_char.ascii_number?
                # skip
              end
            end
            break
          else
            kind = Token::Kind::FloatBadSuffix
            while next_char.ascii_number?
              # skip
            end
            break
          end
        when 'i', 'u'
          case next_char
          when '8'
            if peek_char.ascii_number?
              kind = Token::Kind::IntegerBadSuffix
              while next_char.ascii_number?
                # skip
              end
            else
              next_char
            end
            break
          when '1'
            case next_char
            when '2'
              if next_char == '8' && !peek_char.ascii_number?
                next_char
              else
                kind = Token::Kind::IntegerBadSuffix
                while next_char.ascii_number?
                  # skip
                end
              end
              break
            when '6'
              if peek_char.ascii_number?
                kind = Token::Kind::IntegerBadSuffix
                while next_char.ascii_number?
                  # skip
                end
              else
                next_char
              end
              break
            else
              kind = Token::Kind::FloatBadSuffix
              while next_char.ascii_number?
                # skip
              end
              break
            end
          when '3'
            if next_char == '2' && !peek_char.ascii_number?
              next_char
            else
              kind = Token::Kind::IntegerBadSuffix
              while next_char.ascii_number?
                # skip
              end
            end
            break
          when '6'
            if next_char == '4' && !peek_char.ascii_number?
              next_char
            else
              kind = Token::Kind::IntegerBadSuffix
              while next_char.ascii_number?
                # skip
              end
            end
            break
          else
            kind = Token::Kind::FloatBadSuffix
            while next_char.ascii_number?
              # skip
            end
            break
          end
        when '_'
          next
        when '.'
          break if kind.float?
          case peek_char
          when .ascii_letter?, '.'
            break
          when .ascii_number?
            next_char
            kind = Token::Kind::Float
          else
            raise "unexpected token '#{next_char}'"
          end
        when .ascii_number?
          next
        else
          break
        end
      end

      Token.new kind, location, read_string_from start
    end

    private def lex_string_or_symbol_key(end_char : Char) : Token
      start = current_pos
      escaped = false
      @string_nest << end_char

      loop do
        case current_char
        when '\0'
          raise "unterminated quote literal"
        when '\\'
          escaped = !escaped
          next_char
        when '#'
          if next_char == '{' && !escaped
            loc = location
            next_char
            return Token.new :string_start, loc, read_string_from(start)[..-3]
          end
          escaped = false
        when end_char
          break unless escaped
          escaped = false
          next_char
        else
          next_char
          escaped = false
        end
      end

      value = read_string_from start
      @string_nest.pop

      if next_char == ':'
        next_char
        Token.new :symbol_key, location, value
      else
        Token.new :string, location, value
      end
    end

    private def lex_string_part(end_char : Char) : Token
      start = current_pos
      escaped = false

      loop do
        case current_char
        when '\0'
          raise "unterminated quote literal"
        when '\\'
          escaped = !escaped
          next_char
        when '#'
          if next_char == '{' && !escaped
            next_char
            return Token.new :string_part, location, read_string_from(start)[..-3]
          end
          escaped = false
        when end_char
          break unless escaped
          escaped = false
        else
          next_char
          escaped = false
        end
      end

      value = read_string_from start
      next_char
      @string_nest.pop

      Token.new :string_end, location, value
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

    private def read_unicode_escape(allow_spaces : Bool) : Char
      if peek_char == '{'
        next_char
        codepoint = 0
        found_brace = found_space = found_digit = false
        char = '\0'

        6.times do
          char = next_char
          case char
          when '}'
            found_brace = true
            break
          when ' '
            if allow_spaces
              found_space = true
              break
            else
              raise "expected hexadecimal character in unicode escape"
            end
          else
            hex = char.to_i?(16) || raise "expected hexadecimal character in unicode escape"
            codepoint = 16 &* codepoint &+ hex
            found_digit = true
          end
        end

        if !found_digit
          raise "expected hexadecimal character in unicode escape"
        elsif codepoint > 0x10FFFF
          raise "invalid unicode codepoint (too large)"
        elsif 0xD800 <= codepoint <= 0xDFFF
          raise "invalid unicode codepoint (surrogate half)"
        end

        unless found_space
          char = next_char unless found_brace

          unless char == '}'
            raise "expected '}' to close unicode escape"
          end
        end

        codepoint.chr
      else
        codepoint = 0

        4.times do
          hex = next_char.to_i?(16) || raise "expected hexadecimal character in unicode escape"
          codepoint = 16 &* codepoint &+ hex
        end

        if 0xD800 <= codepoint <= 0xDFFF
          raise "invalid unicode codepoint (surrogate half)"
        end

        codepoint.chr
      end
    end
  end
end
