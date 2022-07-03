create or replace procedure `fn.update_table_lastmodified_time`(
  target struct<project_id string, dataset_id string, table_id string>
)
begin
  execute immediate format(
    r"delete `%s.%s.%s` where false"
    , ifnull(target.project_id, @@project_id), target.dataset_id, target.table_id
  );
end
