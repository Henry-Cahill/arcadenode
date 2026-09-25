import api from '@/lib/httpClient'
import type {
  AuthResponse,
  Server,
  ServerStats,
  Node,
  Allocation,
  Egg,
  Nest,
  DashboardStats,
  CreateServerRequest,
  CreateNodeRequest,
  User,
  NodeConnectionTestResult,
  InviteCode,
  GameTemplate,
  DeployServerRequest,
  DeploymentProgress,
  ResourceRecommendation,
  CartridgeListItem,
  CartridgeDetail,
  CartridgeCategory,
  CreateCartridgeServerRequest,
} from '@/types'

// Auth
export const authService = {
  login: async (username: string, password: string): Promise<AuthResponse> => {
    const { data } = await api.post<AuthResponse>('/auth/login', { username, password })
    return data
  },

  register: async (
    username: string,
    email: string,
    password: string,
    inviteCode: string,
    firstName?: string,
    lastName?: string
  ): Promise<AuthResponse> => {
    const { data } = await api.post<AuthResponse>('/auth/register', {
      username,
      email,
      password,
      inviteCode,
      firstName,
      lastName,
    })
    return data
  },

  getCurrentUser: async (): Promise<User> => {
    const { data } = await api.get<User>('/auth/me')
    return data
  },

  updateProfile: async (firstName?: string, lastName?: string, email?: string) => {
    await api.put('/auth/me', { firstName, lastName, email })
  },

  changePassword: async (currentPassword: string, newPassword: string) => {
    await api.post('/auth/change-password', { currentPassword, newPassword })
  },
}

// Servers
export const serverService = {
  getAll: async (): Promise<Server[]> => {
    const { data } = await api.get<Server[]>('/servers')
    return data
  },

  getById: async (id: string): Promise<Server> => {
    const { data } = await api.get<Server>(`/servers/${id}`)
    return data
  },

  getByIdentifier: async (identifier: string): Promise<Server> => {
    const { data } = await api.get<Server>(`/servers/identifier/${identifier}`)
    return data
  },

  create: async (request: CreateServerRequest): Promise<Server> => {
    const { data } = await api.post<Server>('/servers', request)
    return data
  },

  update: async (id: string, request: Partial<CreateServerRequest>): Promise<Server> => {
    const { data } = await api.put<Server>(`/servers/${id}`, request)
    return data
  },

  delete: async (id: string): Promise<void> => {
    await api.delete(`/servers/${id}`)
  },

  power: async (id: string, action: 'start' | 'stop' | 'restart' | 'kill') => {
    const { data } = await api.post(`/servers/${id}/power`, { action })
    return data
  },

  getLogs: async (id: string, tail: number = 100): Promise<{ logs: string }> => {
    const { data } = await api.get<{ logs: string }>(`/servers/${id}/logs`, {
      params: { tail },
    })
    return data
  },

  sendCommand: async (id: string, command: string) => {
    const { data } = await api.post(`/servers/${id}/command`, { command })
    return data
  },

  getStats: async (id: string): Promise<ServerStats> => {
    const { data } = await api.get<ServerStats>(`/servers/${id}/stats`)
    return data
  },

  suspend: async (id: string, suspended: boolean) => {
    await api.post(`/servers/${id}/suspend`, null, { params: { suspended } })
  },
}

// Nodes
export const nodeService = {
  getAll: async (): Promise<Node[]> => {
    const { data } = await api.get<Node[]>('/nodes')
    return data
  },

  getById: async (id: string): Promise<Node> => {
    const { data } = await api.get<Node>(`/nodes/${id}`)
    return data
  },

  create: async (request: CreateNodeRequest): Promise<Node> => {
    const { data } = await api.post<Node>('/nodes', request)
    return data
  },

  update: async (id: string, request: Partial<CreateNodeRequest>): Promise<Node> => {
    const { data } = await api.put<Node>(`/nodes/${id}`, request)
    return data
  },

  delete: async (id: string): Promise<void> => {
    await api.delete(`/nodes/${id}`)
  },

  getAllocations: async (nodeId: string): Promise<Allocation[]> => {
    const { data } = await api.get<Allocation[]>(`/nodes/${nodeId}/allocations`)
    return data
  },

  createAllocations: async (
    nodeId: string,
    ipAddress: string,
    startPort: number,
    endPort?: number,
    alias?: string
  ) => {
    await api.post(`/nodes/${nodeId}/allocations`, {
      ipAddress,
      startPort,
      endPort,
      alias,
    })
  },

  deleteAllocation: async (allocationId: string) => {
    await api.delete(`/nodes/allocations/${allocationId}`)
  },

  testConnection: async (dockerEndpoint: string): Promise<NodeConnectionTestResult> => {
    const { data } = await api.post<NodeConnectionTestResult>('/nodes/test-connection', {
      dockerEndpoint,
    })
    return data
  },

  testNodeConnection: async (nodeId: string): Promise<NodeConnectionTestResult> => {
    const { data } = await api.post<NodeConnectionTestResult>(`/nodes/${nodeId}/test-connection`)
    return data
  },

  regenerateToken: async (nodeId: string): Promise<void> => {
    await api.post(`/nodes/${nodeId}/regenerate-token`)
  },
}

