with datasource as (
  select
    metadata.`@type` as type
    , c.timestamp
    , resource
    , protopayload_auditlog.servicedata_v1_bigquery.jobCompletedEvent
    , JSON_VALUE_ARRAY(metadata.tableDataRead.fields) as fields
    , string(metadata.tableDataRead.jobName) as jobName
  from `bqmake._auditlog.cloudaudit_googleapis_com_data_access` as c
  left join unnest([struct(
    safe.parse_json(protopayload_auditlog.metadataJson) as metadata
  )])
  where
    date(timestamp) >= date(current_date() - interval 1 day)
)
, tableReadData as (
  select regexp_extract(jobName, '[^/]+$') as jobId, to_json_string(fields) as fields from datasource
  where resource.type = 'bigquery_dataset'
)
, jobCompleteEvent as (
  select
    timestamp
    , jobCompletedEvent.job.jobName.jobId as jobId
    , struct(
       jobCompletedEvent.job.jobConfiguration as config
       , jobCompletedEvent.job.jobStatistics as statistics
    ) as job
    , jobCompletedEvent as _raw
  from datasource
  where jobCompletedEvent.eventName = 'query_job_completed'
)

select *
from jobCompleteEvent
left join tableReadData using(jobId)
order by timestamp desc
