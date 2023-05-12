using Microsoft.AspNetCore.Mvc;

namespace MicroservicePOC.Controllers;
[ApiController]
[Route("ping")]
public class PingController : ControllerBase
{
    private readonly ILogger<PingController> _logger;

    public PingController(ILogger<PingController> logger)
    {
        _logger = logger;
    }

    [HttpGet]
    public IActionResult Get()
    {
        _logger.LogInformation("ping");
        return new OkObjectResult("pong");
    }
}
