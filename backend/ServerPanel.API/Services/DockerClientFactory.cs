using System.Collections.Concurrent;
using Docker.DotNet;

namespace ServerPanel.API.Services;

/// <summary>
/// Creates and caches one <see cref="DockerClient"/> per endpoint. Registered as a
/// singleton so clients are reused across requests (rather than a new client per
/// scope) and disposed together at application shutdown. Enables per-node endpoints.
/// </summary>
public sealed class DockerClientFactory : IDockerClientFactory, IDisposable
{
    private readonly ConcurrentDictionary<string, DockerClient> _clients = new();
    private readonly string _defaultEndpoint;

    public DockerClientFactory(IConfiguration configuration)
    {
        _defaultEndpoint = configuration["Docker:NodeUrl"] ?? "tcp://localhost:2375";
    }

    public DockerClient GetClient(string? endpoint = null)
    {
        var target = string.IsNullOrWhiteSpace(endpoint) ? _defaultEndpoint : endpoint;
        return _clients.GetOrAdd(target, ep => new DockerClientConfiguration(new Uri(ep)).CreateClient());
    }

    public void Dispose()
    {
        foreach (var client in _clients.Values)
        {
            client.Dispose();
        }
        _clients.Clear();
    }
}
