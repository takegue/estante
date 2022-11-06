const { greet } = require("./pkg");

console.log('--package', require("./pkg"))
console.log('greet', greet);
console.log(greet("hoge"));
