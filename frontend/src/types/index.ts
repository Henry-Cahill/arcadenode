export interface User {
  id: string
  username: string
  email: string
  firstName: string
  lastName: string
  role: 'User' | 'SubUser' | 'Admin' | 'SuperAdmin'
  isActive: boolean
  createdAt: string
  lastLoginAt: string | null
}

export interface AuthResponse {
  token: string
  user: User
  expiresAt: string
}

export interface InviteCode {
  id: string
  code: string
  maxUses: number
  timesUsed: number
  expiresAt: string | null
  isRevoked: boolean
  isValid: boolean
  createdAt: string
  createdByUsername: string
}

export interface Server {
  id: string
  name: string
  description: string
  identifier: string
  containerId: string | null
  dockerImage: string
  startupCommand: string | null
  memoryLimit: number
  cpuLimit: number
  diskLimit: number
  port: number
  ipAddress: string
  status: ServerStatus
  isSuspended: boolean
  createdAt: string
  lastStartedAt: string | null
  ownerId: string
  ownerUsername: string
  nodeId: string
  nodeName: string
}

export type ServerStatus =
  | 'Stopped'
  | 'Starting'
  | 'Running'
  | 'Stopping'
  | 'Error'
  | 'Installing'
  | 'Suspended'

export interface ServerStats {
  serverId: string
  status: ServerStatus
  memoryUsage: number
  cpuUsage: number
  diskUsage: number
  networkRxBytes: number
  networkTxBytes: number
  timestamp: string
}

export interface Node {
  id: string
  name: string
  description: string
  fqdn: string
  daemonPort: number
  sftpPort: number
  useSsl: boolean
  behindProxy: boolean
  dockerEndpoint: string
  // Returned only from GET /nodes/{id}/token (SuperAdmin), not in list/detail responses.
  daemonToken?: string | null
  totalMemory: number
  totalDisk: number
  allocatedMemory: number
  allocatedDisk: number
  isOnline: boolean
  isMaintenanceMode: boolean
  serverCount: number
  createdAt: string
  lastCheckedAt: string | null
}

export interface Allocation {
  id: string
  ipAddress: string
  port: number
  alias: string | null
  isAssigned: boolean
  nodeId: string
  serverId: string | null
  serverName: string | null
}

export interface Nest {
  id: string
  name: string
  description: string
  author: string
  eggCount: number
  createdAt: string
}

export interface Egg {
  id: string
  name: string
  description: string
  dockerImage: string
  startupCommand: string
  nestId: string
  nestName: string
  variables: EggVariable[] | null
  createdAt: string
}

export interface EggVariable {
  name: string
  description: string
  envVariable: string
  defaultValue: string
  userViewable: boolean
  userEditable: boolean
  rules: string | null
}

export interface DashboardStats {
  totalUsers: number
  totalServers: number
  totalNodes: number
  runningServers: number
  onlineNodes: number
  totalAllocatedMemory: number
  totalAllocatedDisk: number
}

export interface CreateServerRequest {
  name: string
  description?: string
  nodeId: string
  eggId?: string
  dockerImage: string
  startupCommand?: string
  memoryLimit?: number
  cpuLimit?: number
  diskLimit?: number
  port?: number
  environmentVariables?: Record<string, string>
}

export interface CreateNodeRequest {
  name: string
  description?: string
  fqdn: string
  daemonPort?: number
  sftpPort?: number
  useSsl?: boolean
  behindProxy?: boolean
  totalMemory?: number
  totalDisk?: number
  memoryOverallocate?: number
  diskOverallocate?: number
  dockerEndpoint?: string
}

export interface NodeConnectionTestResult {
  success: boolean
  message: string
  dockerVersion: string | null
  operatingSystem: string | null
  containerCount: number | null
  memoryTotal: number | null
  memoryAvailable: number | null
}

