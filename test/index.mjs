import express from 'express'
import ElasticsearchBulkIndexer from 'elasticsearch-bulk-indexer'

const app = express()
app.use(express.json())
app.post('/index', async (req, res) => {
  try {
    const elasticsearchUsername = process.env.ELASTICSEARCH_USERNAME
    const elasticsearchPassword = process.env.ELASTICSEARCH_PASSWORD
    const elasticsearchUrl = process.env.ELASTICSEARCH_URL
    console.log({
      elasticsearchUsername,
      elasticsearchPassword,
      elasticsearchUrl
    })
    const indexerChunkSize = 1
    const elasticsearchBulkIndexer = new ElasticsearchBulkIndexer(
      elasticsearchUsername,
      elasticsearchPassword,
      elasticsearchUrl,
      indexerChunkSize
    )
    const { indexName, messageId, message } = req.body
    await elasticsearchBulkIndexer.index(indexName, messageId, message)
    await elasticsearchBulkIndexer.flush()
    res.send('ok')
  } catch (err) {
    res.status(500).send(err)
  }
})
app.get('/ping', (req, res) => res.send('pong'))
app.listen(process.env.PORT || 3000)
