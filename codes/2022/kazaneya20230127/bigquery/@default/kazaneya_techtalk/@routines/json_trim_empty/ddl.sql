CREATE OR REPLACE FUNCTION `kazaneya_techtalk.json_trim_empty`(json STRING) RETURNS STRING LANGUAGE js
AS
r"""
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
""";