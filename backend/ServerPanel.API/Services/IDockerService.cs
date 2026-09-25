using ServerPanel.API.DTOs;
using ServerPanel.API.Models;

namespace ServerPanel.API.Services;

public interface IDockerService
{
    Task<string> CreateContainerAsync(GameServer server);
    Task<bool> StartContainerAsync(string containerId);
    Task<bool> StopContainerAsync(string containerId);
    Task<bool> RestartContainerAsync(string containerId);
    Task<bool> RemoveContainerAsync(string containerId);
    Task<ServerStatsDto?> GetContainerStatsAsync(Guid serverId, string containerId);
    Task<string> GetContainerLogsAsync(string containerId, int tail = 100);
    Task<bool> SendCommandAsync(string containerId, string command);
}
