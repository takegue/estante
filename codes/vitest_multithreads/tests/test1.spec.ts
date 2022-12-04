import { describe, expect, it } from "vitest";

import { createNewParser } from "../src/utils.js";

describe("new parser", () => {
  it.each(Array(20).fill(0))("concurrent test", async () => {
    const parser = createNewParser();
    console.log(parser.parse("select 1"));
    // parser shouldn't be undefined
    expect(parser).toBeDefined();
  });
});
