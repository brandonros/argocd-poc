using MicroservicePOC.Model;
using Microsoft.AspNetCore.Mvc;

namespace MicroservicePOC.Controllers;
[ApiController]
[Route("httpClient")]
public class HttpClientController : ControllerBase
{
    private readonly ILogger<HttpClientController> _logger;
    private readonly HttpClient _client;

    public HttpClientController(ILogger<HttpClientController> logger)
    {
        _logger = logger;
        _client = new HttpClient(); // TODO: this is just quick + dirty for proof of concept
    }

    [HttpPost("api/call")]
    public async Task<IActionResult> ApiCall([FromBody] ApiCallRequest request)
    {
        _logger.LogInformation($"apiCall url = {request.url}");
        using HttpResponseMessage response = await _client.GetAsync(request.url);
        response.EnsureSuccessStatusCode();
        string responseBody = await response.Content.ReadAsStringAsync();
        return new OkObjectResult(responseBody);
    }
}
