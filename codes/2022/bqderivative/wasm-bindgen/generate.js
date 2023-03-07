const fs = require("fs");
const glue = fs.readFileSync("./pkg/bqderivative.js", { encoding: "utf-8" });
const buffer = fs.readFileSync("./pkg/bqderivative_bg.wasm");

const bytes = Array.from(new Uint8Array(buffer.buffer));

fs.writeFileSync(
  "dist/index.js",
  `\
${glue}
wasm_bindgen.initSync(Buffer.from(new Uint8Array(${JSON.stringify(bytes)})));
this.wasm = wasm_bindgen
`,
);
