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
            any_value(funnel) as funnel,
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
                            then datetime(datetime_trunc(signal.timestamp, week, 'Asia/Tokyo'), 'Asia/Tokyo')
                            when "daily"
                            then datetime(datetime_trunc(signal.timestamp, day, 'Asia/Tokyo'), 'Asia/Tokyo')
                            when "hourly"
                            then datetime(datetime_trunc(signal.timestamp, hour, 'Asia/Tokyo'), 'Asia/Tokyo')
                            else error("analytics_units.time is invalid")
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
                        ) as segment,
                    signal_type as funnel
                    )
                ]
            )
        group by format('%t', (units, segment, funnel))
    ),
    core_stats as (
        select
            format('%t', any_value(_group_key)) as _pivot_key,
            any_value(funnel) as funnel,
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
                    sum(metrics.device.nonnull) as nonnull,
                    hll_count.merge(metrics.device.hll) as uniques
                ) as device,
                struct(
                    sum(metrics.session.nonnull) as nonnull,
                    hll_count.merge(metrics.session.hll) as uniques
                ) as session,
                struct(
                    sum(metrics.page.nonnull) as nonnull,
                    hll_count.merge(metrics.page.hll) as uniques
                ) as page,
                struct(
                    sum(metrics.item.nonnull) as nonnull,
                    hll_count.merge(metrics.item.hll) as uniques
                ) as `item`,
                struct(
                    sum(metrics.order.nonnull) as nonnull,
                    hll_count.merge(metrics.order.hll) as uniques
                ) as `order`,
                struct(
                    sum(metrics.revenue.nonnull) as nonnull,
                    sum(metrics.revenue.sum) as sum,
                    sum(metrics.revenue.sum2) as sum2
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
        left join unnest([struct(units as units, segments)]) as _group_key
        left join unnest(["#overall", funnel]) as funnel
        -- unit
        group by format('%t', (_group_key, funnel))
    )
    , funnels as (
      select
        overall.units as units,
        overall.segments as segments,
        overall.metrics as oveall,
        page_view.metrics as page_view,
        view_item.metrics as view_item,
        select_item.metrics as select_item,
        add_to_cart.metrics as add_to_cart,
        purchase.metrics as purchase,
      from core_stats
        pivot (any_value(
            struct(units, segments, metrics, unit_metrics))
          for funnel in (
            '#overall' as overall,
            'page_view',
            'view_item',
            'select_item',
            'add_to_cart',
            'purchase'
          )
        )
    )

select
    analytics_units,
    units.*,
    `kazaneya_techtalk.json_pretty_kv`(
        `kazaneya_techtalk.json_trim_empty`(to_json_string(segments)), ', ', null
    ) as segment_label,
    -- units.item.id as item_id,
    * except (units)
from funnels
;