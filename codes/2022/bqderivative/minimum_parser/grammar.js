const multiplicative_operators = ["*", "/", "||"],
  shift_operators = ["<<", ">>"],
  comparative_operators = ["<", "<=", "<>", "=", ">", ">=", "!="],
  additive_operators = ["+", "-"],
  unary_operators = ["~", "+", "-"],
  unquoted_identifier = (_) => /[_a-zA-Z][_a-zA-Z0-9]*/,
  quoted_identifier = (_) => /`[a-zA-Z0-9._-]+`/;

module.exports = grammar({
  name: "sql_bigquery",
  extras: ($) => [
    /\s\n/,
    /\s/,
    $.comment,
    /[\s\f\uFEFF\u2060\u200B]|\\\r?\n/,
  ],

  // Reference:
  //   Operator Precedence: https://cloud.google.com/bigquery/docs/reference/standard-sql/operators#operator_precedence
  precedences: (_) => [
    [
      "unary_exp",
      "binary_times",
      "binary_plus",
      "binary_bitwise_shift",
      "binary_bitwise_and",
      "binary_bitwise_xor",
      "binary_bitwise_or",
      "operator_compare",
      "binary_relation",
      "binary_concat",
      "binary_and",
      "binary_or",
      "unary_not",
      "statement",
      "clause_connective",
    ],
  ],
  conflicts: ($) => [[$.query_expr]],
  externals: ($) => [
    $._string_start,
    $._string_content,
    $._string_end,
  ],

  word: ($) => $._unquoted_identifier,
  rules: {
    source_file: ($) => repeat($._statement),

    /** ************************************************************************
     *                              Keywords
     * ************************************************************************* */

    keyword_if_not_exists: (_) => kw("IF NOT EXISTS"),
    keyword_if_exists: (_) => kw("IF EXISTS"),
    keyword_temporary: (_) => choice(kw("TEMP"), kw("TEMPORARY")),
    keyword_replace: (_) => kw("OR REPLACE"),
    _keyword_alter: (_) => kw("ALTER"),
    _keyword_from: (_) => kw("FROM"),
    _keyword_distinct: (_) => kw("DISTINCT"),
    _keyword_format: (_) => kw("FORMAT"),
    _keyword_delete: (_) => kw("DELETE"),
    _keyword_tablesuffix: (_) => kw("_TABLE_SUFFIX"),
    _keyword_begin: (_) => kw("BEGIN"),
    _keyword_end: (_) => kw("END"),
    _keyword_struct: (_) => kw("STRUCT"),
    _keyword_array: (_) => kw("ARRAY"),
    _keyword_returns: (_) => kw("RETURNS"),
    _keyword_between: (_) => kw("BETWEEN"),
    _keyword_case: (_) => kw("CASE"),
    _keyword_when: (_) => kw("WHEN"),
    _keyword_then: (_) => kw("THEN"),
    _keyword_else: (_) => kw("ELSE"),
    _keyword_is: (_) => kw("IS"),
    _keyword_in: (_) => kw("IN"),
    _keyword_not: (_) => kw("NOT"),
    _keyword_and: (_) => kw("AND"),
    _keyword_or: (_) => kw("OR"),
    _keyword_like: (_) => kw("LIKE"),
    _keyword_repeat: (_) => kw("REPEAT"),
    _keyword_as: (_) => kw("AS"),
    _keyword_cast: (_) => choice(kw("CAST"), kw("SAFE_CAST")),
    _keyword_window: (_) => kw("WINDOW"),
    _keyword_partition_by: (_) => kw("PARTITION BY"),
    _keyword_date: (_) => kw("DATE"),
    _keyword_for: (_) => kw("FOR"),
    _keyword_system_as_of: (_) => kw("FOR SYSTEM_TIME AS OF"),

    /** ************************************************************************
     *                              Statements
     * ************************************************************************* */

    _statement: ($) =>
      seq(
        choice(
          $.query_statement,
        ),
        optional(";"),
      ),

    /** *******************************************************************************
     *  Query Statement
     * ***************************************************************************** */
    query_statement: ($) => $.query_expr,
    set_operation: ($) =>
      prec.right(
        seq(
          $.query_expr,
          field(
            "operator",
            choice(
              kw("UNION ALL"),
              kw("UNION DISTINCT"),
              kw("INTERSECT DISTINCT"),
              kw("EXCEPT DISTINCT"),
            ),
          ),
          $.query_expr,
        ),
      ),
    query_expr: ($) =>
      prec(
        10,
        seq(
          optional($.cte_clause),
          choice($.select, seq("(", $.query_expr, ")"), $.set_operation),
          optional($.order_by_clause),
          optional($.limit_clause),
        ),
      ),
    select: ($) =>
      seq(
        kw("SELECT"),
        optional(choice(kw("ALL"), $._keyword_distinct)),
        optional(seq($._keyword_as, choice($._keyword_struct, kw("VALUE")))),
        $.select_list,
        optional($.from_clause),
        optional($.where_clause),
        optional($.group_by_clause),
        optional($.having_clause),
        optional($.qualify_clause),
        optional($.window_clause),
      ),

    select_list: ($) =>
      prec.right(
        seq(
          commaSep1(
            choice(
              $.select_all,
              alias($._aliasable_expression, $.select_expression),
            ),
          ),
          // Allow trailing comma
          optional(","),
        ),
      ),
    select_all: ($) =>
      prec.right(
        seq(
          seq($.asterisk_expression),
          optional($.select_all_except),
          optional($.select_all_replace),
        ),
      ),
    select_all_except: ($) =>
      seq(kw("EXCEPT"), "(", commaSep1(field("except_key", $.identifier)), ")"),
    select_all_replace: ($) =>
      seq(kw("REPLACE"), "(", commaSep1($.select_replace_expression), ")"),
    select_replace_expression: ($) => seq($._expression, $.as_alias),
    select_expr: ($) => seq($._expression, $.as_alias),
    having_clause: ($) => seq(kw("HAVING"), $._expression),
    qualify_clause: ($) => seq(kw("QUALIFY"), $._expression),
    limit_clause: ($) =>
      seq(kw("LIMIT"), $._integer, optional(seq(kw("OFFSET"), $._integer))),
    group_by_clause_body: ($) => commaSep1($._expression),
    group_by_clause: ($) =>
      seq(
        kw("GROUP BY"),
        choice(
          $.group_by_clause_body,
          seq(kw("ROLLUP"), "(", $.group_by_clause_body, ")"),
        ),
      ),
    over_clause: ($) =>
      choice(
        $.identifier,
        $.window_specification,
      ),
    window_specification: ($) =>
      seq(
        "(",
        optional($.identifier),
        optional($.window_partition_clause),
        optional($.order_by_clause),
        optional($.window_frame_clause),
        ")",
      ),
    window_partition_clause: ($) =>
      seq(
        $._keyword_partition_by,
        commaSep1(alias($._expression, $.partition_expression)),
      ),
    window_frame_clause: ($) =>
      seq(
        $.rows_range,
        choice(optional($.window_frame_start), $.window_frame_between),
      ),
    rows_range: (_) => choice(kw("ROWS"), kw("RANGE")),
    window_frame_start: ($) =>
      seq(
        choice(
          $.window_numeric_preceding,
          $.keyword_unbounded_preceding,
          $.keyword_current_row,
        ),
      ),
    window_frame_between: ($) =>
      seq(
        $._keyword_between,
        choice(
          seq(
            alias(
              choice($.keyword_unbounded_preceding, $.window_numeric_preceding),
              $.between_from,
            ),
            $._keyword_and,
            alias($._window_frame_end_a, $.between_to),
          ),
          seq(
            alias($.keyword_current_row, $.between_from),
            $._keyword_and,
            $._window_frame_end_b,
          ),
          seq(
            alias($.window_numeric_following, $.between_from),
            $._keyword_and,
            alias($._window_frame_end_c, $.between_to),
          ),
        ),
      ),
    _window_frame_end_a: ($) =>
      choice(
        $.window_numeric_preceding,
        $.keyword_current_row,
        $.window_numeric_following,
        $.keyword_unbounded_preceding,
      ),
    _window_frame_end_b: ($) =>
      choice(
        $.keyword_current_row,
        $.window_numeric_following,
        $.keyword_unbounded_following,
      ),
    _window_frame_end_c: ($) =>
      choice(
        $.window_numeric_following,
        $.keyword_unbounded_following,
      ),
    window_numeric_preceding: ($) => seq($.number, kw("PRECEDING")),
    window_numeric_following: ($) => seq($.number, kw("FOLLOWING")),
    keyword_unbounded_preceding: (_) => kw("UNBOUNDED PRECEDING"),
    keyword_unbounded_following: (_) => kw("UNBOUNDED FOLLOWING"),
    keyword_current_row: (_) => kw("CURRENT ROW"),

    named_window_expression: ($) =>
      seq(
        $.identifier,
        $._keyword_as,
        choice($.identifier, $.window_specification),
      ),
    window_clause: ($) => seq($._keyword_window, $.named_window_expression),
    order_by_clause_body: ($) =>
      commaSep1(
        seq(
          $._expression,
          optional($._direction_keywords),
          optional($._nulls_preference),
        ),
      ),
    _direction_keywords: (_) => field("order", choice(kw("ASC"), kw("DESC"))),
    _nulls_preference: (_) =>
      field("nulls_preference", choice(kw("NULLS FIRST"), kw("NULLS LAST"))),
    order_by_clause: ($) => seq(kw("ORDER BY"), $.order_by_clause_body),
    where_clause: ($) => seq(kw("WHERE"), $._expression),
    _aliasable_expression: ($) =>
      prec.right(seq($._expression, optional($.as_alias))),

    as_alias: ($) =>
      seq(optional($._keyword_as), field("alias_name", $.identifier)),

    cte_clause: ($) =>
      seq(
        kw("WITH"),
        commaSep1($.non_recursive_cte),
      ),
    non_recursive_cte: ($) =>
      seq(
        field("alias_name", $.identifier),
        $._keyword_as,
        "(",
        $.query_expr,
        ")",
      ),
    from_clause: ($) =>
      seq(
        $._keyword_from,
        seq(
          $.from_item,
          optional(choice($.pivot_operator, $.unpivot_operator)),
          optional($.tablesample_operator),
        ),
      ),
    pivot_value: ($) => seq($.function_call, optional($.as_alias)),
    pivot_operator: ($) =>
      seq(
        kw("PIVOT"),
        "(",
        commaSep1($.pivot_value),
        $._keyword_for,
        alias($.identifier, $.input_column),
        kw("IN"),
        "(",
        commaSep1(alias($._aliasable_expression, $.pivot_column)),
        ")",
        ")",
        optional($.as_alias),
      ),
    unpivot_operator: ($) =>
      seq(
        kw("UNPIVOT"),
        optional(choice(kw("INCLUDE NULLS"), kw("EXCLUDE NULLS"))),
        "(",
        choice($.single_column_unpivot, $.multi_column_unpivot),
        ")",
        optional($.as_alias),
      ),
    single_column_unpivot: ($) =>
      seq(
        alias($.identifier, $.unpivot_value),
        $._keyword_for,
        alias($.identifier, $.name_column),
        kw("IN"),
        "(",
        commaSep1($.unpivot_column),
        ")",
      ),
    multi_column_unpivot: ($) =>
      prec.right(
        seq(
          "(",
          commaSep1(alias($.identifier, $.unpivot_value)),
          ")",
          $._keyword_for,
          alias($.identifier, $.name_column),
          kw("IN"),
          "(",
          commaSep1($.unpivot_column),
          ")",
        ),
      ),
    unpivot_column: ($) =>
      seq(
        choice($.struct, $.identifier),
        optional(seq($._keyword_as, field("alias", $.string))),
      ),

    tablesample_operator: ($) =>
      seq(
        kw("TABLESAMPLE SYSTEM"),
        "(",
        field("sample_rate", choice($._integer, $.query_parameter)),
        kw("PERCENT"),
        ")",
      ),
    from_item: ($) =>
      seq(
        choice(
          seq(field("table_name", $.identifier), optional($.as_alias)),
          //TODO: add fucntion call subexpression
          seq($.select_subexpression, optional($.as_alias)),
          $.unnest_clause,
          $.join_operation,
          seq("(", $.join_operation, ")"),
        ),
      ),
    join_operation: ($) =>
      choice($._cross_join_operation, $._conditional_join_operator),
    join_type: ($) =>
      seq(
        choice(
          kw("INNER"),
          seq(
            choice(kw("LEFT"), kw("RIGHT"), kw("FULL")),
            optional(kw("OUTER")),
          ),
        ),
      ),
    _cross_join_operation: ($) =>
      prec.left(
        "clause_connective",
        seq(
          $.from_item,
          field("operator", choice(kw("CROSS JOIN"), ",")),
          $.from_item,
        ),
      ),
    _conditional_join_operator: ($) =>
      prec.left(
        "clause_connective",
        seq(
          $.from_item,
          optional($.join_type),
          kw("JOIN"),
          $.from_item,
          optional($.join_condition),
        ),
      ),
    join_condition: ($) =>
      choice(
        seq(kw("ON"), $._expression),
        seq(kw("USING"), "(", commaSep1(field("keys", $.identifier)), ")"),
      ),

    select_subexpression: ($) => seq("(", $.query_expr, ")"),

    analytics_clause: ($) => seq(seq(kw("OVER"), $.over_clause)),

    function_call: ($) =>
      // FIXME: precedence
      prec(
        1,
        choice(
          seq(
            field("function", $.identifier),
            "(",
            optional(alias($._keyword_distinct, $.distinct)),
            field(
              "argument",
              commaSep1(choice($._expression, $.asterisk_expression)),
            ),
            optional(
              seq(optional(choice(kw("IGNORE", "RESPECT"))), kw("NULLS")),
            ),
            optional($.order_by_clause),
            optional($.limit_clause),
            ")",
            optional($.analytics_clause),
          ),
          seq(
            field(
              "function",
              choice(
                $.identifier,
                alias(
                  choice(
                    $._keyword_date,
                    kw("TIME"),
                    kw("DATETIME"),
                    kw("TIMESTAMP"),
                  ),
                  $.identifier,
                ),
              ),
            ),
            "(",
            optional(
              field(
                "argument",
                commaSep1(choice($._expression, $.asterisk_expression)),
              ),
            ),
            ")",
          ),
          // EXTRACT
          seq(
            field("function", alias(kw("EXTRACT"), $.identifier)),
            "(",
            alias($._unquoted_identifier, $.datetime_part),
            $._keyword_from,
            $._expression,
            ")",
          ),
          // Special case for ARRAY
          seq(
            field("function", kw("ARRAY")),
            $.select_subexpression,
          ),
        ),
      ),

    unnest_operator: ($) =>
      choice(
        seq(kw("UNNEST"), "(", $._expression, ")"),
      ),
    unnest_clause: ($) =>
      prec.right(
        50,
        seq(
          $.unnest_operator,
          optional($.as_alias),
          optional($.unnest_withoffset),
        ),
      ),
    unnest_withoffset: ($) =>
      prec.left(
        2,
        seq(kw("WITH OFFSET"), optional(seq($._keyword_as, $._identifier))),
      ),

    /* *******************************************************************
     *                           Literals
     * ********************************************************************/
    _literal: ($) =>
      choice(
        $.system_variable,
        $.query_parameter,
        $.array,
        $.struct,
        $.interval,
        $.time,
        $.string,
        $.TRUE,
        $.FALSE,
        $.NULL,
        $.number,
      ),
    NULL: (_) => kw("NULL"),
    TRUE: (_) => kw("TRUE"),
    FALSE: (_) => kw("FALSE"),
    _integer: (_) => /[-+]?\d+/,
    _float: ($) =>
      choice(
        /[-+]?\d+\.(\d*)([eE][+-]?\d+)?/,
        /(\d+)?\.\d+([eE][+-]?\d+)?/,
        /\d+[eE][+-]?\d+/,
      ),
    _float_or_integer: ($) => choice($._integer, $._float),
    numeric: ($) =>
      seq(
        choice(
          kw("NUMERIC"),
          kw("BIGNUMERIC"),
          kw("DECIMAL"),
          kw("BIGDECIMAL"),
        ),
        choice(
          seq("'", $._float_or_integer, "'"),
          seq('"', $._float_or_integer, '"'),
        ),
      ),
    _number: ($) => choice($._integer, $._float, $.numeric),
    interval: ($) =>
      seq(
        kw("INTERVAL"),
        $._expression,
        alias($._unquoted_identifier, $.datetime_part),
        optional(seq(kw("TO"), alias($._unquoted_identifier, $.datetime_part))),
      ),
    time: ($) =>
      seq(
        choice($._keyword_date, kw("TIME"), kw("DATETIME"), kw("TIMESTAMP")),
        $.string,
      ),
    number: ($) => $._number,

    system_variable: () => /@@[_a-zA-Z][._a-zA-Z0-9]*/,
    query_parameter: ($) =>
      choice($._named_query_parameter, $._positional_query_parameter),
    _named_query_parameter: (_) => /@+[_a-zA-Z][_a-zA-Z0-9]*/,
    _positional_query_parameter: (_) => /\?/,

    type: ($) => $._bqtype,
    _bqtype: ($) => choice($._type_struct, $._type_array, $._base_type),
    _type_struct: ($) =>
      seq(
        $._keyword_struct,
        optional(
          seq(
            "<",
            commaSep1(
              seq(
                optional($._identifier),
                $._bqtype,
              ),
            ),
            ">",
          ),
        ),
      ),
    _type_array: ($) =>
      seq(
        kw("ARRAY"),
        optional(seq("<", $._bqtype, ">")),
      ),
    array: ($) =>
      seq(
        optional($._type_array),
        "[",
        optional(commaSep1($._expression)),
        "]",
      ),

    struct: ($) =>
      seq(
        optional($._type_struct),
        "(",
        commaSep1($._aliasable_expression),
        ")",
      ),
    _unquoted_identifier: unquoted_identifier,
    _quoted_identifier: quoted_identifier,
    _identifier: ($) => choice($._quoted_identifier, $._unquoted_identifier),
    _dotted_identifier: ($) => seq($._identifier, token.immediate(".")),
    identifier: ($) =>
      prec.right(seq(repeat($._dotted_identifier), $._identifier)),
    _base_type: ($) =>
      prec.left(seq($._unquoted_identifier, optional(seq("(", $.number, ")")))),
    string: ($) =>
      seq(
        $._string_start,
        repeat($._string_content),
        $._string_end,
      ),
    ordered_expression: ($) => seq($._expression, $._direction_keywords),

    // http://stackoverflow.com/questions/13014947/regex-to-match-a-c-style-multiline-comment/36328890#36328890
    comment: ($) =>
      token(
        choice(
          seq("#", /.*/),
          seq("--", /.*/),
          seq("/*", /[^*]*\*+([^/*][^*]*\*+)*/, "/"),
        ),
      ),

    /* *******************************************************************
     *                           Operators
     * ********************************************************************/
    _expression: ($) =>
      choice(
        $.unary_expression,
        $.between_operator,
        $.casewhen_expression,
        $.function_call,
        $._literal,
        $.identifier,
        $.unnest_clause,
        $._parenthesized_expression,
        $.binary_expression,
        $.array_element_access,
        $.argument_reference,
        $.select_subexpression,
        $.cast_expression,
      ),

    _parenthesized_expression: ($) =>
      prec("unary_exp", seq("(", $._expression, ")")),
    array_element_access: ($) =>
      seq(choice($.identifier, $.argument_reference), "[", $._expression, "]"),

    unary_expression: ($) =>
      choice(
        prec.left(
          "unary_not",
          seq(field("operator", $._keyword_not), field("value", $._expression)),
        ),
        prec.left(
          "unary_exp",
          seq(field("operator", choice(...unary_operators)), $._expression),
        ),
        prec.left(
          "unary_exp",
          seq(field("operator", kw("EXISTS")), $.select_subexpression),
        ),
        prec.left(
          "operator_compare",
          seq(
            $._expression,
            $._keyword_is,
            optional($._keyword_not),
            choice($.NULL, $.TRUE, $.FALSE),
          ),
        ),
      ),
    binary_expression: ($) => {
      const table = [
        ["binary_times", choice(...multiplicative_operators)],
        ["binary_plus", choice(...additive_operators)],
        ["operator_compare", choice(...comparative_operators)],
        ["binary_bitwise_shift", choice(...shift_operators)],
        ["binary_bitwise_and", "&"],
        ["binary_bitwise_xor", "^"],
        ["binary_bitwise_or", "|"],
        ["binary_and", $._keyword_and],
        ["binary_or", $._keyword_or],
        ["operator_compare", seq(optional($._keyword_not), $._keyword_in)],
        ["operator_compare", seq(optional($._keyword_not), $._keyword_like)],
        [
          "operator_compare",
          seq($._keyword_is, optional($._keyword_not), kw("DISTINCT FROM")),
        ],
      ];

      return choice(
        ...table.map(([precedence, operator]) =>
          prec.left(
            precedence,
            seq(
              field("left", $._expression),
              field("operator", operator),
              field("right", $._expression),
            ),
          )
        ),
      );
    },
    between_operator: ($) =>
      prec.left(
        "operator_compare",
        seq(
          field("exp", $._expression),
          optional($._keyword_not),
          $._keyword_between,
          field("from", alias($._expression, $.between_from)),
          $._keyword_and,
          field("to", alias($._expression, $.between_to)),
        ),
      ),
    casewhen_expression: ($) =>
      prec.left(
        "clause_connective",
        seq(
          $._keyword_case,
          optional(field("expr", $._expression)),
          repeat1($.casewhen_clause),
          optional($.caseelse_clause),
          $._keyword_end,
        ),
      ),
    casewhen_clause: ($) =>
      seq(
        $._keyword_when,
        field("match_condition", $._expression),
        $._keyword_then,
        field("match_result", $._expression),
      ),
    caseelse_clause: ($) =>
      seq($._keyword_else, field("else_result", $._expression)),
    cast_expression: ($) =>
      prec.right(
        10,
        seq(
          $._keyword_cast,
          "(",
          $._expression,
          $._keyword_as,
          alias($._bqtype, $.type_identifier),
          optional($.cast_format_clause),
          ")",
        ),
      ),
    cast_format_clause: ($) =>
      seq($._keyword_format, field("format_type", $.string)),
    asterisk_expression: ($) => seq(optional($._dotted_identifier), "*"),
    argument_reference: () => seq("$", /\d+/),
  },
});

// Generate case insentitive match for SQL keyword
// In case of multiple word keyword provide a seq matcher
function kw(keyword) {
  if (keyword.toUpperCase() != keyword) {
    throw new Error(`Expected upper case keyword got ${keyword}`);
  }
  const words = keyword.split(" ");
  const regExps = words.map(createCaseInsensitiveRegex);

  if (regExps.length == 1) {
    return alias(regExps[0], keyword);
  } else {
    return alias(seq(...regExps), keyword.replace(/ /g, "_"));
  }
}

function createCaseInsensitiveRegex(word) {
  return new RegExp(
    word
      .split("")
      .map((letter) => `[${letter}${letter.toUpperCase()}]`)
      .join(""),
  );
}

function commaSep1(rule) {
  return sep1(rule, ",");
}

function sep1(rule, separator) {
  return seq(rule, repeat(seq(separator, rule)));
}
