[![Build/Test](https://github.com/TKNGUE/tree-sitter-sql-bigquery/actions/workflows/ci.yml/badge.svg)](https://github.com/TKNGUE/tree-sitter-sql-bigquery/actions/workflows/ci.yml)

# tree-sitter for BigQuery's SQL

This project supports StandardSQL in BigQuery. You could try out the demo on
[Github Pages](https://takegue.github.io/tree-sitter-sql-bigquery/)

# Supported BigQuery SQL feature

- [x] Basic Literals/Expressions
- [x] Query Statement
- [x] DML Statements
- [x] DDL Statements
- [x] Procedural Language
- [x] BigQuery ML
- [ ] DCL Statements

### References

- ZetaSQL: https://github.com/google/zetasql/blob/master/docs/README.md

- Other SQL Dialect Projects:
  - MySQL: https://github.com/DerekStride/tree-sitter-sql
  - PostgreSQL: https://github.com/m-novikov/tree-sitter-sql
  - SQLite: https://github.com/dhcmrlchtdj/tree-sitter-sqlite

## Development

### Running tests

```
npm install --also=dev
npm test
```

### Debbuging

- `npm run parse <your sql file.sql>` outputs a syntax tree
