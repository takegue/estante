'use restrict';

 // Imports the Google Cloud client library
const {BigQuery} = require('@google-cloud/bigquery');
const fs = require('fs');
const path = require('path');
const cli = require('cac')()
const baseDirectory = './bigquery';

predefinedLabels = {
  "bigquery-loader": "bigquery_templating"
}

function createCLI() {
  cli
    .command('push', '説明') // コマンド
    .option('--opt', '説明') // 引数オプション
    .action(async (options) => {
      // 実行したい処理
      console.log('push command', options) // 引数の値をオブジェクトで受け取れる
      await pushBigQueryResources()
    });

  cli
    .command('pull', '説明') // コマンド
    .option('--opt', '説明') // 引数オプション
    .action(async (options) => {
      // 実行したい処理
      pullBigQueryResources()
    })
  ;

  cli.help()
  cli.parse()
}

async function walk(dir) {
    let files = await fs.promises.readdir(dir);
    files = await Promise.all(files.map(async file => {
        const filePath = path.join(dir, file);
        const stats = await fs.promises.stat(filePath);
        if (stats.isDirectory()) return walk(filePath);
        else if(stats.isFile()) return filePath;
    }));

    return files.reduce((all, folderContents) => all.concat(folderContents), []);
}

async function pullBigQueryResources() {
  const bqClient = new BigQuery();
  // Lists all datasets in the specified project
  bqClient.getDatasetsStream()
    .on("error", console.error)
    .on("data", async (dataset) => {
        const projectID = dataset.metadata.datasetReference.projectId;
        const datasetPath = `${baseDirectory}/${projectID}/${dataset.id}`
        if (!fs.existsSync(datasetPath)) {
          // console.log(`Creating ${datasetPath}`);
          await fs.promises.mkdir(datasetPath, {recursive: true})
        }

        // TODO: INFORMATION_SCHEMA.TABLES quota error will occur
        await bqClient.createQueryJob(`
          select 
            routine_type as type
            , routine_catalog as catalog
            , routine_schema as schema
            , routine_name as name
            , ddl 
          from \`${dataset.id}.INFORMATION_SCHEMA.ROUTINES\`
          union all
          select 
            table_type as type
            , table_catalog as catalog
            , table_schema as schema
            , table_name as name
            , ddl 
          from \`${dataset.id}.INFORMATION_SCHEMA.TABLES\`
        `).then(async ([job, apiResponse]) => {
            await job.getQueryResults()
              .then(async (records) => {
                await Promise.all(
                  records[0].map(async ({
                    type,
                    catalog,
                    schema,
                    name,
                    ddl
                  }) => {
                    const pathDir = `${baseDirectory}/${catalog}/${schema}/${name}`
                    const pathDDL = `${pathDir}/ddl.sql`
                    const cleanedDDL = ddl
                      .replace(/\r\n/g, '\n')
                      .replace("CREATE PROCEDURE", "CREATE OR REPLACE PROCEDURE")
                      .replace("CREATE TABLE FUNCTION", "CREATE OR REPLACE TABLE FUNCTION")
                      .replace("CREATE FUNCTION", "CREATE OR REPLACE FUNCTION")
                      .replace(/CREATE TABLE/, "CREATE TABLE IF NOT EXISTS")
                      .replace(/CREATE VIEW/, "CREATE OR REPLACE VIEW")
                      .replace(/CREATE MATERIALIZED VIEW/, "CREATE OR REPLACE MATERIALIZED VIEW")

                    if (!fs.existsSync(pathDir)) {
                        await fs.promises.mkdir(pathDir, {recursive: true})
                    }
                    if (type in {'VIEW': true, 'TABLE': true, 'MATERIALIZED VIEW': true}) {
                        const [table, _] = await dataset.table(name).get()
                        const pathSchema = `${pathDir}/schema.json`
                        await fs.promises.writeFile(
                          pathSchema,
                          JSON.stringify(table.metadata.schema.fields, null, 4)
                        )

                        if('view' in table.metadata) {
                          const pathView = `${pathDir}/view.sql`
                          await fs.promises.writeFile(
                            pathView,
                            table.metadata.view.query
                              .replace(/\r\n/g, '\n')
                          )
                        } 
                    }
                    await fs.promises.writeFile(pathDDL, cleanedDDL)
                      .then(
                        () => console.log(
                          `${type}: ${catalog}:${schema}.${name} => ${pathDDL}`
                        )
                      )
                  })
                )
              })
          })
          .catch(err => {
            console.error(err);
          })

    })
    .on('end', () => {
    })
}

