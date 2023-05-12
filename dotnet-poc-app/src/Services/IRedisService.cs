namespace MicroservicePOC.Services
{
  public interface IRedisService
  {
    Task<string> Get(string key);
  }
}
