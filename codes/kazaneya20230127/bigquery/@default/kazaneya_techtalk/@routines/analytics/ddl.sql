create or replace table function
    `kazaneya_techtalk.analytics`(
        begins_at date,
        ends_at date,
        analytics_units struct<time string, user string, product string>
    )
as
with
    datasource as (
      select * from `kazaneya_techtalk.signal`
      where date between begins_at and ends_at
    ),
    grain as (
        select
            any_value(units) as units,
            any_value(user) as user,
            any_value(item) as item,
            struct(
                -- 型ごとに主要統計量の取り方が定まる
                -- timestamp signal
                count(1) as records,
                struct(
                    countif(signal.timestamp is not null) as nonnull,
                    min(signal.timestamp) as min,
                    max(signal.timestamp) as max
                -- identifier signal
                ) as timestamp,
                struct(
                    countif(signal.transaction_id is not null) as nonnull,
                    hll_count.init(signal.transaction_id) as hll
                -- numeric
                ) as `order`,
                struct(
                    countif(signal.purchase_revenue is not null) as nonnull,
                    sum(signal.purchase_revenue) as sum
                ) as revenue
            ) as metrics
        from datasource
        group by format('%t', units)
    ),
    core_stats as (
        select
            -- Unit Metrics
            -- Unit Metrics
            any_value(_group_key).*,
            struct(
                nullif(approx_count_distinct(string(grain.units.time_id)), 0) as time,
                nullif(approx_count_distinct(grain.units.user_id), 0) as users,
                nullif(approx_count_distinct(grain.units.item_id), 0) as items,
                approx_count_distinct(
                    ifnull(grain.units.user_id, 'none')
                    || '-'
                    || ifnull(grain.units.item_id, 'none')
                ) as user_item
            -- Additive Metrics
            ) as unit_metrics,
            struct(
                sum(metrics.records) as records,
                struct(
                    sum(metrics.timestamp.nonnull) as nonnull,
                    min(metrics.timestamp.min) as min,
                    max(metrics.timestamp.min) as max
                ) as timestamp,
                struct(
                    sum(metrics.order.nonnull) as nonnull,
                    hll_count.merge_partial(metrics.order.hll) as hll
                ) as `order`,
                struct(
                    sum(metrics.revenue.nonnull) as nonnull,
                    sum(metrics.revenue.sum) as sum
                ) as revenue
            ) as metrics
        from grain
        -- left join `user` using(user_id)
        -- left join `item` using(item_id) -- segments
        left join
            unnest(
                [
                    struct(
                        struct(
                            user.device.category as category,
                            user.geo.country as country
                        ) as user,
                        struct(item.item_category) as item,
                        struct(
                            extract(dayofweek from units.time_id) as dayofweek
                        ) as time
                    )
                ]
            ) as context
        left join
            unnest(
                [
                    -- Overall
                    struct(
                        if(false, null, context.user) as user,
                        if(false, null, context.item) as item,
                        if(false, null, context.time) as time
                    )
                -- -- Time Specific
                -- , struct(
                -- if(false, null, context.user) as user
                -- , if(false, null, context.item) as item
                -- , if(true, null, context.time) as time
                -- )
                -- -- Item Specific
                -- , struct(
                -- if(false, null, context.user) as user
                -- , if(true, null, context.item) as item
                -- , if(false, null, context.time) as time
                -- )
                -- -- User Specific
                -- , struct(
                -- if(true, null, context.user) as user
                -- , if(false, null, context.item) as item
                -- , if(false, null, context.time) as time
                ]
            ) as segments
        -- marginalization for units
        left join unnest([struct('item' as unit, units.item_id as id), null]) as item
        left join unnest([struct('user' as unit, units.user_id as id), null]) as user
        left join
            unnest(
                [
                    struct(
                        'week' as unit,
                        datetime(timestamp_trunc(units.time_id, week)) as id
                    ),
                    struct('day' as unit, datetime(date(units.time_id)) as id),
                    struct('hour' as unit, datetime(units.time_id) as id),
                    null
                ]
            ) as time
        left join
            unnest([struct(struct(time, user, item) as units, segments)]) as _group_key

        -- unit
        group by format('%t', _group_key)
    )

select
    ifnull(
        nullif(
            array_to_string([units.time.unit, units.user.unit, units.item.unit], ' x '),
            ''
        ),
        '#overall'
    ) as unit,
    units.time.id as time_id,
    units.user.id as user_id,
    # , `fn.json_pretty_kv`(`fn.json_trim_empty`(to_json_string(segments)), ', ',
    # null) as segment_label
    units.item.id as item_id,
    * except (units)
from core_stats
;