using MicroservicePOC.Services;
using Microsoft.AspNetCore.Mvc;

namespace MicroservicePOC.Controllers;
[ApiController]
[Route("redis")]
public class RedisController : ControllerBase
{
    private readonly ILogger<RedisController> _logger;
    private readonly IRedisService _redisService;

    public RedisController(ILogger<RedisController> logger, IRedisService redisService)
    {
        _logger = logger;
        _redisService = redisService;
    }

    [HttpGet("keys/{keyName}")]
    public async Task<IActionResult> Get(string keyName)
    {
        _logger.LogInformation("redis");
        var value = await _redisService.Get(keyName);
        return new OkObjectResult(value);
    }
}
