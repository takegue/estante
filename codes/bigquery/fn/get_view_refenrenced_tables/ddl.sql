declare ret array<struct<project_id string, dataset_id string, table_id string>>;

create or replace procedure `fn.get_view_referenced_tables`(
  in target struct<
    project_id string
    , dataset_id string
    , table_id string
  >
  , out ret array<struct<project_id string, dataset_id string, table_id string>>
)
begin
  execute immediate format(
    r"select 1 from `%s.%s.%s` limit 0"
    , ifnull(target.project_id, @@project_id), target.dataset_id, target.table_id
  );

  set ret = (
    select as value
      referenced_tables
    from `region-us.INFORMATION_SCHEMA.JOBS_BY_USER`
    where job_id = @@last_job_id
    and date(creation_time) = current_date()
    order by start_time desc
    limit 1
  );
end
;

-- Test
call `fn.get_view_referenced_tables`(
  ("bigquery-public-data", "google_analytics_sample", 'ga_sessions*'), ret);
select ret;
