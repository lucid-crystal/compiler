package main

import (
	"fmt"

	"github.com/lucid-crystal/compiler/lexer"
)

func main() {
	lexer := lexer.NewLexer("main.cr", `puts "hello world"`)
	r, err := lexer.Lex()
	if err != nil {
		fmt.Printf("err: %v\n", err)
		return
	}

	for i, t := range r {
		fmt.Printf("%d: %#v\n", i, t)
	}
}
