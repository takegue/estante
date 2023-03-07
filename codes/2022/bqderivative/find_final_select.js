function find_final_select(sql) {
  const left = ["("];
  const right = [")"];
  let surroundCnt = 0;
  let buffer = [];

  const kw = "select";
  const kw_matcher = new RegExp(kw, "i");

  for (let ix = 0; ix < sql.length; ix++) {
    const c = sql[ix];
    if (left.includes(c)) {
      surroundCnt++;
    } else if (right.includes(c)) {
      surroundCnt--;
    }

    if (c.match(/[a-z0-9]/i)) {
      buffer.push(c);
    } else {
      buffer.length = 0;
    }

    if (surroundCnt === 0 && buffer.join("").match(kw_matcher)) {
      return ix - kw.length;
    }
  }
}

const inputs = [
  `
with
datasource as (
  select * from \`bigquery-public-data.austin_311.311_service_requests\`
)
, __test_count as (
  select count(1) from datasource
)

select * from datasource
`,
  `
with
datasource as (
  select * from \`bigquery-public-data.austin_311.311_service_requests\`
)
, __test_count as (
  select count(1) from datasource
)

SELECT * from (select * __test_count)
`,
];

for (sql of inputs) {
  console.log(sql.substring(0, find_final_select(sql)));
}
