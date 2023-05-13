import express from 'express'
import winston from 'winston'
import { NodeSDK } from '@opentelemetry/sdk-node'
import { getNodeAutoInstrumentations } from '@opentelemetry/auto-instrumentations-node'
import { PrometheusExporter } from '@opentelemetry/exporter-prometheus'
import { ZipkinExporter } from '@opentelemetry/exporter-zipkin'
import { HttpInstrumentation } from '@opentelemetry/instrumentation-http'
import { ExpressInstrumentation } from '@opentelemetry/instrumentation-express'

// logger
const logger = winston.createLogger({
  level: 'debug',
  format: winston.format.json(),
  defaultMeta: { service: process.env.SERVICE_NAME },
  transports: [
    new winston.transports.Console({
      format: winston.format.combine(
        winston.format.timestamp(),
        winston.format.json()
      )
    })
  ]
})
// start metrics
const sdk = new NodeSDK({
  traceExporter: new ZipkinExporter({
    serviceName: process.env.SERVICE_NAME,
    url: process.env.ZIPKIN_EXPORTER_URL
  }),
  metricReader: new PrometheusExporter({ startServer: true, port: process.env.METRICS_PORT || 9464 }, () => {
    logger.info({
      message: 'Prometheus metrics server started on port 9464'
    })
  }),
  instrumentations: [
    getNodeAutoInstrumentations(),
    new HttpInstrumentation(),
    new ExpressInstrumentation()
  ]
})
sdk.start()
// start express server
const app = express()
app.use(express.json())
app.get('/ping', (req, res) => res.send('pong'))
app.listen(process.env.PORT || 3000)
logger.info({
  message: 'Express API server listening...'
})
// gracefully shut down the SDK on process exit
process.on('SIGTERM', () => {
  sdk.shutdown()
    .catch((err) => {
      logger.error({
        message: 'failed to cleanly shutdown metrics',
        error: err.toString()
      })
    })
    .finally(() => process.exit(0))
})
