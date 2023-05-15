use std::{time::Instant, convert::Infallible, net::SocketAddr};

use hyper::{Request, Body, Response, StatusCode, Server};
use once_cell::sync::Lazy;
use opentelemetry::{sdk::{propagation::TraceContextPropagator, self}, trace::{Tracer, TraceContextExt}, Key};
use opentelemetry_api::Context;
use routerify::{prelude::RequestExt, RequestInfo, Router, Middleware, RouterService};
use tokio::{runtime};

static TRACER: Lazy<sdk::trace::Tracer> = Lazy::new(|| {
  opentelemetry::global::set_text_map_propagator(TraceContextPropagator::new());
  let service_name = std::env::var("SERVICE_NAME").unwrap();
  let collector_endpoint = std::env::var("ZIPKIN_EXPORTER_ENDPOINT").unwrap();
  return opentelemetry_zipkin::new_pipeline()
      .with_service_name(service_name)
      .with_collector_endpoint(collector_endpoint)
      .install_simple()
      .unwrap();
});

#[derive(Clone)]
struct RequestContext {
  pub start: Instant,
  pub trace_context: Context
}

pub async fn pre_router_middleware(req: Request<Body>) -> Result<Request<Body>, Infallible> {
  return TRACER.in_span("middleware", move |cx| {
      let trace_id = cx.span().span_context().trace_id();
      cx.span().set_attribute(Key::new("method").string(req.method().to_string()));
      cx.span().set_attribute(Key::new("path").string(req.uri().to_string()));
      let start = Instant::now();
      req.set_context(RequestContext {
        start,
        trace_context: cx
      });
      log::info!("pre_router_middleware: {} {} {}", trace_id, req.method(), req.uri().path());
      Ok(req)
  });
}

pub async fn post_router_middleware(res: Response<Body>, req_info: RequestInfo) -> Result<Response<Body>, Infallible> {
  let request_context = req_info.context::<RequestContext>().unwrap();
  let span = request_context.trace_context.span();
  let trace_id = span.span_context().trace_id();
  let elapsed = request_context.start.elapsed().as_millis();
  log::info!("post_router_middleware: {} {}ms {} {}", trace_id, elapsed, req_info.method(), req_info.uri().path());
  Ok(res)
}

pub async fn route_ping(req: Request<Body>) -> Result<Response<Body>, Infallible> {
  let request_context: RequestContext = req.context().unwrap();
  let span = request_context.trace_context.span();
  let trace_id = span.span_context().trace_id();
  log::info!("{trace_id}");
    Ok(
        Response::builder()
        .status(StatusCode::OK)
        .body(Body::from("pong"))
        .unwrap(),
    )
}
  
pub async fn route_404(_req: Request<Body>) -> Result<Response<Body>, Infallible> {
    Ok(
      Response::builder()
        .status(StatusCode::NOT_FOUND)
        .body(Body::from(""))
        .unwrap(),
    )
}

fn main() {
  // runtime
  let runtime = runtime::Builder::new_current_thread().enable_all().build().unwrap();
  // tracer
  Lazy::force(&TRACER);
  // logs
  tracing_subscriber::fmt().json().init();
  // http server
  let port = 3000; // TODO: std::env?
  log::info!("binding http server to http://0.0.0.0:{port}");
  let router = Router::builder()
    .middleware(Middleware::pre(pre_router_middleware))
    .middleware(Middleware::post_with_info(post_router_middleware))
    .get("/ping", route_ping)
    .any(route_404)
    .build()
    .unwrap();
  let service = RouterService::new(router).unwrap();
  let addr: SocketAddr = format!("0.0.0.0:{port}").parse().unwrap();
  return runtime.block_on(async {
    Server::bind(&addr).serve(service).await.unwrap();
  });
}
