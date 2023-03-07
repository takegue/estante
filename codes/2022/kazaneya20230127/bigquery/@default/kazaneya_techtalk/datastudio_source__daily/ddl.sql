declare query string;

set query = format("""
  select * from `%s.kazaneya_techtalk.analytics`(@begin, @end, ("daily", "overall", "overall"))
  union all
  select * from `%s.kazaneya_techtalk.analytics`(@begin, @end, ("hourly", "overall", "overall"))
""", @@project_id, @@project_id);


with _implict_deps as (
  select * from `kazaneya_techtalk.analytics`(null, null, null)
)
select 1;

drop table if exists `kazaneya_techtalk.datastudio_source__daily`;

execute immediate """
create table if not exists `kazaneya_techtalk.datastudio_source__daily`
partition by DATE(time_id)
as
""" || query
using
  "2000-01-01"as `begin`,
  "2000-01-01"as `end`
;

call `bqmake.v0.partition_table__update`(
  (@@project_id, "kazaneya_techtalk", "datastudio_source__daily")
  , null
  , `bqmake.v0.alignment_day2day`('2021-01-01', '2021-01-01')
  , query
  , null
);
