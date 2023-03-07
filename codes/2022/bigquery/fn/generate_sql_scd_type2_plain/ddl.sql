create or replace procedure `fn.generate_sql_scd_type2_plain`(
  out ret struct<
    ddl string
   , dml string
  >
  , destination struct<
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
)
begin
  declare snapshot_query, destination_ref, source_ref string;

  set (destination_ref, source_ref) = (
    ifnull(
      format(
        '%s.%s.%s'
        , coalesce(destination.project_id, @@project_id)
        , destination.dataset_id
        , destination.table_id
      ), error(format("Invalid Destination: %t", destination))
    )
    , ifnull(
      format(
        '%s.%s.%s',
        coalesce(source.project_id, @@project_id)
        , source.dataset_id
        , source.table_id
      ), error(format("Invalid Source: %t", source)))
  );

  set snapshot_query = ifnull(
    format("""
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

  set ret = (
    -- DDL Query
    format("""
        create table if not exists `%s`
        partition by DATE(valid_to)
        cluster by unique_key
        as %s
      """
      , destination_ref
      , snapshot_query
    ) as create_ddl
    -- DML Query
    , format("""
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
    ) as update_dml
    -- TVF DDL for Access
    , format("""
        create or replace table function `%s`(_at timestamp)
        as
          select * from `%s`
        where
          ifnull(
            valid_from <= `_at` and `_at` < valid_to
            , valid_to is null
          )
      """
      , destination_ref
    ) as access_tvf_ddl
  );

end
