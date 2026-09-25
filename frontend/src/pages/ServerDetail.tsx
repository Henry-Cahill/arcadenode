import { useState, useEffect, useRef } from 'react'
import { useParams, useNavigate } from 'react-router-dom'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { serverService } from '@/services/api'
import toast from 'react-hot-toast'
import clsx from 'clsx'
import { getStatusColor } from '@/lib/statusColors'
import { getErrorMessage } from '@/lib/errorHandler'
import { usePageTitle } from '@/lib/usePageTitle'
import {
  PlayIcon,
  StopIcon,
  ArrowPathIcon,
  CommandLineIcon,
  ChartBarIcon,
  Cog6ToothIcon,
  DocumentTextIcon,
  TrashIcon,
  GlobeAltIcon,
  ClockIcon,
  CpuChipIcon,
  CircleStackIcon,
  ServerIcon,
  ArrowDownTrayIcon,
  ArrowUpTrayIcon,
} from '@heroicons/react/24/outline'

type Tab = 'console' | 'files' | 'settings' | 'stats'

// Helper function to format bytes into human-readable format
function formatBytes(bytes: number): string {
  if (bytes === 0) return '0 B'
  const k = 1024
  const sizes = ['B', 'KiB', 'MiB', 'GiB', 'TiB']
  const i = Math.floor(Math.log(bytes) / Math.log(k))
  return `${(bytes / Math.pow(k, i)).toFixed(2)} ${sizes[i]}`
}

// Format uptime from seconds to human readable
function formatUptime(seconds: number): string {
  if (!seconds || seconds < 0) return '0s'
  const hours = Math.floor(seconds / 3600)
  const minutes = Math.floor((seconds % 3600) / 60)
  const secs = Math.floor(seconds % 60)
  
  if (hours > 0) {
    return `${hours}h ${minutes}m ${secs}s`
  } else if (minutes > 0) {
    return `${minutes}m ${secs}s`
  }
  return `${secs}s`
}

// Parse and colorize log lines
function parseLogLine(line: string, index: number) {
  // Try to detect log level/type
  const lowerLine = line.toLowerCase()
  let logType = 'LOG'
  let typeColor = 'text-gray-400'
  
  if (lowerLine.includes('error') || lowerLine.includes('exception') || lowerLine.includes('failed')) {
    logType = 'ERROR'
    typeColor = 'text-red-400'
  } else if (lowerLine.includes('warn')) {
    logType = 'WARN'
    typeColor = 'text-yellow-400'
  } else if (lowerLine.includes('info') || lowerLine.includes('[info]')) {
    logType = 'INFO'
    typeColor = 'text-blue-400'
  } else if (lowerLine.includes('debug')) {
    logType = 'DEBUG'
    typeColor = 'text-purple-400'
  } else if (lowerLine.includes('lua') || lowerLine.includes('script')) {
    logType = 'LUA'
    typeColor = 'text-cyan-400'
  }

  return (
    <div key={index} className="flex gap-3 py-0.5 hover:bg-white/5">
      <span className={clsx('font-medium w-12 flex-shrink-0', typeColor)}>{logType}</span>
      <span className="text-gray-500">:</span>
      <span className="text-gray-300 break-all">{line}</span>
    </div>
  )
}

