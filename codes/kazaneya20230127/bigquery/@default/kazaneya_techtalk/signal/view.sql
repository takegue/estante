select
    parse_date('%Y%m%d', _table_suffix) as date,
    timestamp_trunc(timestamp, hour) as time_id,
    user_pseudo_id as user_id,
    session_id,
    page_id,
    _v.item_id,
    device_id,
    struct(
      struct(device, geo, is_debug_user) as user,
      struct(
        `bqutil.fn.url_parse`(page_id, 'HOST') as host,
        `bqutil.fn.url_parse`(page_id, 'PATH') as path,
        page_title
      ) as app,
      struct(
        _v.item_id as item_id,
        ifnull(split(_v.item_category)[safe_offset(0)], "#missing") as item_category1,
        ifnull(split(_v.item_category)[safe_offset(1)], "#missing") as item_category2,
        ifnull(split(_v.item_category)[safe_offset(2)], "#missing") as item_category3,
        item.price as price,
        item.quantity as quantity,
        item.item_revenue as revenue
      ) as item,
      struct(
        _v.promotion_id as promotion,
        _v.creative_id as creative,
        _v.item_list_index as list_index
      ) as promotion,
      struct(
        extract(dayofweek from timestamp) as dayofweek,
        case
          when extract(dayofweek from timestamp) in (0, 6) then "HOLIDAY"
          else "WEEKDAY"
        end as dayofweek_type
      ) as time
    ) as entities,
    event_name as signal_type,
    struct(
        -- ID類
        timestamp,
        nullif(ecommerce.transaction_id, '(not set)') as transaction_id,
        item.item_revenue as revenue,
        item.item_revenue / ecommerce.purchase_revenue as revenue_ratio,
        page_id,
        device_id,
        user_id,
        session_id,
        _v.item_id
    ) as signal
from `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
left join
    unnest(
        [
            struct(
                timestamp_micros(event_timestamp) as timestamp,
                `bqutil.fn.get_value`(
                    'ga_session_id', event_params
                ).int_value as session_id,
                `bqutil.fn.get_value`(
                    'page_location', event_params
                ).string_value as page_id,
                `bqutil.fn.get_value`(
                    'page_title', event_params
                ).string_value as page_title,
                `bqutil.fn.get_value`(
                    'page_referrer', event_params
                ).string_value as page_referrer,
                `bqutil.fn.get_value`(
                    'meidum', event_params
                ).string_value as medium,
                `bqutil.fn.get_value`(
                    'campaign', event_params
                ).string_value as campaign,
                `bqutil.fn.get_value`(
                    'source', event_params
                ).string_value as source,
                ifnull(cast(`bqutil.fn.get_value`(
                      'debug_mode', event_params
                ).int_value as bool), false) as is_debug_user,
                user_pseudo_id as device_id
            )
        ]
    )
left join unnest(items) as item
left join
    unnest(
        [
            struct(
              nullif(item.item_id, '(not set)') as item_id,
              nullif(item.item_category, '(not set)') as item_category,
              nullif(item.promotion_name, '(not set)') as promotion_id,
              nullif(item.creative_name, '(not set)') as creative_id,
              safe_cast(replace(nullif(item.item_list_index, '(not set)'), 'Slide ', '') as int64) as item_list_index
            )
        ]
    ) as _v
-- left join `user` using(user_id)
-- left join `item` using(item_id) -- segments
where
  _table_suffix = "20210101"
  and event_name in ('pageview', 'view_item', 'select_item', 'add_to_cart', 'purchase')
