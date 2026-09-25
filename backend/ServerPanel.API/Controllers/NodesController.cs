using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using ServerPanel.API.Common;
using ServerPanel.API.DTOs;
using ServerPanel.API.Services;

namespace ServerPanel.API.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize(Roles = "Admin,SuperAdmin")]
public class NodesController : ControllerBase
{
    private readonly INodeService _nodeService;

    public NodesController(INodeService nodeService)
    {
        _nodeService = nodeService;
    }

    /// <summary>
    /// Get all nodes
    /// </summary>
    [HttpGet]
    [ProducesResponseType(typeof(IEnumerable<NodeDto>), 200)]
    public async Task<IActionResult> GetNodes([FromQuery] int? page = null, [FromQuery] int? pageSize = null)
    {
        var (p, ps) = Pagination.Resolve(page, pageSize);
        var result = await _nodeService.GetAllNodesAsync(p, ps);

        Response.ApplyPaginationHeaders(result);
        return Ok(result.Items);
    }

    /// <summary>
    /// Get node by ID
    /// </summary>
    [HttpGet("{id:guid}")]
    [ProducesResponseType(typeof(NodeDto), 200)]
    [ProducesResponseType(404)]
    public async Task<IActionResult> GetNode(Guid id)
    {
        var node = await _nodeService.GetNodeByIdAsync(id);
        if (node == null) return NotFound();

        return Ok(node);
    }

    /// <summary>
    /// Get the daemon token for a node (SuperAdmin only).
    /// </summary>
    [HttpGet("{id:guid}/token")]
    [Authorize(Roles = "SuperAdmin")]
    [ProducesResponseType(200)]
    [ProducesResponseType(404)]
    public async Task<IActionResult> GetNodeToken(Guid id)
    {
        var token = await _nodeService.GetNodeTokenAsync(id);
        if (token == null) return NotFound();

        return Ok(new { token });
    }

    /// <summary>
    /// Create a new node
    /// </summary>
    [HttpPost]
    [ProducesResponseType(typeof(NodeDto), 201)]
    [ProducesResponseType(400)]
    public async Task<IActionResult> CreateNode([FromBody] CreateNodeRequest request)
    {
        try
        {
            var node = await _nodeService.CreateNodeAsync(request);
            if (node == null)
            {
                return BadRequest(new { message = "Node with this FQDN already exists" });
            }

            return CreatedAtAction(nameof(GetNode), new { id = node.Id }, node);
        }
        catch (Exception ex)
        {
            return BadRequest(new { message = $"Failed to create node: {ex.Message}" });
        }
    }

    /// <summary>
    /// Update node settings
    /// </summary>
    [HttpPut("{id:guid}")]
    [ProducesResponseType(typeof(NodeDto), 200)]
    [ProducesResponseType(404)]
    public async Task<IActionResult> UpdateNode(Guid id, [FromBody] UpdateNodeRequest request)
    {
        var node = await _nodeService.UpdateNodeAsync(id, request);
        if (node == null) return NotFound();

        return Ok(node);
    }

    /// <summary>
    /// Delete a node
    /// </summary>
    [HttpDelete("{id:guid}")]
    [ProducesResponseType(204)]
    [ProducesResponseType(400)]
    public async Task<IActionResult> DeleteNode(Guid id)
    {
        var success = await _nodeService.DeleteNodeAsync(id);
        if (!success)
        {
            return BadRequest(new { message = "Cannot delete node with existing servers" });
        }

        return NoContent();
    }

    /// <summary>
    /// Get node allocations
    /// </summary>
    [HttpGet("{id:guid}/allocations")]
    [ProducesResponseType(typeof(IEnumerable<AllocationDto>), 200)]
    public async Task<IActionResult> GetAllocations(Guid id)
    {
        var allocations = await _nodeService.GetNodeAllocationsAsync(id);
        return Ok(allocations);
    }

    /// <summary>
    /// Create allocations for a node
    /// </summary>
    [HttpPost("{id:guid}/allocations")]
    [ProducesResponseType(201)]
    [ProducesResponseType(400)]
    public async Task<IActionResult> CreateAllocations(Guid id, [FromBody] CreateAllocationBulkRequest request)
    {
        var createRequest = new CreateAllocationRequest(id, request.IpAddress, request.StartPort, request.EndPort, request.Alias);
        var success = await _nodeService.CreateAllocationsAsync(createRequest);

        if (!success)
        {
            return BadRequest(new { message = "Failed to create allocations" });
        }

        return Created("", new { message = "Allocations created successfully" });
    }

    /// <summary>
    /// Delete an allocation
    /// </summary>
    [HttpDelete("allocations/{allocationId:guid}")]
    [ProducesResponseType(204)]
    [ProducesResponseType(400)]
    public async Task<IActionResult> DeleteAllocation(Guid allocationId)
    {
        var success = await _nodeService.DeleteAllocationAsync(allocationId);
        if (!success)
        {
            return BadRequest(new { message = "Cannot delete assigned allocation" });
        }

        return NoContent();
    }

    /// <summary>
    /// Test connection to a Docker endpoint
    /// </summary>
    [HttpPost("test-connection")]
    [ProducesResponseType(typeof(NodeConnectionTestResult), 200)]
    public async Task<IActionResult> TestConnection([FromBody] TestNodeConnectionRequest request)
    {
        var result = await _nodeService.TestNodeConnectionAsync(request.DockerEndpoint);
        return Ok(result);
    }

    /// <summary>
    /// Test connection to an existing node
    /// </summary>
    [HttpPost("{id:guid}/test-connection")]
    [ProducesResponseType(typeof(NodeConnectionTestResult), 200)]
    [ProducesResponseType(404)]
    public async Task<IActionResult> TestNodeConnection(Guid id)
    {
        var result = await _nodeService.TestNodeConnectionByIdAsync(id);
        if (result.Message == "Node not found")
        {
            return NotFound(new { message = "Node not found" });
        }
        return Ok(result);
    }

    /// <summary>
    /// Regenerate daemon token for a node
    /// </summary>
    [HttpPost("{id:guid}/regenerate-token")]
    [ProducesResponseType(200)]
    [ProducesResponseType(404)]
    public async Task<IActionResult> RegenerateToken(Guid id)
    {
        var success = await _nodeService.RegenerateNodeTokenAsync(id);
        if (!success)
        {
            return NotFound(new { message = "Node not found" });
        }
        return Ok(new { message = "Token regenerated successfully" });
    }
}
