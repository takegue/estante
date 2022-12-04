import Parser from "tree-sitter";
import Language from "tree-sitter-sql-bigquery";

export function createNewParser() {
  const parser = new Parser();
  parser.setLanguage(Language);
  return parser;
}
