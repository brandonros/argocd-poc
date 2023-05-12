using MicroservicePOC.Services;
using OpenTelemetry.Resources;
using OpenTelemetry.Trace;
using OpenTelemetry.Metrics;
using StackExchange.Redis;
using MicroservicePOC.Middleware;
using NLog.Web;

var logger = NLogBuilder.ConfigureNLog("NLog.config").GetCurrentClassLogger();
var builder = WebApplication.CreateBuilder(args);
// logging
builder.Logging.ClearProviders();
builder.Logging.SetMinimumLevel(Microsoft.Extensions.Logging.LogLevel.Trace);
builder.Host.UseNLog();
// Add services to the container.
builder.Services.AddControllers();
builder.Services.AddSwaggerGen(c =>
{
    c.SwaggerDoc("v1", new() { Title = "WeatherForecastApi", Version = "v1" });
});
builder.Services.AddSingleton<IConnectionMultiplexer, ConnectionMultiplexer>(x =>
{
    return ConnectionMultiplexer.Connect(Environment.GetEnvironmentVariable("REDIS_CONNECTION_STRING"));
});
builder.Services.AddScoped<IRedisService, RedisService>();
builder.Services.AddOpenTelemetry()
    .WithMetrics(provider =>
    {
        provider
            .AddRuntimeInstrumentation()
            .AddProcessInstrumentation()
            .AddAspNetCoreInstrumentation()
            .AddHttpClientInstrumentation()
            .AddPrometheusExporter();
    })
    .WithTracing(provider =>
    {
        var appName = Environment.GetEnvironmentVariable("APP_NAME");
        provider
            .AddSource(appName)
            .SetResourceBuilder(ResourceBuilder.CreateDefault().AddService(appName))
            .AddAspNetCoreInstrumentation()
            .AddHttpClientInstrumentation()
            .AddRedisInstrumentation()
            .AddZipkinExporter(o =>
            {
                o.Endpoint = new Uri(Environment.GetEnvironmentVariable("ZIPKIN_EXPORTER_ENDPOINT"));
            });
    });
var app = builder.Build();
// Configure the HTTP request pipeline.
if (builder.Environment.IsDevelopment())
{
    app.UseDeveloperExceptionPage();
    app.UseSwagger();
    app.UseSwaggerUI(c => c.SwaggerEndpoint("/swagger/v1/swagger.json", "WeatherForecastApi v1"));
}
app.UseMiddleware<TraceIdMiddleware>();
app.UseAuthorization();
app.UseOpenTelemetryPrometheusScrapingEndpoint();
app.MapControllers();
// run
try
{
    app.Run();
}
catch (Exception ex)
{
    logger.Error(ex);
    throw;

}
finally
{
    NLog.LogManager.Shutdown();
}