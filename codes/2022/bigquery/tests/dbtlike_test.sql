with
  datasource as (
    select * from `bigquery-public-data.austin_311.311_service_requests`
  )
  , __test__datasource as (
    -- DBT-Like validation
    with uniqueness_check as (
      with unique_count as (
        select any_value(_uniqueness_target) as tgt, count(1) as actual
        from datasource
        left join unnest([
          struct(
            'unique_key' as _key
            , format('%t', unique_key) as _value
          )
        ]) as _uniqueness_target
        group by format('%t', _uniqueness_target)
      )
      select
        format("Uniqueness check: %s=%s", tgt._key, tgt._value) as name
        , actual
        , 1 as expected
      from unique_count
    )
    , nonnull_check as (
      with unique_count as (
        select
          any_value(_uniqueness_target) as tgt
          , countif(nullif(_uniqueness_target._value, 'NULL') is null) as actual
        from datasource
        left join unnest([
          struct(
            'source' as _key
            , format('%T', source) as _value
          )
          , struct(
            'status' as _key
            , format('%T', status) as _value
          )
          , struct(
            'incident_address' as _key
            , format('%T', incident_address) as _value
          )
        ]) as _uniqueness_target
        group by _uniqueness_target._key
      )
      select
        format("Non-null check: %s", tgt._key) as name
        , actual
        , 0 as expected
      from unique_count
    )
    , accepted_values_check as (
      with stats as (
        select
          any_value(_uniqueness_target.spec) as spec
          , approx_top_count(nullif(_uniqueness_target._value, 'NULL'), 100) as actual
        from datasource
        left join unnest([
          struct(
            struct(
              'source' as _key
              , cast(null as array<string>) as _expected
            ) as spec
            , format('%T', source) as _value
          )
          , struct(
            struct(
              'status' as _key
              , ["Closed", "Duplicate (closed)", "Closed -Incomplete"] as _expected
            ) as spec
            , format('%T', status) as _value
          )
        ]) as _uniqueness_target
        group by format('%t', _uniqueness_target.spec)
      )
      select
        format("Pattern check: %s", spec._key) as name
        , array(select value from unnest(stats.actual) order by value) as actual
        , array(select format('%T', value) from unnest(spec._expected) as value order by value) as expected
      from stats
    )
    , report as (
      with all_testcases as (
        select 'uniqueness_check' as group_name, name, format('%T', actual) as actual, format('%T', expected) as expected from uniqueness_check
        union all
        select 'nonnull_check' as group_name, name, format('%T', actual) as actual, format('%T', expected) as expected from nonnull_check
        union all
        select 'accepted_values_check' as group_name, name, format('%T', actual) as actual, format('%T', expected) as expected from accepted_values_check
      )
      select
        group_name
        , count(1) as n_cases
        , countif(actual = expected) as n_cases_passed
        , countif(actual != expected) as n_cases_failed
        , approx_top_sum(
            if(
              actual = expected
              , null
              , format('%s; Expected %t but actual is %t', name, expected, actual)
            )
            , if(actual = expected, null, 1)
            , 20
        ) as errors
      from all_testcases
      group by group_name
    )

    select * from report
  )


select * from __test__datasource
