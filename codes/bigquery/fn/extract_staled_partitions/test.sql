declare ret struct<begins_at date, ends_at date>;
declare message string;

create schema if not exists `zpreview_test`;

create or replace table `zpreview_test.dest1`
partition by date_jst
as
select date '2006-01-02' as date_jst
;

create or replace table `zpreview_test.ref2`
partition by date_jst
as select date '2006-01-02' as date_jst
;

call `fn.extract_staled_partitions`(
  (null, "zpreview_test", "dest1")
  , [(string(null), "zpreview_test", "ref1")]
  , [("20060102", ["20060102"])]
  , null
  , ret
);

assert ret.begins_at is not null and ret.begins_at = '2006-01-02'

drop schema if exists `zpreview_test` CASCADE;
