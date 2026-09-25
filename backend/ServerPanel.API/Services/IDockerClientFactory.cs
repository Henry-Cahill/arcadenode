using Docker.DotNet;

namespace ServerPanel.API.Services;

public interface IDockerClientFactory
{
    /// <summary>
    /// Returns a DockerClient for the given endpoint (or the configured default when null).
    /// Clients are cached and reused per endpoint.
    /// </summary>
    DockerClient GetClient(string? endpoint = null);
}
