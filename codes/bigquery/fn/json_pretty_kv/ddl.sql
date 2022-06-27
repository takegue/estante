create or replace function `fn.json_pretty_kv`(json string, delimiter string, `limit` int64)
returns string
language js
as r"""
  const _delimiter = delimiter ?? '\n';
  const genNamespace = (namespace, child) => `${namespace}.${child}`.replace(/^\./, '');
  const pretty_kvformat = (namespace, obj) => {
    if (Array.isArray(obj)) {
      return obj.map((i, v) => pretty_kvformat(genNamespace(namespace, i), v)).join(_delimiter);
    }
    if (typeof obj === 'object') {
      const keys = Object.keys(obj);
      if (keys.length === 0) {
        return '';
      }
      const kv = keys.map(key => {
        const value = obj[key];
        const new_namespace = `${namespace}.${key}`.replace(/^\./, '');
        if (typeof value === 'object') {
          return pretty_kvformat(`${new_namespace}`, value);
        }
        return `${new_namespace}=${value}`;
      });
      return kv.join(_delimiter);
    }
    return `${namespace}=${obj}`;
  };

  const o = JSON.parse(json);
  return pretty_kvformat('', o);
"""
;

assert trim("""
k1=long_value
k2.item1=nestedvalue1
arr.1=0
arr.2=1
arr.3=2
""") = `fn.json_pretty_kv`('{"k1": "long_value", "k2": { "item1": "nestedvalue1"}, "arr": [1,2,3]}', null, 20);
