using ServerPanel.API.DTOs;

namespace ServerPanel.API.Services;

public interface INodeService
{
    Task<PagedResult<NodeDto>> GetAllNodesAsync(int page = 1, int pageSize = int.MaxValue);
    Task<NodeDto?> GetNodeByIdAsync(Guid id);
    Task<NodeDto?> CreateNodeAsync(CreateNodeRequest request);
    Task<NodeDto?> UpdateNodeAsync(Guid id, UpdateNodeRequest request);
    Task<bool> DeleteNodeAsync(Guid id);
    Task<bool> UpdateNodeStatusAsync(Guid id, bool isOnline);
    Task<IEnumerable<AllocationDto>> GetNodeAllocationsAsync(Guid nodeId);
    Task<bool> CreateAllocationsAsync(CreateAllocationRequest request);
    Task<bool> DeleteAllocationAsync(Guid id);
    Task<NodeConnectionTestResult> TestNodeConnectionAsync(string dockerEndpoint);
    Task<NodeConnectionTestResult> TestNodeConnectionByIdAsync(Guid nodeId);
    Task<bool> RegenerateNodeTokenAsync(Guid nodeId);
    Task<string?> GetNodeTokenAsync(Guid nodeId);
}
