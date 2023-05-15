import opentelemetry from '@opentelemetry/api'
import { getNodeAutoInstrumentations } from '@opentelemetry/auto-instrumentations-node'
import { NodeTracerProvider } from '@opentelemetry/sdk-trace-node'
import { BatchSpanProcessor } from '@opentelemetry/sdk-trace-base'
import { ZipkinExporter } from '@opentelemetry/exporter-zipkin'
import { registerInstrumentations } from '@opentelemetry/instrumentation'
import promClient from 'prom-client'

const run = async () => {
  // tracing
  const tracerProvider = new NodeTracerProvider()
  tracerProvider.addSpanProcessor(new BatchSpanProcessor(new ZipkinExporter({
    url: process.env.ZIPKIN_EXPORTER_ENDPOINT,
    serviceName: process.env.SERVICE_NAME
  })))
  tracerProvider.register()
  registerInstrumentations({
    instrumentations: [
      getNodeAutoInstrumentations()
    ]
  })
  // metrics
  const metricsRegistry = new promClient.Registry();
  promClient.collectDefaultMetrics({ register: metricsRegistry })
  // logger
  const winston = await import('winston')
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
  // express
  const { default: express } = await import('express')
  const app = express()
  app.use((_req, res, next) => {
    const currentSpanContext = opentelemetry.trace.getActiveSpan().spanContext()
    res.set('x-trace-id', currentSpanContext.traceId)
    next()
  })
  app.use((req, _res, next) => {
    logger.info({
      message: 'request',
      url: req.url,
      method: req.method
    })
    next()
  })
  app.use(express.json())
  app.get('/ping', (_req, res) => res.send('pong'))
  app.get('/metrics', async (_req, res) => res.send(await metricsRegistry.metrics()))
  await new Promise(resolve => app.listen(process.env.PORT || 3000, resolve))
  logger.info({
    message: 'Express API server listening...'
  })
}

run()
