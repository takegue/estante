import { beforeAll } from "vitest";

beforeAll(() => {
  delete require.cache[require.resolve("tree-sitter")];
  const Parser = require("tree-sitter");
  global.parser = new Parser();
  delete require
    .cache[
      require.resolve(
        "/home/pisces/.ghq/github.com/takegue/estante/codes/vitest_multithreads/node_modules/tree-sitter/build/Release/tree_sitter_runtime_binding.node",
      )
    ];
});
