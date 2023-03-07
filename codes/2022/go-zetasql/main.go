package main

import (
	"github.com/goccy/go-zetasql"
	"github.com/goccy/go-zetasql/ast"
)

func main() {

	stmt, err := zetasql.ParseStatement("SELECT * FROM Samples WHERE id = 1")
	if err != nil {
		panic(err)
	}

	// use type assertion and get concrete nodes.
	queryStmt := stmt.(*ast.QueryStatementNode)
}
