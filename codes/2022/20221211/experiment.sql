DECLARE destination STRUCT<project_id STRING, dataset_id STRING, table_id STRING> DEFAULT NULL;
DECLARE update_job STRUCT<unique_key STRING, query STRING, snapshot_timestamp TIMESTAMP> DEFAULT NULL;
DECLARE options JSON DEFAULT NULL;

begin
  declare scale int64 default 5;
  declare buckets int64 default cast(pow(10, scale) as int64);
  declare plots array<int64> default
    array(select cast(pow(10, s) as int64) from unnest(generate_array(0, scale -1)) as s)
    || [cast(buckets/2 as int64)]
    || array(select cast(pow(10, scale) - pow(10, s) as int64) from unnest(generate_array(0, scale - 1)) as s)
    ;
  declare n_data int64 default 1000000;
  declare n_sample int64 default 10;

  create or replace temp table `experiment`
  as
  with
    uniform as (
      select
        v2 as sample_ix
        , rand() as r
      from
        unnest(generate_array(1, n_data)) as v
        , unnest(generate_array(1, n_sample)) as v2
    )
    , normal_dist as (
      select
        v2 as sample_ix
        -- normal distribution: box-muller
        , sqrt(-2 * ln(rand())) * cos(rand() * 4 * atan(1.0)) as r
      from
        unnest(generate_array(1, n_data)) as v
        , unnest(generate_array(1, n_sample)) as v2

    )
    , heavy_tailed as (
      select
        v2 as sample_ix
        -- normal distribution: box-muller
        , POWER((-1. / 1.5) * LOG(1. - rand()), 1./0.1)
        as r
      from
        unnest(generate_array(1, n_data)) as v
        , unnest(generate_array(1, n_sample)) as v2
    )

    , experimented as (
      with datasource as (
        select 'heavytail' as label, * from heavy_tailed
        union all
        select 'normal', * from normal_dist
        union all
        select 'uniform', * from uniform
      )
      , groundtruth as (
        with calc as (
          select
            label, sample_ix
            , percent_rank() over (partition by label, sample_ix order by r) * buckets as prank
            , r
          from datasource
        )
        select
          label, sample_ix
          , cast(round(prank, 0) as int64) as qtile
          , min(r) as min
          , max(r) as max
          , (max(r) + min(r)) / 2 as mid
        from calc
        group by label, sample_ix, qtile
      )
      , approximate as (
        select
          label, sample_ix
          , approx_quantiles(r, buckets) as value
        from datasource
        group by label, sample_ix
      )

      select
        groundtruth, round(approx, 2) as approx, round((approx - mid), 3) as err_abs, round((approx - mid) / mid, 3) as err_rel
      from approximate as A
      left join unnest(A.value) as approx with offset qtile
      left join groundtruth using(label, sample_ix, qtile)
      where qtile in unnest(plots)
      order by qtile
    )

  select
    groundtruth.label
    , to_json(struct(scale, n_data, n_sample)) as config
    , groundtruth.qtile / buckets as qtile
    , round(any_value(groundtruth.mid), 2) as groundtruth
    , round(avg(approx), 2) as approx
    , struct(
      round(avg(err_abs), 3) as avg
      , round(stddev(err_abs), 3) as stddev
    ) as err_abs
    , struct(
      round(avg(err_rel), 3) as avg
      , round(stddev(err_rel), 3) as stddev
    ) as err_rel
  from experimented
  group by label, qtile
  order by label
  ;

  call `bqmake.v0.snapshot_table__update`(
    ("project-id-7288898082930342315", "expreriments", "approx_quantile_data")
    , []
    , (
      "format('%T', (label, config, qtile))"
      , `bqmake.v0.zgensql__snapshot_partial`(
        ("project-id-7288898082930342315", "expreriments", "approx_quantile_data")
        , "select * from experiment"
        ,"format('%T', (label, config, qtile))"
      )
      , current_timestamp()
    )
    , to_json(struct(
      current_timestamp() as force_expired_at
    ))
  );

end;
