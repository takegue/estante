import { defineConfig } from "vitest/config";

export default defineConfig({
  plugins: [{
    name: "a-vitest-plugin-that-changes-config",
    config: () => ({
      test: {
        setupFiles: [
          "./setupFiles/hoge.ts",
        ],
      },
    }),
  }],

  test: {
    threads: true,
    // ...
    globals: false,
  },
});