async function pushBigQueryResources() {
  const bqClient = new BigQuery();
  const rootDir = path.normalize("./bigquery");
  const results = await Promise.allSettled((await walk(rootDir)).map(
    async (p) => {
      if(p && !p.endsWith('sql')) return null;

      const [catalogId, schemaId, tableId] = path.dirname(path.relative(rootDir, p)).split('/')
      const query = await fs.promises.readFile(p)
        .then((s) => s.toString())
        .catch((err => {
          throw new Error(msgWithPath(err)); 
        }))
      ;

      // console.log(catalogId, schemaId, tableId, p, path.basename(p)) 
      const msgWithPath = (msg) =>  `${path.dirname(p)}: ${msg}`;
      switch (path.basename(p)) {
        case "ddl.sql":
          await bqClient.createQueryJob(query)
          break;
        case "view.sql":
          const schema = bqClient.dataset(schemaId);
          const api = schema.table(tableId);
          const [isExist] = await api.exists();

          const [view] = await (
            isExist 
              ? api.get() 
              : schema.createTable(tableId, {
                view: query,
              })
          );
          const [metadata] = await view.getMetadata();

          const metadataPath = path.join(path.dirname(p), "metadata.json");
          if(fs.existsSync(metadataPath)) {
            const metaTable = await fs.promises.readFile(metadataPath)
              .then((s) => JSON.parse(s.toString()))
              .catch((err) => console.error(err))
            ;
            metadata.description = metaTable?.description ?? "";
            metadata.labels =  {...predefinedLabels, ...metaTable?.labels};
          }
          metadata.view = query;

          await view.setMetadata(metadata)
            .catch(err => {
                throw new Error(
                  msgWithPath(err.errors.map(e => e.message).join('\n')));
            });

          const localMetadata = Object.fromEntries(Object.entries({
            type: metadata.type,
            description: metadata.description,
            // Filter predefined labels
            labels: Object.entries(metadata.labels).reduce((ret, [k, v]) => {
              if(!(k in predefinedLabels)) {
                ret[k] = v;
              }
              return ret
            }, {})
          }).filter(([_, v]) => !!v && Object.keys(v).length > 0));
          await fs.promises.writeFile(
            metadataPath,
            JSON.stringify(localMetadata, null, 4)
          )

          const fieldsPath = path.join(path.dirname(p), "schema.json");
          if(fs.existsSync()) {
            const oldFields = await fs.promises.readFile(fieldsPath)
              .then((s) => JSON.parse(s.toString()))
              .catch((err) => console.error(err))
            ;
            // Update 
            Object.fromEntries(Object.entries(metadata.schema.fields).map(
              ([k, v]) => {
                if(k in oldFields) {
                  if(metadata.schema.fields[k].description) {
                    metadata.schema.fields[k].description = v.description
                  }
                }
              }
            ));

            // Sync local storage and BigQuery
            await fs.promises.writeFile(
              fieldsPath,
              JSON.stringify(metadata.schema.fields, null, 4)
            )
            await view.setMetadata(metadata)
          }
          await fs.promises.writeFile(
            fieldsPath,
            JSON.stringify(metadata.schema.fields, null, 4)
          )
          break;
      }
    }
  ));

  console.log(results
    .filter(r => r.status == 'rejected')
    .map(e => console.log(e.reason?.message))
  );
}

const main = async () => {
  createCLI()
   // await pullBigQueryResources()
  // await pushBigQueryResources()
}

main();
