create or replace procedure `fn.generate_sql_scd_type4`(
  out ret struct<snapshot_query string, recover_query string>
  , in destination struct<project string, dataset string, table string>
  , in unique_key string
  , in options array<struct<key string, value string>>
)
begin
  declare dataset_ref string default format(
    '%s.%s'
    , coalesce(destination.project, @@project_id)
    , ifnull(destination.dataset, error('Not found dataset'))
  );

  execute immediate format("""
    create or replace temp table _tmp_table_columns
    as
      select
        table_catalog, table_schema, table_name, column_name
        , field_path
        , ordinal_position as position
        , path.data_type
        , starts_with(c.data_type, 'ARRAY') as is_under_array
      from `%s.INFORMATION_SCHEMA.COLUMNS` c
      left join `%s.INFORMATION_SCHEMA.COLUMN_FIELD_PATHS` as path
        using(table_catalog, table_schema, table_name, column_name)
      where
        table_name = '%s'
  """
    , dataset_ref
    , dataset_ref
    , destination.table
  )
  ;

  set ret = (
    with
      ddl as (
      select
        table_catalog, table_schema, table_name
        , format("""
          with version_hash as (
            select as value
              generate_uuid() as version_hash
          )
            -- template
            select
              %s
              , c.column_name
              , c.column_type
              , version_hash as version_hash
              , current_timestamp() as valid_from
              , timestamp(null) as valid_to
              , c.column_value
            from
              `%s.%s`
              , version_hash
            left join unnest([
              struct(
                "_name" as column_name, "_type" as column_type
                -- support data types
                , struct(
                    string(null) as string
                    , to_json(null) as json
                    , null as int64
                    , cast(null as bignumeric) as bignumeric
                    , float64(null) as float64
                    , cast(null as bytes) as bytes
                    , bool(null) as bool
                    , time(null) as time
                    , date(null) as date
                    , datetime(null) as datetime
                    , timestamp(null) as timestamp
                  ) as column_value)
              -- template vairables
              , %s
            ]) as c
            where
              c.column_name != '_name'
          """
          , unique_key
          , dataset_ref
          , table_name
          , string_agg(
              format('("%s", "%s", (%s))'
                , column_name
                , data_type
                , array_to_string([
                    if(data_type = "STRING", field_path, "null")
                    , if(data_type = "JSON", field_path, "null")
                    , if(data_type = "INT64", field_path, "null")
                    , if(data_type = "BIGNUMERIC", field_path, "null")
                    , if(data_type = "FLOAT64", field_path, "null")
                    , if(data_type = "BYTES", field_path, "null")
                    , if(data_type = "BOOL", field_path, "null")
                    , if(data_type = "TIME", field_path, "null")
                    , if(data_type = "DATE", field_path, "null")
                    , if(data_type = "DATETIME", field_path, "null")
                    , if(data_type = "TIMESTAMP", field_path, "null")
                ]
                , ", "
            ))
            , "\n        , "
          )
        ) as snapshot_query
        , format("""
          select
            %s as unique_key
            , %s
          from `%%s.%%s.%%s`
          where
            valid_to is null
          group by unique_key
        """
          , unique_key
          , string_agg(
            format(", max(if(column_name = '%s', column_value.%s, null)) as %s", field_path, lower(data_type), field_path)
            , '\n'
          )
        ) as recover_query
      from _tmp_table_columns
      where
        -- Filter unsuported types
        not is_under_array
        and not starts_with(data_type, 'STRUCT')
      group by table_catalog, table_schema, table_name
    )

    select as struct snapshot_query, recover_query from ddl
  );
end;
