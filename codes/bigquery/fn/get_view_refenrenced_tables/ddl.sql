declare ret array<struct<project_id string, dataset_id string, table_id string>>;

create or replace procedure `fn.get_view_referenced_tables`(
  out ret array<struct<project_id string, dataset_id string, table_id string>>
  , in target struct<
    project_id string
    , dataset_id string
    , table_id string
  >
)
begin
  call get_referenced_tables(
    ret,
    format(
      r"select 1 from `%s.%s.%s` limit 0"
      , ifnull(target.project_id, @@project_id), target.dataset_id, target.table_id
    )
  );
end
;

-- Test
call `fn.get_view_referenced_tables`(
  ret
  , ("bigquery-public-data", "google_analytics_sample", 'ga_sessions*'));
select ret;
