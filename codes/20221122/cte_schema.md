CTEのスキーマを取得するためのSQL

```
declare query string default """
with A as (
  select * from `bqmake.bqtest.demo_sample_table` LIMIT 1000
)
, B as (
  select count(1) as total_record from A
)
, C as (
  select as struct
    status
    , approx_count_distinct(unique_key) as hll_unique
    , approx_top_count(unique_key, 10) as top10cnt
  from A group by status
)
, final as (
  select
    C
    , (select * from B) as B
  from C
)

select * from final
""";

create schema if not exists `zztemp_query`;
for cte_view in (
  select
    cte_name as name
    , rtrim(left(
      query
      , `bqmake.bqtest.zfind_final_select`(query)
    ))
      || format('\nselect * from `%s`', cte_name)
    as query
  from unnest(`bqmake.bqtest.zfind_ctes`(query)) as cte_name
)
do
  execute immediate format("create or replace view `%s.%s` as %s", "zztemp_query", cte_view.name, cte_view.query);
end for;

SELECT
  table_name as cte_names
  , array_agg(struct(
    column_name
    , data_type
    , is_nullable
    , is_partitioning_column
    , ordinal_position
  ) order by ordinal_position
  )
FROM `project-id-7288898082930342315.zztemp_query.INFORMATION_SCHEMA.COLUMNS`
GROUP BY table_name
```
