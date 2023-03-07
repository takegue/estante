CREATE TEMP FUNCTION `greet`() RETURNS STRING LANGUAGE js AS '''
  return wasm_bindgen.greet("hoge");
'''
OPTIONS (
  library=[
    "gs://fh-bigquery/js/inexorabletash.encoding.js",
    "gs://takegue_sandbox/public/index_nomodules.js"
  ]
);


SELECT greet() b62
FROM (
  select 'dbc3d5ebe344484da3e2448712a02213' as hex
)