export default function ServerDetail() {
  const { id } = useParams<{ id: string }>()
  const navigate = useNavigate()
  const queryClient = useQueryClient()
  const [activeTab, setActiveTab] = useState<Tab>('console')
  const [command, setCommand] = useState('')
  const [logs, setLogs] = useState('')
  const [showDeleteConfirm, setShowDeleteConfirm] = useState(false)
  const [uptime, setUptime] = useState(0)
  const [settingsName, setSettingsName] = useState('')
  const [settingsDescription, setSettingsDescription] = useState('')
  const consoleRef = useRef<HTMLDivElement>(null)

  const { data: server, isLoading } = useQuery({
    queryKey: ['server', id],
    queryFn: () => serverService.getById(id!),
    enabled: !!id,
    refetchInterval: 5000,
  })

  usePageTitle(server?.name ? `Server — ${server.name}` : 'Server Details')

  const { data: stats } = useQuery({
    queryKey: ['server-stats', id],
    queryFn: () => serverService.getStats(id!),
    enabled: !!id && server?.status === 'Running',
    refetchInterval: 2000,
  })

  // Sync settings form state when server data loads
  useEffect(() => {
    if (server) {
      setSettingsName(server.name)
      setSettingsDescription(server.description)
    }
  }, [server?.id])

  // Track uptime based on server.lastStartedAt
  useEffect(() => {
    if (server?.status === 'Running' && server.lastStartedAt) {
      const calculateUptime = () => {
        const startedAt = new Date(server.lastStartedAt!).getTime()
        const now = Date.now()
        return Math.max(0, Math.floor((now - startedAt) / 1000))
      }
      setUptime(calculateUptime())
      const interval = setInterval(() => {
        setUptime(calculateUptime())
      }, 1000)
      return () => clearInterval(interval)
    } else {
      setUptime(0)
    }
  }, [server?.status, server?.lastStartedAt])

  // Fetch logs - always try to fetch when we have a container ID
  useEffect(() => {
    if (id && server?.containerId) {
      const fetchLogs = async () => {
        try {
          const { logs: newLogs } = await serverService.getLogs(id, 200)
          setLogs(newLogs || '')
        } catch (error) {
          console.error('Failed to fetch logs:', error)
          setLogs('[Failed to fetch logs from server]')
        }
      }
      fetchLogs()
      // Poll more frequently when server is running
      const interval = setInterval(fetchLogs, server.status === 'Running' ? 2000 : 5000)
      return () => clearInterval(interval)
    } else if (server && !server.containerId) {
      setLogs('[Container not created yet - try starting the server]')
    }
  }, [id, server?.containerId, server?.status])

  // Auto-scroll console
  useEffect(() => {
    if (consoleRef.current) {
      consoleRef.current.scrollTop = consoleRef.current.scrollHeight
    }
  }, [logs])

  const powerMutation = useMutation({
    mutationFn: ({ action }: { action: 'start' | 'stop' | 'restart' | 'kill' }) =>
      serverService.power(id!, action),
    onSuccess: (_, { action }) => {
      toast.success(`Server ${action} command sent`)
      queryClient.invalidateQueries({ queryKey: ['server', id] })
    },
    onError: (error: unknown) => {
      toast.error(getErrorMessage(error, 'Power action failed'))
    },
  })

  const commandMutation = useMutation({
    mutationFn: (cmd: string) => serverService.sendCommand(id!, cmd),
    onSuccess: () => {
      setCommand('')
    },
    onError: () => {
      toast.error('Failed to send command')
    },
  })

  const updateMutation = useMutation({
    mutationFn: (request: { name: string; description: string }) =>
      serverService.update(id!, request),
    onSuccess: () => {
      toast.success('Server settings saved')
      queryClient.invalidateQueries({ queryKey: ['server', id] })
      queryClient.invalidateQueries({ queryKey: ['servers'] })
    },
    onError: (error: unknown) => {
      toast.error(getErrorMessage(error, 'Failed to save settings'))
    },
  })

  const deleteMutation = useMutation({
    mutationFn: () => serverService.delete(id!),
    onSuccess: () => {
      toast.success('Server deleted successfully')
      queryClient.invalidateQueries({ queryKey: ['servers'] })
      navigate('/servers')
    },
    onError: (error: unknown) => {
      toast.error(getErrorMessage(error, 'Failed to delete server'))
    },
  })

  const handleDeleteServer = () => {
    deleteMutation.mutate()
    setShowDeleteConfirm(false)
  }

  const handleSendCommand = (e: React.FormEvent) => {
    e.preventDefault()
    if (command.trim() && server?.status === 'Running') {
      commandMutation.mutate(command.trim())
    }
  }


  if (isLoading) {
    return (
      <div className="flex items-center justify-center min-h-[400px]">
        <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-primary-500" />
      </div>
    )
  }

  if (!server) {
    return (
      <div className="text-center py-12">
        <h2 className="text-xl font-semibold text-white">Server not found</h2>
      </div>
    )
  }

  const tabs = [
    { id: 'console' as Tab, name: 'Console', icon: CommandLineIcon },
    { id: 'stats' as Tab, name: 'Statistics', icon: ChartBarIcon },
    { id: 'files' as Tab, name: 'Files', icon: DocumentTextIcon },
    { id: 'settings' as Tab, name: 'Settings', icon: Cog6ToothIcon },
  ]

  // Parse logs into lines
  const logLines = logs ? logs.split('\n').filter(line => line.trim()) : []

  return (
    <div className="h-full">
      {/* Header */}
      <div className="flex flex-col lg:flex-row lg:items-center lg:justify-between gap-4 mb-4">
        <div className="flex items-center gap-4">
          <div className={clsx('w-3 h-3 rounded-full', getStatusColor(server.status))} />
          <div>
            <h1 className="text-2xl font-bold text-white">{server.name}</h1>
            <p className="text-sm text-gray-500">
              {server.identifier} • {server.nodeName}
            </p>
          </div>
        </div>

        {/* Power Controls - ClickByte style */}
        <div className="flex items-center gap-2">
          <button
            onClick={() => powerMutation.mutate({ action: 'start' })}
            disabled={server.status === 'Running' || server.isSuspended || powerMutation.isPending}
            className="flex items-center gap-2 px-5 py-2.5 bg-emerald-600 hover:bg-emerald-500 disabled:bg-emerald-800/50 disabled:text-gray-400 disabled:cursor-not-allowed text-white font-medium rounded-lg transition-all shadow-lg shadow-emerald-900/30"
          >
            <PlayIcon className="h-4 w-4" />
            Start
          </button>
          <button
            onClick={() => powerMutation.mutate({ action: 'restart' })}
            disabled={server.status !== 'Running' || powerMutation.isPending}
            className="flex items-center gap-2 px-5 py-2.5 bg-gray-600 hover:bg-gray-500 disabled:bg-gray-700/50 disabled:text-gray-500 disabled:cursor-not-allowed text-white font-medium rounded-lg transition-all"
          >
            <ArrowPathIcon className="h-4 w-4" />
            Restart
          </button>
          <button
            onClick={() => powerMutation.mutate({ action: 'stop' })}
            disabled={server.status === 'Stopped' || powerMutation.isPending}
            className="flex items-center gap-2 px-5 py-2.5 bg-red-600 hover:bg-red-500 disabled:bg-red-800/50 disabled:text-gray-400 disabled:cursor-not-allowed text-white font-medium rounded-lg transition-all shadow-lg shadow-red-900/30"
          >
            <StopIcon className="h-4 w-4" />
            Stop
          </button>
          <button
            onClick={() => setShowDeleteConfirm(true)}
            disabled={server.status === 'Running' || deleteMutation.isPending}
            className="flex items-center gap-2 px-3 py-2.5 bg-red-900/50 hover:bg-red-800 disabled:bg-red-950/30 disabled:text-gray-600 disabled:cursor-not-allowed text-red-300 font-medium rounded-lg transition-all ml-2"
            title={server.status === 'Running' ? 'Stop the server before deleting' : 'Delete server'}
          >
            <TrashIcon className="h-4 w-4" />
          </button>
        </div>
      </div>

      {/* Delete Confirmation Modal */}
      {showDeleteConfirm && (
        <div className="fixed inset-0 bg-black/70 flex items-center justify-center z-50 backdrop-blur-sm">
          <div className="bg-[#1a1f2e] border border-gray-700/50 rounded-xl p-6 max-w-md mx-4 shadow-2xl">
            <h3 className="text-xl font-semibold text-white mb-2">Delete Server</h3>
            <p className="text-gray-400 mb-4">
              Are you sure you want to delete <span className="text-white font-medium">{server.name}</span>? 
              This action cannot be undone and all server data will be permanently lost.
            </p>
            <div className="flex justify-end gap-3">
              <button
                onClick={() => setShowDeleteConfirm(false)}
                className="px-4 py-2 bg-gray-700 hover:bg-gray-600 text-white font-medium rounded-lg transition-colors"
              >
                Cancel
              </button>
              <button
                onClick={handleDeleteServer}
                disabled={deleteMutation.isPending}
                className="flex items-center gap-2 px-4 py-2 bg-red-600 hover:bg-red-500 disabled:bg-red-800 text-white font-medium rounded-lg transition-colors"
              >
                {deleteMutation.isPending ? (
                  <>
                    <ArrowPathIcon className="h-4 w-4 animate-spin" />
                    Deleting...
                  </>
                ) : (
                  <>
                    <TrashIcon className="h-4 w-4" />
                    Delete Server
                  </>
                )}
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Tabs */}
      <div className="border-b border-gray-700/50 mb-4">
        <nav className="flex gap-1">
          {tabs.map((tab) => (
            <button
              key={tab.id}
              onClick={() => setActiveTab(tab.id)}
              className={clsx(
                'flex items-center gap-2 px-4 py-3 text-sm font-medium border-b-2 -mb-px transition-colors',
                activeTab === tab.id
                  ? 'border-cyan-500 text-cyan-400'
                  : 'border-transparent text-gray-500 hover:text-gray-300'
              )}
            >
              <tab.icon className="h-4 w-4" />
              {tab.name}
            </button>
          ))}
        </nav>
      </div>

      {/* Tab Content */}
      {activeTab === 'console' && (
        <div className="flex gap-4 h-[calc(100vh-280px)]">
          {/* Console Panel */}
          <div className="flex-1 bg-[#0d1117] border border-gray-800 rounded-xl overflow-hidden flex flex-col">
            {/* Console Header */}
            <div className="px-4 py-2 bg-[#161b22] border-b border-gray-800 flex items-center justify-between">
              <span className="text-sm text-gray-400">
                Container: {server.containerId ? server.containerId.substring(0, 12) : 'Not created'}
              </span>
              <span className={clsx(
                'text-xs px-3 py-1 rounded-full font-medium',
                server.status === 'Running' ? 'bg-emerald-500/20 text-emerald-400' :
                server.status === 'Stopped' ? 'bg-gray-700/50 text-gray-400' :
                'bg-yellow-500/20 text-yellow-400'
              )}>
                {server.status}
              </span>
            </div>
            
            {/* Console Output - ClickByte style */}
            <div
              ref={consoleRef}
              className="flex-1 overflow-auto p-4 font-mono text-sm bg-[#0d1117]"
            >
              {logLines.length > 0 ? (
                <div className="space-y-0">
                  {logLines.map((line, i) => parseLogLine(line, i))}
                </div>
              ) : server.containerId ? (
                <p className="text-gray-600 italic">Loading console output...</p>
              ) : (
                <p className="text-gray-600 italic">No container running. Click "Start" to launch the server.</p>
              )}
            </div>

            {/* Command Input - ClickByte style */}
            <form onSubmit={handleSendCommand} className="border-t border-gray-800 p-3 bg-[#161b22]">
              <div className="flex items-center gap-2">
                <span className="text-gray-500 font-mono text-lg">&gt;&gt;</span>
                <input
                  type="text"
                  value={command}
                  onChange={(e) => setCommand(e.target.value)}
                  placeholder={
                    server.status === 'Running'
                      ? 'Type a command...'
                      : 'Server must be running to send commands'
                  }
                  disabled={server.status !== 'Running'}
                  className="flex-1 px-3 py-2 bg-transparent border-none text-white placeholder-gray-600 focus:outline-none focus:ring-0 disabled:opacity-50 font-mono"
                />
                <button
                  type="submit"
                  disabled={server.status !== 'Running' || !command.trim()}
                  className="px-4 py-2 bg-cyan-600 hover:bg-cyan-500 disabled:bg-gray-700 disabled:text-gray-500 disabled:cursor-not-allowed text-white font-medium rounded-lg transition-colors"
                >
                  Send
                </button>
              </div>
            </form>
          </div>

          {/* Stats Sidebar - ClickByte style */}
          <div className="w-72 flex-shrink-0 bg-[#0d1117] border border-gray-800 rounded-xl p-4 space-y-4">
            {/* Address */}
            <div className="flex items-start gap-3">
              <div className="p-2 bg-gray-800/50 rounded-lg">
                <GlobeAltIcon className="h-5 w-5 text-gray-400" />
              </div>
              <div>
                <p className="text-xs text-gray-500 uppercase tracking-wide">Address</p>
                <p className="text-sm text-cyan-400 font-medium">
                  {server.ipAddress}:{server.port}
                </p>
              </div>
            </div>

            {/* Uptime */}
            <div className="flex items-start gap-3">
              <div className="p-2 bg-gray-800/50 rounded-lg">
                <ClockIcon className="h-5 w-5 text-gray-400" />
              </div>
              <div>
                <p className="text-xs text-gray-500 uppercase tracking-wide">Uptime</p>
                <p className="text-sm text-white font-medium">
                  {server.status === 'Running' ? formatUptime(uptime) : '—'}
                </p>
              </div>
            </div>

            {/* CPU Load */}
            <div className="flex items-start gap-3">
              <div className="p-2 bg-gray-800/50 rounded-lg">
                <CpuChipIcon className="h-5 w-5 text-gray-400" />
              </div>
              <div className="flex-1">
                <p className="text-xs text-gray-500 uppercase tracking-wide">CPU Load</p>
                <p className="text-sm text-white font-medium">
                  {stats ? `${Math.min(stats.cpuUsage, 100).toFixed(2)}%` : '—'}
                  <span className="text-gray-600 text-xs ml-1">/ {server.cpuLimit}%</span>
                </p>
                {stats && (
                  <div className="mt-1 h-1.5 bg-gray-800 rounded-full overflow-hidden">
                    <div 
                      className="h-full bg-cyan-500 rounded-full transition-all"
                      style={{ width: `${Math.min((stats.cpuUsage / server.cpuLimit) * 100, 100)}%` }}
                    />
                  </div>
                )}
              </div>
            </div>

            {/* Memory */}
            <div className="flex items-start gap-3">
              <div className="p-2 bg-gray-800/50 rounded-lg">
                <CircleStackIcon className="h-5 w-5 text-gray-400" />
              </div>
              <div className="flex-1">
                <p className="text-xs text-gray-500 uppercase tracking-wide">Memory</p>
                <p className="text-sm text-white font-medium">
                  {stats ? formatBytes(stats.memoryUsage) : '—'}
                  <span className="text-gray-600 text-xs ml-1">/ {(server.memoryLimit / 1024).toFixed(1)} GiB</span>
                </p>
                {stats && (
                  <div className="mt-1 h-1.5 bg-gray-800 rounded-full overflow-hidden">
                    <div 
                      className="h-full bg-emerald-500 rounded-full transition-all"
                      style={{ width: `${Math.min((stats.memoryUsage / (server.memoryLimit * 1024 * 1024)) * 100, 100)}%` }}
                    />
                  </div>
                )}
              </div>
            </div>

            {/* Disk */}
            <div className="flex items-start gap-3">
              <div className="p-2 bg-gray-800/50 rounded-lg">
                <ServerIcon className="h-5 w-5 text-gray-400" />
              </div>
              <div>
                <p className="text-xs text-gray-500 uppercase tracking-wide">Disk I/O</p>
                <p className="text-sm text-white font-medium">
                  {stats ? formatBytes(stats.diskUsage) : '—'}
                </p>
              </div>
            </div>

            {/* Network Inbound */}
            <div className="flex items-start gap-3">
              <div className="p-2 bg-gray-800/50 rounded-lg">
                <ArrowDownTrayIcon className="h-5 w-5 text-gray-400" />
              </div>
              <div>
                <p className="text-xs text-gray-500 uppercase tracking-wide">Network (Inbound)</p>
                <p className="text-sm text-white font-medium">
                  {stats ? formatBytes(stats.networkRxBytes) : '—'}
                </p>
              </div>
            </div>

            {/* Network Outbound */}
            <div className="flex items-start gap-3">
              <div className="p-2 bg-gray-800/50 rounded-lg">
                <ArrowUpTrayIcon className="h-5 w-5 text-gray-400" />
              </div>
              <div>
                <p className="text-xs text-gray-500 uppercase tracking-wide">Network (Outbound)</p>
                <p className="text-sm text-white font-medium">
                  {stats ? formatBytes(stats.networkTxBytes) : '—'}
                </p>
              </div>
            </div>
          </div>
        </div>
      )}

      {activeTab === 'stats' && (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
          <div className="bg-[#0d1117] border border-gray-800 rounded-xl p-6">
            <div className="flex items-center gap-3 mb-3">
              <div className="p-2 bg-emerald-500/10 rounded-lg">
                <CircleStackIcon className="h-5 w-5 text-emerald-400" />
              </div>
              <p className="text-sm text-gray-400">Memory Usage</p>
            </div>
            <p className="text-2xl font-bold text-white">
              {stats ? formatBytes(stats.memoryUsage) : '—'}
            </p>
            <p className="text-xs text-gray-600 mt-1">of {server.memoryLimit} MB limit</p>
          </div>

          <div className="bg-[#0d1117] border border-gray-800 rounded-xl p-6">
            <div className="flex items-center gap-3 mb-3">
              <div className="p-2 bg-cyan-500/10 rounded-lg">
                <CpuChipIcon className="h-5 w-5 text-cyan-400" />
              </div>
              <p className="text-sm text-gray-400">CPU Usage</p>
            </div>
            <p className="text-2xl font-bold text-white">
              {stats ? `${Math.min(stats.cpuUsage, 100).toFixed(1)}%` : '—'}
            </p>
            <p className="text-xs text-gray-600 mt-1">of {server.cpuLimit}% limit</p>
          </div>

          <div className="bg-[#0d1117] border border-gray-800 rounded-xl p-6">
            <div className="flex items-center gap-3 mb-3">
              <div className="p-2 bg-purple-500/10 rounded-lg">
                <ServerIcon className="h-5 w-5 text-purple-400" />
              </div>
              <p className="text-sm text-gray-400">Disk I/O</p>
            </div>
            <p className="text-2xl font-bold text-white">
              {stats ? formatBytes(stats.diskUsage) : '—'}
            </p>
            <p className="text-xs text-gray-600 mt-1">total read + write</p>
          </div>

          <div className="bg-[#0d1117] border border-gray-800 rounded-xl p-6">
            <div className="flex items-center gap-3 mb-3">
              <div className="p-2 bg-blue-500/10 rounded-lg">
                <GlobeAltIcon className="h-5 w-5 text-blue-400" />
              </div>
              <p className="text-sm text-gray-400">Network I/O</p>
            </div>
            <p className="text-lg font-bold text-white flex items-center gap-2">
              <ArrowDownTrayIcon className="h-4 w-4 text-green-400" />
              {stats ? formatBytes(stats.networkRxBytes) : '—'}
            </p>
            <p className="text-lg font-bold text-white flex items-center gap-2">
              <ArrowUpTrayIcon className="h-4 w-4 text-orange-400" />
              {stats ? formatBytes(stats.networkTxBytes) : '—'}
            </p>
          </div>
        </div>
      )}

      {activeTab === 'settings' && (
        <div className="bg-[#0d1117] border border-gray-800 rounded-xl p-6">
          <h3 className="text-lg font-semibold text-white mb-4">Server Settings</h3>
          <form
            onSubmit={(e) => {
              e.preventDefault()
              updateMutation.mutate({ name: settingsName, description: settingsDescription })
            }}
          >
            <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
              <div>
                <label className="block text-sm font-medium text-gray-400 mb-2">Server Name</label>
                <input
                  type="text"
                  value={settingsName}
                  onChange={(e) => setSettingsName(e.target.value)}
                  className="w-full px-4 py-2.5 bg-[#161b22] border border-gray-700 rounded-lg text-white focus:outline-none focus:ring-2 focus:ring-cyan-500 focus:border-transparent"
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-400 mb-2">Description</label>
                <input
                  type="text"
                  value={settingsDescription}
                  onChange={(e) => setSettingsDescription(e.target.value)}
                  className="w-full px-4 py-2.5 bg-[#161b22] border border-gray-700 rounded-lg text-white focus:outline-none focus:ring-2 focus:ring-cyan-500 focus:border-transparent"
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-400 mb-2">
                  Memory Limit (MB)
                </label>
                <input
                  type="number"
                  value={server.memoryLimit}
                  disabled
                  className="w-full px-4 py-2.5 bg-[#161b22] border border-gray-700 rounded-lg text-gray-500 cursor-not-allowed"
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-400 mb-2">CPU Limit (%)</label>
                <input
                  type="number"
                  value={server.cpuLimit}
                  disabled
                  className="w-full px-4 py-2.5 bg-[#161b22] border border-gray-700 rounded-lg text-gray-500 cursor-not-allowed"
                />
              </div>
            </div>
            <div className="mt-6 flex justify-end">
              <button
                type="submit"
                disabled={updateMutation.isPending || (settingsName === server.name && settingsDescription === server.description)}
                className={clsx(
                  'px-6 py-2.5 rounded-lg font-medium text-sm transition-all',
                  settingsName === server.name && settingsDescription === server.description
                    ? 'bg-gray-700 text-gray-400 cursor-not-allowed'
                    : 'bg-cyan-600 hover:bg-cyan-500 text-white'
                )}
              >
                {updateMutation.isPending ? 'Saving...' : 'Save Settings'}
              </button>
            </div>
          </form>
        </div>
      )}

      {activeTab === 'files' && (
        <div className="bg-[#0d1117] border border-gray-800 rounded-xl p-6">
          <h3 className="text-lg font-semibold text-white mb-4">File Manager</h3>
          <p className="text-gray-500">File manager coming soon...</p>
        </div>
      )}
    </div>
  )
}
