CREATE OR REPLACE FUNCTION `kazaneya_techtalk.json_pretty_kv`(json STRING, delimiter STRING, `limit` INT64) RETURNS STRING LANGUAGE js
AS
r"""
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
""";