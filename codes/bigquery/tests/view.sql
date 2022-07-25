with datasource as (
  select v.* from unnest([
    struct(1 as id, 'one' as name)
    , struct(2 as id, 'two' as name)
    , struct(3 as id, 'three' as name)
    , struct(3 as id, 'three' as name)
  ]) as v
)
, _validation as (
  with uniqueness as (
    select
      "#1 Uniquness" as title
      , format("%s should be unique. count=%d", unique_key, count(1)) as message
      , 1 = count(1) as assertion
    from datasource
    left join unnest([struct(
       format('%t', (id)) as unique_key
    )])
    group by unique_key
  )

  , test as (
    select as struct
      title
      , string_agg(distinct message, '\n') as error
    from (
      select * from uniqueness
    )
    where not assertion
    group by title
  )

  select as value
    if(
      count(error) > 0
      , error(format('Failed: %s', string_agg(error, ',' limit 10)))
      , true
    ) as errors
  from test
  where error is not null
)

select
  datasource.*
from datasource, _validation
where
  _validation
