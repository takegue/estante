const fs = require("fs");

const glue = fs.readFileSync("./pkg/hello_world.js", { encoding: "utf-8" });
const buffer = fs.readFileSync("./pkg/hello_world_bg.wasm");

const bytes = Array.from(new Uint8Array(buffer.buffer));

fs.writeFileSync(
  "base62.js",
  `\
${glue}
wasm_bindgen.initSync(Buffer.from(new Uint8Array(${JSON.stringify(bytes)})));
this.wasm = wasm_bindgen
`,
);
