with recursive lineage as (
  select
    format('%s.%s.%s', dst_project, dst_dataset, dst_table) as destination
    , 0 as depth
    , relations.*
  from relations
  union all
  select
    destination
    , depth + 1 as depth
    , relations.*
  from lineage
    join relations
      on (relations.dst_project, relations.dst_dataset, relations.dst_table)
       = (lineage.src_project, lineage.src_dataset, lineage.src_table)
  where
    -- FIXME: surpress duplicate join
    depth < 5
)
, job as (
  select
    job_id
    , user_email
    , creation_time
    , end_time - start_time as processed_time
    , start_time - creation_time as wait_time
    , query
    , total_bytes_processed
    , total_slot_ms
    , destination_table
    , referenced_tables
  from `project-id-7288898082930342315.region-us.INFORMATION_SCHEMA.JOBS_BY_PROJECT`
  where
    destination_table.table_id is not null
    and error_result.reason is null
    and state = 'DONE'
    -- Excldue anonymous or temporarily dataset
    and not starts_with(destination_table.dataset_id, '_')
)
, relations as (
  select
    format('%t <- %t', destination_table, ref) as unique_key
    , any_value(destination_table).project_id as dst_project
    , any_value(destination_table).dataset_id as dst_dataset
    , any_value(normalized_dst_table) as dst_table
    , any_value(ref).project_id as src_project
    , any_value(ref).dataset_id as src_dataset
    , any_value(normalized_ref_table) as src_table

    , max(creation_time) as job_latest

    , approx_count_distinct(user_email) as n_user
    , approx_count_distinct(query) as n_queries
    , approx_count_distinct(job_id) as n_job
    , sum(total_bytes_processed) as total_bytes

    , approx_quantiles(processed_time_ms, 10) as processed_time__quantiles
    , approx_quantiles(wait_time_ms, 10) as wait_time__quantiles

    , sum(total_slot_ms) as total_slots_ms
    , approx_quantiles(total_slot_ms, 10) as total_slots_ms__quantiles

  from job
    left join unnest(referenced_tables) as ref
    left join unnest([struct(
      extract(millisecond from processed_time)
        + extract(second from processed_time) * 1000
        + extract(minute from processed_time) * 60 * 1000
        + extract(hour from processed_time) * 60 * 60 * 1000
      as processed_time_ms
      , extract(millisecond from wait_time)
        + extract(second from wait_time) * 1000
        + extract(minute from wait_time) * 60 * 1000
        + extract(hour from wait_time) * 60 * 60 * 1000
      as wait_time_ms
      , regexp_extract(ref.table_id, r'\d+$') as _src_suffix_number
      , regexp_extract(destination_table.table_id, r'\d+$') as _dst_suffix_number
    )])
    left join unnest([struct(
      if(safe.parse_date('%Y%m%d', _src_suffix_number) is not null, regexp_replace(ref.table_id, r'\d+$', '*'), ref.table_id) as normalized_ref_table
      , if(safe.parse_date('%Y%m%d', _dst_suffix_number) is not null, regexp_replace(destination_table.table_id, r'\d+$', '*'), destination_table.table_id) as normalized_dst_table
    )])

  group by unique_key
)

select * from lineage
