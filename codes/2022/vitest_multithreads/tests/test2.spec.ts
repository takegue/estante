import { describe, expect, it } from "vitest";

describe("new parser", () => {
  it.concurrent.each(Array(10).fill(0))("concurrent test", async () => {
    // const parser = createNewParser();
    console.log("test2");
    // parser shouldn't be undefined
  });
});
