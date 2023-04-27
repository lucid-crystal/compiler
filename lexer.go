package compiler

import (
	"errors"
	"fmt"
	"io"
	"strings"
	"unicode"
)

type ErrExpected struct {
	wanted rune
	got    rune
}

func (e *ErrExpected) Error() string {
	return fmt.Sprintf("expected token %#q; got %#q", e.wanted, e.got)
}

type ErrUnexpected struct {
	token rune
}

func (e *ErrUnexpected) Error() string {
	return fmt.Sprintf("unexpected token %#q", e.token)
}

type Lexer struct {
	filename string
	source   string
	reader   *strings.Reader
	line     int
	pos      int
	token    *Token
}

func NewLexer(file, source string) *Lexer {
	r := strings.NewReader(source)
	return &Lexer{filename: file, source: source, reader: r}
}

func (l *Lexer) Lex() ([]*Token, error) {
	var t []*Token
	var err error

	for {
		l.newToken()
		b, err := l.next()
		if err != nil {
			if errors.Is(err, io.EOF) {
				err = nil
				break
			}
			return nil, err
		}

		switch b {
		case ' ':
			err = l.LexSpace()
		case '\r':
			fallthrough
		case '\n':
			err = l.LexNewline()
		case '"':
			err = l.LexString()
		default:
			if unicode.IsLetter(b) {
				err = l.LexIdent()
			} else if unicode.IsNumber(b) {
				err = l.LexNumber()
			} else {
				return nil, &ErrUnexpected{b}
			}
		}

		if err != nil {
			if errors.Is(err, io.EOF) {
				err = nil
				break
			}
			return nil, err
		}

		l.token.Location.LineEnd = l.line
		l.token.Location.ColEnd = l.pos
		t = append(t, l.token)
	}

	return t, err
}

func (l *Lexer) newToken() {
	loc := Location{l.line, 0, l.pos, 0}
	l.token = &Token{Location: loc}
}

func (l *Lexer) setTokenValue() {
	l.token.Value = l.source[l.token.Location.ColStart : l.pos-1]
}

func (l *Lexer) next() (rune, error) {
	n, _, err := l.reader.ReadRune()
	if err != nil {
		return 0, err
	}
	l.pos++
	return n, nil
}

func (l *Lexer) expectNext(n rune) error {
	r, err := l.next()
	if err != nil {
		return err
	}
	if n != r {
		return &ErrExpected{r, n}
	}
	return nil
}

// expectSeq
func (l *Lexer) ExpectSeq(s ...rune) error {
	for _, r := range s {
		if err := l.expectNext(r); err != nil {
			return err
		}
	}
	return nil
}

func (l *Lexer) LexSpace() error {
	l.token.Kind = TokenSpace
	for {
		b, err := l.next()
		if err != nil {
			return err
		}
		if b != ' ' {
			return nil
		}
	}
}

func (l *Lexer) LexNewline() error {
	l.token.Kind = TokenNewline
	for {
		b, err := l.next()
		if err != nil {
			return err
		}

		if b == '\r' {
			if err := l.expectNext('\n'); err != nil {
				return err
			}
		}

		if b == '\n' {
			l.line++
			continue
		}

		return nil
	}
}

func (l *Lexer) LexIdent() error {
	for {
		r, err := l.next()
		if err != nil {
			return err
		}
		if unicode.IsLetter(r) || unicode.IsNumber(r) {
			continue
		}
		break
	}

	l.token.Kind = TokenIdent
	l.setTokenValue()
	return nil
}

func (l *Lexer) LexString() error {
	l.token.Location.ColStart++

	for {
		r, err := l.next()
		if err != nil {
			return err
		}
		if r == '"' {
			break
		}
	}

	l.token.Kind = TokenString
	l.setTokenValue()
	return nil
}

// TODO
func (l *Lexer) LexNumber() error { return nil }
