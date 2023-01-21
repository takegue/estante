create or replace function `kazaneya_techtalk.json_trim_empty`(json string)
returns string
language js
as """
  const obj = JSON.parse(json);
  function trimNullElements(obj) {
      if (obj === null) {
          return null;
      }
      if (Array.isArray(obj)) {
          return obj.map(trimNullElements).filter(v => v);
      }
      if (typeof obj === 'object') {
          const newObj = {};
          for (const key in obj) {
              if (obj.hasOwnProperty(key)) {
                  const value = obj[key];
                  if (value !== null) {
                      newValue = trimNullElements(value);
                      if(newValue !== null) {
                          newObj[key] = newValue;
                      }
                  }
              }
          }
          if(Object.keys(newObj).length === 0) {
              return null;
          }
          return newObj;
      }
      return obj;
  }

  const ret = trimNullElements(obj);
  return ret ? JSON.stringify(ret) : null;
"""
;

assert `kazaneya_techtalk.json_trim_empty`('{"key": null}') is null;
assert '{"key2":2}' = `kazaneya_techtalk.json_trim_empty`('{"key": null, "key2": 2}');
assert '{"key2":2}' = `kazaneya_techtalk.json_trim_empty`('{"key": {"item": null}, "key2": 2}');
assert '[1,2]' = `kazaneya_techtalk.json_trim_empty`('[1,null,2]');