// Game Template / Deployment Types
export interface GameTemplate {
  id: string
  name: string
  description: string
  icon: string
  category: string
  dockerImage: string
  defaultMemory: number
  defaultCpu: number
  defaultDisk: number
  ports: GamePort[]
  variables: GameVariable[]
  notes: string | null
}

export interface GamePort {
  name: string
  defaultPort: number
  protocol: string
  required: boolean
  description: string
}

export interface GameVariable {
  name: string
  envVariable: string
  defaultValue: string
  type: 'text' | 'password' | 'number' | 'select' | 'boolean'
  description: string
  required: boolean
  options: string[] | null
  validation: string | null
}

export interface DeployServerRequest {
  gameTemplateId: string
  serverName: string
  description?: string
  nodeId: string
  memoryLimit?: number
  cpuLimit?: number
  diskLimit?: number
  portMappings?: Record<number, number>
  variables: Record<string, string>
}

export interface DeploymentProgress {
  deploymentId: string
  status: string
  progress: number
  currentStep: string | null
  errorMessage: string | null
  serverId: string | null
}

export interface ResourceRecommendation {
  memory: number
  cpu: number
  disk: number
  notes: string
}

// Cartridge Types
export interface CartridgeListItem {
  id: string
  name: string
  description: string
  category: string
  tags: string[]
  icon: string | null
  dockerImage: string
  recommendedMemory: number
  recommendedCpu: number
  defaultPort: number
}

export interface CartridgeDetail {
  id: string
  name: string
  author: string
  description: string
  category: string
  tags: string[]
  website: string | null
  icon: string | null
  docker: {
    image: string
    baseImage: string | null
  }
  ports: CartridgePort[]
  resources: {
    memory: CartridgeResourceLimit
    cpu: CartridgeResourceLimit
  }
  variables: CartridgeVariable[]
  variableGroups: CartridgeVariableGroup[] | null
  console: CartridgeConsole | null
  startup: {
    command: string
    readyPattern: string | null
    readyTimeout: number
  }
  process: {
    stopCommand: string
    stopTimeout: number
    restartOnCrash: boolean
  }
}

export interface CartridgePort {
  name: string
  default: number
  protocol: string
  required: boolean
  description: string | null
}

export interface CartridgeResourceLimit {
  minimum: number
  recommended: number
  maximum: number
}

export interface CartridgeVariable {
  id: string
  name: string
  description: string
  envVariable: string
  type: 'string' | 'integer' | 'boolean'
  default: unknown
  required: boolean
  userViewable: boolean
  userEditable: boolean
  validation: CartridgeVariableValidation | null
  ui: CartridgeVariableUI | null
}

export interface CartridgeVariableValidation {
  min: number | null
  max: number | null
  minLength: number | null
  maxLength: number | null
  pattern: string | null
}

export interface CartridgeVariableUI {
  component: 'text' | 'textarea' | 'password' | 'number' | 'slider' | 'switch' | 'select'
  placeholder: string | null
  group: string | null
  help: string | null
  options: { value: string; label: string }[] | null
  step: number | null
  marks: number[] | null
  rows: number | null
  prefix: string | null
  suffix: string | null
  onLabel: string | null
  offLabel: string | null
}

export interface CartridgeVariableGroup {
  id: string
  name: string
  description: string | null
  order: number
  collapsed: boolean
  adminOnly: boolean
}

export interface CartridgeConsole {
  enabled: boolean
  type: string
  commands: CartridgeConsoleCommand[] | null
}

export interface CartridgeConsoleCommand {
  name: string
  command: string
  description: string | null
  parameters: {
    name: string
    type: string
    required: boolean
    default: unknown
    options: string[] | null
  }[] | null
}

export interface CartridgeCategory {
  name: string
  count: number
}

export interface CreateCartridgeServerRequest {
  name: string
  description?: string
  nodeId: string
  cartridgeId: string
  memoryLimit?: number
  cpuLimit?: number
  diskLimit?: number
  port?: number
  variables: Record<string, unknown>
}

