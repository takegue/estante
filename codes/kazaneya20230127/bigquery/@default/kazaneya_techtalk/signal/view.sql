select
    parse_date('%Y%m%d', _table_suffix) as date,
    struct(
        timestamp_trunc(timestamp, hour) as time_id,
        user_pseudo_id as user_id,
        item.item_id
    ) as units,
    struct(device, geo) as user,
    item as item,
    event_name as signal_type,
    struct(
        -- ID類
        timestamp,
        ecommerce.transaction_id,
        ecommerce.purchase_revenue,
        page_id,
        user_pseudo_id as device_id,
        user_id,
        session_id,
        item_id,
        1 as first_visit_per_day,
        1 as first_purchase_per_user
    ) as signal
from `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
left join
    unnest(
        [
            struct(
                timestamp_micros(event_timestamp) as timestamp,
                `bqutil.fn.get_value`(
                    'ga_session_id', event_params
                ).string_value as session_id,
                `bqutil.fn.get_value`(
                    'page_location', event_params
                ).string_value as page_id
            )
        ]
    )
left join unnest(items) as item
