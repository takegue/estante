with
  datasource as (
    select *, struct(source) as data from `bigquery-public-data.austin_bikeshare.bikeshare_stations` source
  )
  , check__dbtlike as (
    select
      unique_check_column.name
      , count(1) as count
      , struct(
        count(distinct key)
        , approx_count_distinct(key)
        , approx_top_count(key, 10)
      ) as unique
      , struct(
        countif(key is not null) as value
      ) as nonnull
      , struct(
        hll_count.init(key) as hll
      ) as acceptable
      , struct(
        countif(station_id in (select start_station_id from `bigquery-public-data.austin_bikeshare.bikeshare_trips`))
      ) as relation_ship
    from datasource
    left join unnest([
      struct("station_id" as name, station_id as key)
      -- add columns here
    ]) as unique_check_column
    group by unique_check_column.name
  )

select * from check__dbt
