import { describe, expect, it } from "vitest";

// import { createNewParser } from "../src/utils.js";

describe("new parser", () => {
  it.concurrent.each(Array(10).fill(0))("concurrent test", async () => {
    // global.parser;
    console.log("test1");
  });
});
