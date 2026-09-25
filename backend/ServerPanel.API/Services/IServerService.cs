using ServerPanel.API.DTOs;
using ServerPanel.API.Models;

namespace ServerPanel.API.Services;

public interface IServerService
{
    Task<PagedResult<ServerDto>> GetAllServersAsync(int page = 1, int pageSize = int.MaxValue);
    Task<PagedResult<ServerDto>> GetUserServersAsync(Guid userId, int page = 1, int pageSize = int.MaxValue);
    Task<ServerDto?> GetServerByIdAsync(Guid id);
    Task<ServerDto?> GetServerByIdentifierAsync(string identifier);
    Task<ServerDto?> CreateServerAsync(CreateServerRequest request, Guid ownerId);
    Task<ServerDto?> CreateServerFromCartridgeAsync(CreateCartridgeServerRequest request, Guid ownerId);
    Task<ServerDto?> UpdateServerAsync(Guid id, UpdateServerRequest request);
    Task<bool> DeleteServerAsync(Guid id);
    Task<bool> UpdateServerStatusAsync(Guid id, ServerStatus status);
    Task<bool> SuspendServerAsync(Guid id, bool suspended);
}
