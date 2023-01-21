create or replace table function
    `kazaneya_techtalk.analytics`(
        begins_at date,
        ends_at date,
        analytics_units struct<time string, user string, product string>
    )
as
with
    datasource as (
        select *
        from `kazaneya_techtalk.signal`
        where date between begins_at and ends_at
    ),
    grain as (
        select
            any_value(units) as units,
            any_value(segment) as segment,
            struct(
                -- 型ごとに主要統計量の取り方が定まる
                -- timestamp signal
                count(1) as records,
                struct(
                    countif(signal.device_id is not null) as nonnull,
                    hll_count.init(signal.device_id) as hll
                ) as device,
                struct(
                    countif(signal.session_id is not null) as nonnull,
                    hll_count.init(signal.session_id) as hll
                ) as session,
                struct(
                    countif(signal.page_id is not null) as nonnull,
                    hll_count.init(signal.page_id) as hll
                ) as page,
                struct(
                    countif(signal.item_id is not null) as nonnull,
                    hll_count.init(signal.item_id) as hll
                ) as item,
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
                    countif(signal.revenue is not null) as nonnull,
                    sum(signal.revenue) as sum,
                    sum(signal.revenue * signal.revenue) as sum2
                ) as revenue
            ) as metrics
        from datasource
        left join
            unnest(
                [
                    struct(
                        case
                            analytics_units.time
                            when "overall"
                            then null
                            when "weekly"
                            then datetime_trunc(signal.timestamp, week, 'Asia/Tokyo')
                            when "daily"
                            then datetime_trunc(signal.timestamp, day, 'Asia/Tokyo')
                            when "hourly"
                            then datetime_trunc(signal.timestamp, hour, 'Asia/Tokyo')
                        end as time_id,
                        case
                            analytics_units.user
                            when "overall"
                            then null
                            when "device"
                            then signal.device_id
                        end as user_id
                    )
                ]
            ) as units
        left join
            unnest(
                [
                    struct(
                        struct(
                            struct(
                                entities.user.device.language as lang,
                                entities.user.device.category as category,
                                entities.user.device.web_info.browser as browser,
                                entities.user.device.mobile_brand_name as brand,
                                entities.user.geo.continent as geo_continent,
                                entities.user.geo.region as geo_region
                            ) as user,
                            struct(
                                entities.item.item_category1,
                                entities.item.item_category2,
                                entities.item.item_category3
                            ) as item,
                            struct(
                                entities.app.host as host, entities.app.path as path
                            ) as app,
                            struct(
                              entities.time.dayofweek_type as dayofweek_type
                            ) as time
                        ) as segment
                    )
                ]
            )
        group by format('%t', units)
    ),
    core_stats as (
        select
            -- Unit Metrics
            any_value(_group_key).*,
            struct(
                nullif(approx_count_distinct(string(grain.units.time_id)), 0) as time
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
        left join
            unnest(
                [
                    struct(
                        struct(
                            if(
                                false,
                                segment.user,
                                (
                                    "#overall",
                                    "#overall",
                                    "#overall",
                                    "#overall",
                                    "#overall",
                                    "#overall"
                                )
                            ) as user,
                            if(
                                false,
                                segment.item,
                                ("#overall", '#overall', '#overall')
                            ) as item,
                            if(false, segment.time, (null)) as time
                        ) as null_value
                    )
                ]
            )
        left join
            unnest(
                [
                    struct(
                        if(false, segment.user.lang, '#overall') as lang,
                        if(false, segment.user.category, '#overall') as category,
                        if(false, segment.user.browser, '#overall') as browser,
                        if(false, segment.user.brand, '#overall') as brand,
                        if(false, segment.user.geo_continent, '#overall') as geo_continent,
                        if(false, segment.user.geo_region, '#overall') as geo_region
                    ),
                    (
                        if(true, segment.user.lang, '#overall'),
                        if(false, segment.user.category, '#overall'),
                        if(false, segment.user.browser, '#overall'),
                        if(false, segment.user.brand, '#overall'),
                        if(false, segment.user.geo_continent, '#overall'),
                        if(false, segment.user.geo_region, '#overall')
                    ),
                    (
                        if(false, segment.user.lang, '#overall'),
                        if(true, segment.user.category, '#overall'),
                        if(false, segment.user.browser, '#overall'),
                        if(false, segment.user.brand, '#overall'),
                        if(false, segment.user.geo_continent, '#overall'),
                        if(false, segment.user.geo_region, '#overall')
                    ),
                    (
                        if(false, segment.user.lang, '#overall'),
                        if(false, segment.user.category, '#overall'),
                        if(true, segment.user.browser, '#overall'),
                        if(false, segment.user.brand, '#overall'),
                        if(false, segment.user.geo_continent, '#overall'),
                        if(false, segment.user.geo_region, '#overall')
                    ),
                    (
                        if(false, segment.user.lang, '#overall'),
                        if(false, segment.user.category, '#overall'),
                        if(false, segment.user.browser, '#overall'),
                        if(true, segment.user.brand, '#overall'),
                        if(false, segment.user.geo_continent, '#overall'),
                        if(false, segment.user.geo_region, '#overall')
                    ),
                    (
                        if(false, segment.user.lang, '#overall'),
                        if(false, segment.user.category, '#overall'),
                        if(false, segment.user.browser, '#overall'),
                        if(false, segment.user.brand, '#overall'),
                        if(true, segment.user.geo_continent, '#overall'),
                        if(false, segment.user.geo_region, '#overall')
                    ),
                    (
                        if(false, segment.user.lang, '#overall'),
                        if(false, segment.user.category, '#overall'),
                        if(false, segment.user.browser, '#overall'),
                        if(false, segment.user.brand, '#overall'),
                        if(true, segment.user.geo_continent, '#overall'),
                        if(true, segment.user.geo_region, '#overall')
                    )
                ]
            ) as dim__user
        left join
            unnest(
                [
                    struct(
                        if(
                            false, segment.item.item_category1, "#overall"
                        ) as item_category1,
                        if(
                            false, segment.item.item_category2, "#overall"
                        ) as item_category2,
                        if(
                            false, segment.item.item_category3, "#overall"
                        ) as item_category3
                    ),
                    (
                        if(true, segment.item.item_category1, "#overall"),
                        if(false, segment.item.item_category2, "#overall"),
                        if(false, segment.item.item_category3, "#overall")
                    ),
                    (
                        if(true, segment.item.item_category1, "#overall"),
                        if(true, segment.item.item_category2, "#overall"),
                        if(false, segment.item.item_category3, "#overall")
                    )
                ]
            ) as dim__item
        left join
            unnest(
                [
                    struct(
                        if(false, segment.time.dayofweek_type, "#overall") as dayofweek
                    ),
                    struct(
                        if(true, segment.time.dayofweek_type, "#overall")
                    )
                ]
            ) as dim__time
        left join unnest([struct(dim__user as user, dim__item as item, dim__time)]) as segments
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
        left join unnest([struct(struct(time) as units, segments)]) as _group_key

        -- unit
        group by format('%t', _group_key)
    )

select
    units,
    units.time.id as time_id,
    -- units.user.id as user_id,
    `kazaneya_techtalk.json_pretty_kv`(
        `kazaneya_techtalk.json_trim_empty`(to_json_string(segments)), ', ', null
    ) as segment_label,
    -- units.item.id as item_id,
    * except (units)
from core_stats
;