using StackExchange.Redis;

namespace MicroservicePOC.Services
{
  public interface IRedisService
  {
    Task<string> Get(string key);
  }

  public class RedisService : IRedisService
  {
    private readonly IConnectionMultiplexer _connectionMultiplexer;

    public RedisService(IConnectionMultiplexer connectionMultiplexer)
    {
        _connectionMultiplexer = connectionMultiplexer;
    }

    public async Task<string> Get(string key)
    {
      var db = _connectionMultiplexer.GetDatabase();
      return await db.StringGetAsync(key);
    }
  }
}
