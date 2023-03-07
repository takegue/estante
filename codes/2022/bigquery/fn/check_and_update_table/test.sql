declare ret array<string>;

create schema if not exists `zpreview_test`;

create or replace table `zpreview_test.dest1`
partition by date_jst
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

call `fn.check_and_update_table`(
  (null, "zpreview_test", "dest1")
  , [(string(null), "zpreview_test", "ref1")]
  , [("20060102", ["20060102"])]
  , struct(
    'select date "2006-01-02" as date_jst'
    , true as dry_run
    , interval 0 minute
    , null
    , null
  )
);
