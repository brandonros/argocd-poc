import express from 'express'
const app = express()
app.get('/ping', (req, res) => res.send('pong'))
app.listen(process.env.PORT || 3000)
