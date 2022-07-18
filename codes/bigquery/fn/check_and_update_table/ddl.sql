create or replace procedure `fn.check_and_update_table`(
  destination struct<
    project_id string
    , dataset_id string
    , table_id string
  >
  , sources array<struct<
    project_id string
    , dataset_id string
    , table_id string
    >>
  , partition_alignments array<struct<
    destination string
    , sources array<string>
  >>
  , update_job struct<
    query string
    , dry_run boolean
    , tolerate_delay interval
    , max_update_interval interval
    , via_temp_table boolean
  >
)
begin
  declare staled_partitions array<string>;
  declare partition_range struct<begins_at string, ends_at string>;
  declare partition_key string;

  call `fn.extract_staled_partitions`(
    staled_partitions
    , destination
    , sources
    , partition_alignments
    , struct(update_job.tolerate_delay)
  );

  if ifnull(array_length(staled_partitions), 0) = 0 then
    return;
  end if;

  set partition_range = (
    -- Extract first successive partition range to be update from staled_partitions.
    with gap as (
      select
        p
        , ifnull(
          coalesce(
            datetime_diff(lag(partition_hour) over (order by partition_hour desc), partition_hour, hour) > 1
            , date_diff(lag(partition_date) over (order by partition_date desc), partition_date, day) > 1
            , (lag(partition_int) over (order by partition_int desc) - partition_int) > 1
          )
          -- null or __NULL__
          , true
        ) as has_gap
      from unnest(staled_partitions) p
      left join unnest([struct(
        safe.parse_date('%Y%m%d', p) as partition_date
        , safe.parse_datetime('%Y%m%d%h', p) as partition_hour
        , safe_cast(p as int64) as partition_int
      )])
    )
    , first_successive_partitions as (
      select * from gap
      qualify sum(if(has_gap, 1, 0)) over (order by p desc) = 1
    )
    select min(p), max(p) from first_successive_partitions
  );

  -- Get partition column
  call `fn.get_table_partition_column`(destination, partition_key);

  -- Run Update Job
  if update_job.dry_run then
    return;
  end if;

  if update_job.via_temp_table then
    execute immediate format("""
      create or replace temp table temp_tables
      as
        %s
      """
      , update_job.query
    ) using
      partition_range.begins_at as begins_at
      , partition_range.ends_at as ends_at
  end if;

  execute immediate ifnull(format("""
    merge into `%s` as T
      using (%s) as S
        on false
    when not matched by target
      then
        insert row
    when not matched by source
      -- partition filter
      and %s
      then
        delete
    """
      -- Destination
      , ifnull(format(
          '%s.%s.%s'
          , ifnull(destination.project_id, @@project_id)
          , destination.dataset_id
          , destination.table_id
        ), 'invalid destination'
      )
      , if(ifnull(update_job.via_temp_table, false), 'temp_table', update_job.query)
      , ifnull(format("%s between @begins_at and @ends_at", partition_key), "true")
    )
    , error(format(
      "arguments is invalud: %T", (destination, partition_key, partition_range)
    ))
  )
    using
      partition_range.begins_at as begins_at
      , partition_range.ends_at as ends_at
  ;

end;