// Admin
export const adminService = {
  getDashboardStats: async (): Promise<DashboardStats> => {
    const { data } = await api.get<DashboardStats>('/admin/dashboard')
    return data
  },

  getAllUsers: async (): Promise<User[]> => {
    const { data } = await api.get<User[]>('/admin/users')
    return data
  },

  deleteUser: async (id: string): Promise<void> => {
    await api.delete(`/admin/users/${id}`)
  },

  getNests: async (): Promise<Nest[]> => {
    const { data } = await api.get<Nest[]>('/admin/nests')
    return data
  },

  getEggs: async (nestId?: string): Promise<Egg[]> => {
    const url = nestId ? `/admin/nests/${nestId}/eggs` : '/admin/eggs'
    const { data } = await api.get<Egg[]>(url)
    return data
  },

  // Invite code management
  getInviteCodes: async (): Promise<InviteCode[]> => {
    const { data } = await api.get<InviteCode[]>('/admin/invites')
    return data
  },

  createInviteCode: async (maxUses: number = 1, expiresAt?: string): Promise<InviteCode> => {
    const { data } = await api.post<InviteCode>('/admin/invites', { maxUses, expiresAt })
    return data
  },

  revokeInviteCode: async (id: string): Promise<void> => {
    await api.delete(`/admin/invites/${id}`)
  },
}

// Deployment
export const deploymentService = {
  getTemplates: async (): Promise<GameTemplate[]> => {
    const { data } = await api.get<GameTemplate[]>('/deployment/templates')
    return data
  },

  getTemplate: async (id: string): Promise<GameTemplate> => {
    const { data } = await api.get<GameTemplate>(`/deployment/templates/${id}`)
    return data
  },

  getTemplatesByCategory: async (category: string): Promise<GameTemplate[]> => {
    const { data } = await api.get<GameTemplate[]>(`/deployment/templates/category/${category}`)
    return data
  },

  deploy: async (request: DeployServerRequest): Promise<Server> => {
    const { data } = await api.post<Server>('/deployment/deploy', request)
    return data
  },

  quickDeploy: async (
    gameTemplateId: string,
    serverName: string,
    nodeId: string,
    overrideVariables?: Record<string, string>
  ): Promise<Server> => {
    const { data } = await api.post<Server>('/deployment/quick-deploy', {
      gameTemplateId,
      serverName,
      nodeId,
      overrideVariables,
    })
    return data
  },

  getDeploymentStatus: async (serverId: string): Promise<DeploymentProgress> => {
    const { data } = await api.get<DeploymentProgress>(`/deployment/status/${serverId}`)
    return data
  },

  getRecommendations: async (templateId: string, playerCount: number): Promise<ResourceRecommendation> => {
    const { data } = await api.get<ResourceRecommendation>(
      `/deployment/templates/${templateId}/recommendations`,
      { params: { playerCount } }
    )
    return data
  },
}

// Cartridges
export const cartridgeService = {
  getAll: async (): Promise<CartridgeListItem[]> => {
    const { data } = await api.get<CartridgeListItem[]>('/cartridges')
    return data
  },

  getById: async (id: string): Promise<CartridgeDetail> => {
    const { data } = await api.get<CartridgeDetail>(`/cartridges/${id}`)
    return data
  },

  getByCategory: async (category: string): Promise<CartridgeListItem[]> => {
    const { data } = await api.get<CartridgeListItem[]>(`/cartridges/category/${category}`)
    return data
  },

  getCategories: async (): Promise<CartridgeCategory[]> => {
    const { data } = await api.get<CartridgeCategory[]>('/cartridges/categories')
    return data
  },

  validateVariables: async (
    cartridgeId: string, 
    values: Record<string, unknown>
  ): Promise<{ valid: boolean; errors: string[] }> => {
    const { data } = await api.post<{ valid: boolean; errors: string[] }>(
      `/cartridges/${cartridgeId}/validate`,
      values
    )
    return data
  },

  reload: async (): Promise<void> => {
    await api.post('/cartridges/reload')
  },

  createServer: async (request: CreateCartridgeServerRequest): Promise<Server> => {
    const { data } = await api.post<Server>('/servers/from-cartridge', request)
    return data
  },
}
