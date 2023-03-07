create or replace table function `sandbox.sample_function`(argument int64)
options(
  description="test"
)
as 
select argument as a
