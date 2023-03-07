var ffi = require('ffi');

var lib = ffi.Library('../../target/release/libembed.dylib', {
  'process': ['void', []]
});

lib.process();

console.log("done!");
