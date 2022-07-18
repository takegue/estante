create or replace procedure `fn.extract_staled_partitions`(
  out ret array<string>
  , destination struct<
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
    tolerate_delay interval
  >
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
    -- partition_id -> (null, null) -> ('__NULL__', '__NULL__')
    -- partition_id -> (null, date) -> (_pseudo_date, date)
    -- partition_id -> (date, null) -> (date, _pseudo_date)
    -- partition_id -> (date, date) -> (date, date)

    with
    pseudo_partition as (
      SELECT
        label
        , coalesce(
            partition_id
            , if(has_wildcard, regexp_replace(table_name, format('^%s', pattern), ''), null)
            , format_date('%Y%m%d', _pseudo_date)
            , '__NULL__'
          )
          as partition_id
        , struct(partition_id, table_catalog, table_schema, table_name, last_modified_time)
          as alignment_paylod
      from _partitions_temp
      left join unnest([struct(
        contains_substr(argument, '*') as has_wildcard
        , regexp_replace(argument, r'\*$', '') as pattern
      )])
      left join unnest(
        if(
          partition_id is not null or has_wildcard
          , []
          , (
            select as value
              generate_date_array(
                min(safe.parse_date('%Y%m%d', least(d, s)))
                , max(safe.parse_date('%Y%m%d', greatest(d, s)))
              )
            from unnest(partition_alignments) a
            left join unnest(a.sources) src
            left join unnest([struct(
              nullif(a.destination, '__NULL__') as d
              , nullif(src, '__NULL__') as s
            )])
          )
        )
      ) as _pseudo_date
      where
        table_name = argument or starts_with(table_name, pattern)
    )
    , argument_alignment as (
      select a.destination as partition_id, source as source_partition_id
      from unnest(partition_alignments) a, unnest(a.sources) as source
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

    select
      array_agg(distinct partition_id order by partition_id)
    from aligned
    left join unnest([ifnull(destination.partition_id, '__NULL__')]) as partition_id
    where
      destination.last_modified_time <= source.last_modified_time - options.tolerate_delay
      -- Resolve partition delays enough after tolerate delay goes
      or (
        destination.last_modified_time <= source.last_modified_time
        and destination.last_modified_time <= current_timestamp() - options.tolerate_delay
      )
  );
end;