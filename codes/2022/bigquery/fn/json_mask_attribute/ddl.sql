create or replace function `fn.json_mask_attribute`(
  json_value string
  , max_depth int64
  , null_value string
)
returns array<string>
language js
as """
  const null_value = null_value ?? "__NULL__"
  const obj = JSON.parse(json_value);
  const result = [null_value, json_value];

  if(!obj) {
    return [null_value]
  }

  if(Object.keys(obj).length <= 1) {
    return result
  }

  const traverse = (o, depth) => {
    if(max_depth < depth) {
      return
    }

    if(typeof o !== 'object') {
      return
    }

    if(Array.isArray(o)) {
      return
    }

    Object.keys(o).forEach(key => {
      const newObj = JSON.parse(JSON.stringify(o))
      delete newObj[key]
      if(Object.keys(newObj).length > 0 ){
        result.push(JSON.stringify(newObj))
        traverse(newObj, depth + 1)
      }
    });
  }
  traverse(obj, 1)

  return result;
"""
;

select [
  "__NULL__",
  "{\"user\":{\"value\":2},\"item\":2}",
  "{\"item\":2}",
  "{\"user\":{\"value\":2}}"
] = `fn.json_attribute_subtotal`(to_json_string(struct(struct(2 as value) as user, 2 as item)), 2);
