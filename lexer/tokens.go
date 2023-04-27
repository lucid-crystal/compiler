package lexer

type TokenKind int

const (
	TokenEOF TokenKind = iota
	TokenSpace
	TokenNewline
	TokenIdent
	TokenString
)

func (t TokenKind) String() string {
	switch t {
	case TokenEOF:
		return "eof"
	case TokenSpace:
		return "space"
	case TokenNewline:
		return "newline"
	case TokenIdent:
		return "identifier"
	case TokenString:
		return "string"
	default:
		panic("invalid token")
	}
}

type Location struct {
	LineStart int
	LineEnd   int
	ColStart  int
	ColEnd    int
}

type Token struct {
	Kind     TokenKind
	Value    string
	Location Location
}
