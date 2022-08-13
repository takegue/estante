create or replace procedure `fn.create_or_update_snapshot_table`(
  destination struct<
    project_id string
    , dataset_id string
    , table_id string
  >
  , source struct<
    project_id string
    , dataset_id string
    , table_id string
  >
  , exp_unique_key string
  , scd_type string
)
begin
  declare snapshot_query string;
  declare destination_ref string default ifnull(format('%s.%s.%s',
      coalesce(destination.project_id, @@project_id)
      , destination.dataset_id
      , destination.table_id
    ), error(format("Invalid Destination: %t", destination)));
  declare source_ref string default ifnull(format('%s.%s.%s',
      coalesce(source.project_id, @@project_id)
      , source.dataset_id
      , source.table_id
  ), error(format("Invalid Source: %t", source)));
  declare snapshot_at timestamp default current_timestamp();
  declare stale_partitions array<string>;
  declare source_dependencies array<struct<project_id string, dataset_id string, table_id string>>;
  declare _past_processed int64;

  set snapshot_query = ifnull(
  format("""
      -- Snapshot Templated Query
      select
        %s as unique_key
        , version_hash
        , @timestamp as valid_from
        , timestamp(null) as valid_to
        , entity
      from
        `%s` as entity
        , (select as value generate_uuid()) as version_hash
      """
      , exp_unique_key
      , source_ref
    )
    , error(format("Invalid argument: %t", source))
  );

  -- Checked referenced tables
  call `fn.get_query_referenced_tables`(
    source_dependencies
    , format("select error('intended') from `%s` limit 1", source_ref)
    , null
  );

  call `fn.extract_stale_partitions`(
    stale_partitions
    , destination
    , source_dependencies
    , [('__NULL__', ['__NULL__'])]
    , null
  );

  if ifnull(array_length(stale_partitions), 0) = 0 then
    return;
  end if;

  set snapshot_at = current_timestamp();
  set _past_processed = @@script.bytes_processed;

  execute immediate format("""
    create table if not exists `%s`
    partition by DATE(valid_to)
    cluster by unique_key
    as %s
  """
    , destination_ref
    , snapshot_query
  )
    using snapshot_at as timestamp;

  -- If Table is created, early return
  if @@script.bytes_processed - _past_processed > 100 then
    return;
  end if
  ;

  execute immediate format("""
    merge `%s` T
    using
      (
        %s
      ) as S
    on
      T.valid_to is null
      and S.unique_key = T.unique_key
      and format('%%t', S.entity) = format('%%t', T.entity)
    -- Insert new records changed
    when not matched then
      insert row
    -- Deprecate old records changed
    when
      not matched by source
      and T.valid_to is null then
        update set
          valid_to = @timestamp
  """
    , destination_ref
    , snapshot_query
  )
    using snapshot_at as timestamp;

end
