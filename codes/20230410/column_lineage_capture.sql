create or replace function `v0.zgensql__clineage_queries`(
  target_dataset struct<project_id string, dataset_id string>
  , table_names array<string>
)
as (
  replace(replace(
    """
    -- Query single column for column lineage
    with lineage_sql as (
      select as struct
        table_catalog, table_schema, table_name, field_path, vhash
        , trim(format(r"select %s from `%s.%s.%s` limit 1"
          , field_path, table_catalog, table_schema, table_name
        )) as query
      from `!METADATA_COLUMN_FILED_PATH!`
        , (select generate_uuid() as vhash)
      where
        array_length(!TABLE_NAMES!) = 0
        OR table_name in unnest(!TABLE_NAMES!)
    )
    select array_agg(c) from lineage_sql as c
    """
    , "!TABLE_NAMES!", format('%T', table_names))
    , "!METADATA_COLUMN_FILED_PATH!", format('%s.%s.INFORMATION_SCHEMA.COLUMN_FIELD_PATHS', target_dataset.project_id, target_dataset.dataset_id)
  )
);

create temp function zgensql__prepare_auditdata(
  audit_data struct<project_id string, dataset_id string, table_name string>
  , capture_interval interval
) as (
  replace(replace(r"""
    with datasource as (
      select
        metadata.`@type` as type
        , c.timestamp
        , resource
        , protopayload_auditlog.servicedata_v1_bigquery.jobCompletedEvent
        , tableDataRead
        , c as _raw
      from !AUDIT_TABLEDATA! as c
      left join unnest([struct(
        safe.parse_json(protopayload_auditlog.metadataJson) as metadata
        , protopayload_auditlog.servicedata_v1_bigquery.jobCompletedEvent
      )])
      left join unnest([struct(
        struct(
          regexp_extract(string(metadata.tableDataRead.jobName), '[^/]+$') as jobId
          , json_value_array(nullif(to_json_string(metadata.tableDataRead.fields), 'null')) as fields
        ) as tableDataRead
      )])
      where
        timestamp >= current_timestamp() - !CAPTURE_INTERVAL!
        and
        (
          (
            -- jobCompleteEvent master
            jobCompletedEvent.eventName = 'query_job_completed'
            and contains_substr(jobCompletedEvent.job.jobConfiguration.labels, 'clineage')
          )
          OR (
            -- tableDataRead event
            tableDataRead.jobId is not null
          )
        )
    )
    , tableDataRead as (
      select
        tableDataRead.jobId
        , resource.labels.dataset_id
        , resource.labels.project_id
        , tableDataRead.fields
        , to_json(datasource._raw) as _raw
      from datasource
    )
    , jobCompleteEvent as (
      select
        timestamp
        , jobCompletedEvent.job.jobName.jobId as jobId
        , struct(
          jobCompletedEvent.job.jobConfiguration as config
          , jobCompletedEvent.job.jobStatistics as statistics
        ) as job
        , to_json(jobCompletedEvent) as _raw
      from datasource
      where
        jobCompletedEvent.eventName = 'query_job_completed'
        and contains_substr(jobCompletedEvent.job.jobConfiguration.labels, 'clineage')
    )
    , fmt as (
      select
        any_value(struct(
          clienage__resource, vhash
        )).*
        , array_agg(
          struct(
            field_path as column
            , struct(
              tableDataRead.project_id
              , tableDataRead.dataset_id
              , tableDataRead.fields
            ) as lineage
            , struct(
              job.statistics.totalSlotMs
              , job.statistics.totalProcessedBytes
              , job.statistics.endTime - job.statistics.startTime as leadTime
            ) as stats
          )
        ) as column_lineage
        , struct(
          min(timestamp) as min
          , max(timestamp) as max
        ) as analyze_span
    --    , job.statistics
      from jobCompleteEvent
      left join tableDataRead using(jobId)
      left join unnest([struct(
        struct(
          `bqutil.fn.get_value`('clineage__schema',  job.config.labels) as schema
          , `bqutil.fn.get_value`('clineage__catalog',  job.config.labels) as catalog
          , `bqutil.fn.get_value`('clineage__table',  job.config.labels) as table
        ) as clienage__resource
        , replace(`bqutil.fn.get_value`('clineage__field_path',  job.config.labels), '_-_', '.') as field_path
        , `bqutil.fn.get_value`('clineage__vhash',  job.config.labels) as vhash
      )])
      group by format('%t', (clienage__resource, vhash))
      order by analyze_span.min desc
    )

    select * from fmt
  """
    , '!AUDIT_TABLEDATA!', format('`%s.%s.%s`', audit_data.project_id, audit_data.dataset_id, audit_data.table_name))
    , '!CAPTURE_INTERVAL!', format('%T', capture_interval)
  )
);

begin
  declare clineage_query array<struct<
    table_catalog STRING, table_schema STRING, table_name STRING, field_path STRING, vhash STRING, query STRING
  >>;

  execute immediate `v0.zgensql__clineage_queries`(struct("bqmake", "zgolden"), []) into clineage_query
  ;

  for r in (select * from unnest(clineage_query)) do
    set @@query_label = array_to_string(
      [
        format("clineage__catalog:%s", r.table_catalog),
        format("clineage__schema:%s", r.table_schema),
        format("clineage__table:%s", r.table_name),
        format("clineage__field_path:%s", replace(r.field_path, ".", "_-_")),
        format("clineage__vhash:c%s", r.vhash)
      ]
      , ","
    );
    execute immediate r.query;
    set @@query_label = null;
  end for
  ;

  execute immediate zgensql__prepare_auditdata(
    ("bqmake", "_auditlog", "cloudaudit_googleapis_com_data_access")
    , interval 1 hour
  );
end
;
