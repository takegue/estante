'use restrict';

 // Imports the Google Cloud client library
const { BigQuery } = require('@google-cloud/bigquery');
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

  // console.log(catalogId, schemaId, tableId, p, path.basename(p)) 
  const results = await Promise.allSettled((await walk(rootDir)).map(
    async (p) => {
      const msgWithPath = (msg) =>  `${path.dirname(p)}: ${msg}`;
      const jsonSerializer = (obj) => JSON.stringify(obj, null, 4)
      const fsHandler = (err) => {
          throw new Error(
            msgWithPath(err.message)
          );
      }
      const bigqueryHandler = (err) => {
          throw new Error(
            msgWithPath(err.errors.map(e => e.message).join('\n'))
          );
      }

      if(p && !p.endsWith('sql')) return null;

      const [catalogId, schemaId, name] = path.dirname(path.relative(rootDir, p)).split('/')
      const query = await fs.promises.readFile(p)
        .then((s) => s.toString())
        .catch((err => {
          throw new Error(msgWithPath(err)); 
        }))
      ;

      const syncMetadata = async (table, dirPath) => {
          const metadataPath = path.join(dirPath, "metadata.json");
          const fieldsPath = path.join(dirPath, "schema.json");
          const [metadata] = await table.getMetadata();

          // schema.json: local file <---> BigQuery Table
          if(fs.existsSync(fieldsPath)) {
            const oldFields = await fs.promises.readFile(fieldsPath)
              .then((s) => JSON.parse(s.toString()))
              .catch((err) => console.error(err))
            ;
            // Update 
            let updateCnt = 0;
            Object.entries(metadata.schema.fields).map(
              ([k, v]) => {
                if(k in oldFields) {
                  if(metadata.schema.fields[k].description 
                    && metadata.schema.fields[k].description != v.description
                  ) {
                    metadata.schema.fields[k].description = v.description
                    updateCnt++;
                  }
                }
              }
            );
          }

          // metadata.json: local file <--- BigQuery Table
          const localMetadata = Object.fromEntries(Object.entries({
            type: metadata.type,
            routineType: metadata.routineType,
            modelType: metadata.modelType,
            description: metadata.description,
            // Filter predefined labels
          }).filter(([_, v]) => !!v && Object.keys(v).length > 0));


          // Sync
          await Promise.all([
            fs.promises.writeFile(
              fieldsPath,
              jsonSerializer(metadata.schema.fields)
            ).catch(fsHandler),
            , fs.promises.writeFile(
              metadataPath,
              jsonSerializer(localMetadata)
            ).catch(fsHandler),
            table.setMetadata(metadata)
              .catch(bigqueryHandler),
          ])
      };

      switch (path.basename(p)) {
        case "ddl.sql":
          // https://cloud.google.com/bigquery/docs/reference/rest/v2/Job#jobconfiguration
          const [job] = await bqClient.createQueryJob({
              query,
              priority: 'BATCH',
              labels: {
                key1: "value1"
              }
            })
            .catch(bigqueryHandler)
          await job.getQueryResults();

          // const [completedJob] = await job.get()
          switch (job.metadata.statistics.query.statementType) {
            case "CREATE_SCHEMA":
            case "DROP_SCHEMA":
            case "ALTER_SCHEMA":
              break;
            case "CREATE_ROW_ACCESS_POLICY":
            case "DROP_ROW_ACCESS_POLICY":
              //TODO: row access policy
              console.log(job.metadata.statistics);
              break;
            case "CREATE_MODEL":
            case "EXPORT_MODEL":
              //TODO: models
              console.log(job.metadata.statistics);
              break;
            case "CREATE_FUNCTION":
            case "CREATE_TABLE_FUNCTION":
            case "DROP_FUNCTION":
            case "CREATE_PROCEDURE":
            case "DROP_PROCEDURE":
              //TODO: rountines
              const schema = bqClient.dataset(schemaId);
              const routineId = name;
              const [routine] = await schema.routine(routineId).get();
              const metadata = routine.metadata;
              const metadataPath = path.join(path.dirname(p), "metadata.json");
              const localMetadata = Object.fromEntries(Object.entries({
                routineType: metadata.routineType,
                description: metadata.description,
                // Filter predefined labels
              }).filter(([_, v]) => !!v && Object.keys(v).length > 0));
              await fs.promises.writeFile(
                metadataPath,
                JSON.stringify(localMetadata, null, 4)
              )
              break;
            case "CREATE_VIEW":
            case "CREATE_AS_TABLE_SELECT":
            case "DROP_TABLE":
            case "DROP_VIEW":
            case "ALTER_TABLE":
            case "ALTER_VIEW":
            case "INSERT":
            case "UPDATE":
            case "DELETE":
            case "MERGE":
            case "CREATE_MATERIALIZED_VIEW":
            case "DROP_MATERIALIZED_VIEW":
              {
                const schema = bqClient.dataset(schemaId);
                const [table] = await schema.table(name).get();
                await syncMetadata(table, path.dirname(p))
              }
              break;
            case "SCRIPT":
              //TODO: script
              const [childJobs, _] = await bqClient.getJobs({parentJobId: job.id});
              const tgt = childJobs[0].metadata.statistics.query.ddlTargetRoutine
              console.dir(tgt);
              break;
            default:
              console.dir(job.metadata);
          }
          break;
        case "view.sql":
          const schema = bqClient.dataset(schemaId);
          const tableId = name;
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
          await syncMetadata(view, path.dirname(p))
          break;
      }
      return null
    }
  ));

  console.dir(results
    // .filter(r => r.status == 'rejected')
    // .map(e => console.log(e, e?.reason?.errors))
    , {depth: 3}
  );
}

const main = async () => {
  createCLI()
   // await pullBigQueryResources()
  // await pushBigQueryResources()
}

main();
