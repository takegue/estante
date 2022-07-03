create or replace procedure `fn.get_query_referenced_tables`(
  in query string
  , out ret array<struct<project_id string, dataset_id string, table_id string>>
)
options(
  description='''Get referenced tables from query

Arguments
=====
  - query: a query to be analyzed. Recommended to use no-scan bytes query or query raising error to avoid billing.
  - ret: return value. referenced_tables
  '''
)
begin
  declare last_job_id string;
  begin
    execute immediate query;
  exception when error then
  end;
  set last_job_id = @@last_job_id;

  set ret = (
    select as value
      if(
        cache_hit
        , error("Inproper reference due to cache_hit=true. Avoid to use query cached. Referer https://cloud.google.com/bigquery/docs/cached-results#cache-exceptions")
        , referenced_tables
      )
    from `region-us.INFORMATION_SCHEMA.JOBS_BY_USER`
    where

      job_id = last_job_id
      and date(creation_time) = current_date()
    order by start_time desc
  );

end
