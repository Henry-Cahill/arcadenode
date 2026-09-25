namespace ServerPanel.API.DTOs;

public class DashboardStats
{
    public int TotalUsers { get; set; }
    public int TotalServers { get; set; }
    public int TotalNodes { get; set; }
    public int RunningServers { get; set; }
    public int OnlineNodes { get; set; }
    public int TotalAllocatedMemory { get; set; }
    public int TotalAllocatedDisk { get; set; }
}
