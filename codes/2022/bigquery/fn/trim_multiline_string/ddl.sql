create or replace function `fn.trim_multiline_string`(s string)
returns string
as
((
  select as value
    string_agg(nullif(trim(line), ''), '\n')
  from unnest(split(s, '\n')) line
))
