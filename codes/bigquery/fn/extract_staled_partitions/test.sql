declare ret array<string>;

create schema if not exists `zpreview_test`;

create or replace table `zpreview_test.dest1`
partition by date_jst
as
select date '2006-01-02' as date_jst
;

create or replace table `zpreview_test.dest_no_partition`
as
select date '2006-01-02' as date_jst
;

create or replace table `zpreview_test.ref1`
partition by date_jst
as select date '2006-01-02' as date_jst
;

create or replace table `zpreview_test.ref_no_partition`
as select date '2006-01-02' as date_jst
;

call `fn.extract_staled_partitions`(
  ret
  , (null, "zpreview_test", "dest1")
  , [(string(null), "zpreview_test", "ref1")]
  , [("20060102", ["20060102"])]
  , null
);

assert ret is not null;

call `fn.extract_staled_partitions`(
  ret
  , (null, "zpreview_test", "dest1")
  , [(string(null), "zpreview_test", "ref1")]
  , [("20060102", ["20060102"])]
  , struct(interval 0 hour)
);

assert ret is not null and ret[safe_offset(0)] = '20060102';

call `fn.extract_staled_partitions`(
  ret
  , (null, "zpreview_test", "dest1")
  , [(string(null), "zpreview_test", "ref_no_partition")]
  , [('20060102', ["__NULL__"])]
  , struct(interval 0 hour)
);

assert ret is not null and ret[safe_offset(0)] = '20060102';

call `fn.extract_staled_partitions`(
  ret
  , (null, "zpreview_test", "dest_no_partition")
  , [(string(null), "zpreview_test", "ref_no_partition")]
  , [('__NULL__', ["__NULL__"])]
  , struct(interval 0 hour)
);

assert ret is not null and ret[safe_offset(0)] = '__NULL__';


drop schema if exists `zpreview_test` CASCADE;
