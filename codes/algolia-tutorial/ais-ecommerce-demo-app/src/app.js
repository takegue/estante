/* global algoliasearch instantsearch */
 searchClient = algoliasearch(
  'IPRWMNYBTT',
  '99d2d5c4f8050d8735b38d9affddae3c'
);

const search = instantsearch({
  indexName: 'dev_rettypy',
  searchClient,
});

search.addWidgets([
  instantsearch.widgets.searchBox({
    container: '#searchbox',
  }),
  instantsearch.widgets.hits({
    container: '#hits',
    templates: {
      item: `
<article>
  <h1>{{#helpers.highlight}}{ "attribute": "name" }{{/helpers.highlight}}</h1>
</article>
`,
    },
  }),
  instantsearch.widgets.pagination({
    container: '#pagination',
  }),
]);

search.start();
