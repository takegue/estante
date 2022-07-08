-- declare destination struct<
--     project_id string
--     , dataset_id string
--     , table_id string
--   >
--   ;
-- declare sources array<struct<
--     project_id string
--     , dataset_id string
--     , table_id string
--   >>
-- ;
-- declare alignemnts array<struct<
--     destination string
--     , sources array<string>
--   >>;
-- declare ret struct<begins_at date, ends_at date>;

-- set destination = (null, 'sandbox', "test_partition4");
-- set sources = [("bigquery-public-data", "ga4_obfuscated_sample_ecommerce", "events_*")];
-- set alignemnts = [("20220101", ["20210101", "20210102", "20210103"])];

create or replace procedure `fn.extract_staled_partitions`(
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
  , options struct<
    max_delay interval
  >
  , out ret struct<begins_at date, ends_at date>
)
begin
  -- Prepare metadata from  INFOMARTION_SCHEMA.PARTITIONS
  execute immediate (
    select as value
      "create or replace temp table `_partitions_temp` as "
      || string_agg(
        format("""
          select '%s' as label, '%s' as argument,  *
          from `%s.%s.INFORMATION_SCHEMA.PARTITIONS`
          where %s
          """
          , label
          , target.table_id
          , ifnull(target.project_id, @@project_id), target.dataset_id
          , format(if(
            contains_substr(target.table_id, '*')
            , 'starts_with(table_name, replace("%s", "*", ""))'
            , 'table_name = "%s"'
            )
            , target.table_id)
        )
        , '\nunion all'
      )
    from unnest([
      struct('destination' as label, destination as target)
    ] || array(select as struct 'source', s from unnest(sources) s)
    )
  )
  ;

  -- alignment and extract staled partition
  set ret = (
    with
    pseudo_partition as (
      SELECT
        * replace(
          coalesce(
            partition_id
            , if(has_wildcard, regexp_replace(table_name, format('^%s', pattern), ''), null)
            , format_date('%Y%m%d', _pseudo_date)
          )
          as partition_id
        )
        , struct(partition_id, PARSE_DATE('%Y%m%d', partition_id) as partition_date, table_catalog, table_schema, table_name, last_modified_time)
          as alignment_paylod
      from _partitions_temp
      left join unnest([struct(
        contains_substr(argument, '*') as has_wildcard
        , regexp_replace(argument, r'\*$', '') as pattern
      )])
      left join unnest(
        if(partition_id is not null or has_wildcard
        , []
        , generate_date_array('2020-01-01', '2022-01-01'))
      ) as _pseudo_date
      where
        table_name = argument or starts_with(table_name, pattern)
    )
    , argument_alignment as (
      select a.destination as partition_id, source as source_partition_id from unnest(partition_alignments) a, unnest(a.sources) as source
    )
    , aligned as (
      select
        destination.alignment_paylod as destination
        , source.alignment_paylod as source
      from
        (select * from pseudo_partition where label = 'destination') as destination
      join argument_alignment using(partition_id)
      left join
        (select * from pseudo_partition where label = 'source') as source
        on source_partition_id = source.partition_id
    )

    select as struct
      min(destination.partition_date), max(destination.partition_date)
    from aligned
    where destination.last_modified_time <= source.last_modified_time
  );
end;

-- call `fn.extract_staled_partitions`(destination, sources, alignemnts, null, ret);
-- select ret;
