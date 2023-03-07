import { describe, it } from "vitest";

import { Service } from "@google-cloud/common";

class DataLineage extends Service {
  location?: string;

  constructor(options = {}) {
    let apiEndpoint = "https://datalineage.googleapis.com";
    options = Object.assign({}, options, {
      apiEndpoint,
    });
    const baseUrl = `${apiEndpoint}/v1`;
    const config = {
      apiEndpoint: apiEndpoint,
      baseUrl,
      scopes: [
        "https://www.googleapis.com/auth/cloud-platform",
      ],
      packageJson: require("../../package.json"),
    };
    super(config, options);
    this.location = "us";
  }

  getOperations(): unknown {
    return new Promise((resolve, reject) => {
      this.request({
        method: "GET",
        uri: `/locations/${this.location}/operations`,
        useQuerystring: true,
      }, (err, resp) => {
        if (err) {
          console.error(err);
          reject(err);
          return;
        }
        console.error(resp);
        resolve(resp);
      });
    });
  }

  getSearchLinks(): unknown {
    return new Promise((resolve, reject) => {
      this.request({
        method: "POST",
        uri: `/locations/${this.location}:searchLinks`,
        useQuerystring: false,
        body: {
          target: {
            fullyQualifiedName:
              "bigquery:table.project-id-7288898082930342315.sandbox.sample_clone_table",
          },
        },
      }, (err, resp) => {
        if (err) {
          console.error(err);
          reject(err);
          return;
        }
        console.error(resp);
        resolve(resp);
      });
    });
  }
}

describe("dataLineageAPI", () => {
  it("client test", async () => {
    const client = new DataLineage();

    await client.getOperations();
    await client.getSearchLinks();
  });
});
