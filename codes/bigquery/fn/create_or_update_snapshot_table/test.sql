DECLARE destination STRUCT<project_id STRING, dataset_id STRING, table_id STRING> DEFAULT NULL;
DECLARE source STRUCT<project_id STRING, dataset_id STRING, table_id STRING> DEFAULT NULL;
DECLARE exp_unique_key STRING DEFAULT NULL;
DECLARE scd_type STRING DEFAULT NULL;
CALL `project-id-7288898082930342315.fn.create_or_update_snapshot_table`(
  (null, "sandbox", 'station'), ("bigquery-public-data", "austin_bikeshare", "bikeshare_stations"), "station_id", null);
