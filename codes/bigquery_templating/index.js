'use restrict';

 // Imports the Google Cloud client library
const {BigQuery} = require('@google-cloud/bigquery');
const fs = require('fs');
const path = require('path');
const cli = require('cac')()
const baseDirectory = './bigquery';

function createCLI() {
  cli
    .command('push', '説明') // コマンド
    .option('--opt', '説明') // 引数オプション
    .action((options) => {
      // 実行したい処理
      console.log('push', options) // 引数の値をオブジェクトで受け取れる
    });

  cli
    .command('pull', '説明') // コマンド
    .option('--opt', '説明') // 引数オプション
    .action((options) => {
      // 実行したい処理
      pullBigQueryResources()
    })
  ;

  cli.help()
  cli.parse()
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

        // TODO: TABLES quoata will couse
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


const main = async () => {
  await pullBigQueryResources()

}


main();
