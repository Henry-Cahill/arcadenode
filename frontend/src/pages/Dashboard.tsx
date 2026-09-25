import { useQuery } from '@tanstack/react-query'
import { Link } from 'react-router-dom'
import { adminService, serverService, deploymentService } from '@/services/api'
import { useAuthStore } from '@/stores/authStore'
import { usePageTitle } from '@/lib/usePageTitle'
import {
  ServerIcon,
  CubeIcon,
  UsersIcon,
  CpuChipIcon,
  CircleStackIcon,
  RocketLaunchIcon,
  ExclamationTriangleIcon,
  ArrowPathIcon,
} from '@heroicons/react/24/outline'
import clsx from 'clsx'
import { getStatusColor } from '@/lib/statusColors'

export default function Dashboard() {
  usePageTitle('Dashboard')
  const { user } = useAuthStore()
  const isAdmin = user?.role === 'Admin' || user?.role === 'SuperAdmin'

  const { data: stats, isLoading: statsLoading, isError: statsError } = useQuery({
    queryKey: ['dashboard-stats'],
    queryFn: adminService.getDashboardStats,
    enabled: isAdmin,
  })

  const { data: servers, isLoading: serversLoading, isError: serversError } = useQuery({
    queryKey: ['servers'],
    queryFn: serverService.getAll,
  })

  const { data: templates, isLoading: templatesLoading, isError: templatesError } = useQuery({
    queryKey: ['gameTemplates'],
    queryFn: deploymentService.getTemplates,
    enabled: isAdmin,
  })

  const isLoading = serversLoading || (isAdmin && (statsLoading || templatesLoading))
  const hasError = serversError || (isAdmin && (statsError || templatesError))


  const statCards = isAdmin
    ? [
        {
          name: 'Total Servers',
          value: stats?.totalServers ?? 0,
          icon: ServerIcon,
          color: 'text-violet-400',
        },
        {
          name: 'Running Servers',
          value: stats?.runningServers ?? 0,
          icon: CpuChipIcon,
          color: 'text-green-400',
        },
        {
          name: 'Total Nodes',
          value: stats?.totalNodes ?? 0,
          icon: CubeIcon,
          color: 'text-fuchsia-400',
        },
        {
          name: 'Total Users',
          value: stats?.totalUsers ?? 0,
          icon: UsersIcon,
          color: 'text-orange-400',
        },
      ]
    : [
        {
          name: 'My Servers',
          value: servers?.length ?? 0,
          icon: ServerIcon,
          color: 'text-violet-400',
        },
        {
          name: 'Running',
          value: servers?.filter((s) => s.status === 'Running').length ?? 0,
          icon: CpuChipIcon,
          color: 'text-green-400',
        },
      ]

  return (
    <div>
      <div className="flex items-center gap-3 mb-6">
        <h1 className="text-2xl font-bold text-white">Dashboard</h1>
        <span className="px-2 py-1 text-xs font-medium bg-gradient-to-r from-violet-500/20 to-fuchsia-500/20 text-violet-300 rounded-full border border-violet-500/30">
          ArcadeNode
        </span>
      </div>

      {/* Loading State */}
      {isLoading && (
        <div className="flex flex-col items-center justify-center py-16">
          <ArrowPathIcon className="h-10 w-10 text-violet-400 animate-spin mb-4" />
          <p className="text-gray-400 text-sm">Loading dashboard…</p>
        </div>
      )}

      {/* Error State */}
      {!isLoading && hasError && (
        <div className="bg-red-900/20 border border-red-500/30 rounded-xl p-6 mb-8 flex items-center gap-4">
          <ExclamationTriangleIcon className="h-8 w-8 text-red-400 shrink-0" />
          <div>
            <p className="text-red-300 font-medium">Failed to load dashboard data</p>
            <p className="text-sm text-red-400/70 mt-1">
              Some queries returned errors. Please try refreshing the page.
            </p>
          </div>
        </div>
      )}

      {/* Supported Games Banner */}
      <div className="bg-gradient-to-r from-violet-900/30 via-fuchsia-900/20 to-violet-900/30 border border-violet-500/20 rounded-xl p-4 mb-8">
        <div className="flex items-center justify-between flex-wrap gap-4">
          <div>
            <p className="text-sm text-gray-400 mb-2">Supported Games</p>
            <div className="flex flex-wrap gap-3">
              <span className="px-3 py-1 bg-accent-zomboid/20 text-accent-zomboid text-sm font-medium rounded-lg border border-accent-zomboid/30">
                🧟 Project Zomboid
              </span>
              <span className="px-3 py-1 bg-accent-arma/20 text-accent-arma text-sm font-medium rounded-lg border border-accent-arma/30">
                🎖️ Arma Reforger
              </span>
              <span className="px-3 py-1 bg-accent-minecraft/20 text-accent-minecraft text-sm font-medium rounded-lg border border-accent-minecraft/30">
                ⛏️ Minecraft
              </span>
            </div>
          </div>
          {isAdmin && (
            <Link
              to="/admin/deploy"
              className="flex items-center gap-2 px-4 py-2 bg-primary-600 hover:bg-primary-700 text-white font-medium rounded-lg transition-colors"
            >
              <RocketLaunchIcon className="h-5 w-5" />
              Deploy New Server
            </Link>
          )}
        </div>
      </div>

      {/* Quick Deploy Cards (Admin) */}
      {isAdmin && templates && templates.length > 0 && (
        <div className="mb-8">
          <h2 className="text-lg font-semibold text-white mb-4">Quick Deploy</h2>
          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
            {templates.map((template) => (
              <Link
                key={template.id}
                to={`/admin/deploy?game=${template.id}`}
                className="bg-panel-card border border-panel-border rounded-xl p-4 hover:border-primary-500/50 transition-all group"
              >
                <div className="flex items-center gap-3 mb-2">
                  <span className="text-2xl">{template.icon}</span>
                  <h3 className="font-medium text-white group-hover:text-primary-400 transition-colors">
                    {template.name}
                  </h3>
                </div>
                <p className="text-xs text-gray-500 line-clamp-2">{template.description}</p>
                <div className="mt-3 flex items-center gap-2 text-xs text-gray-400">
                  <span>{template.defaultMemory} MB</span>
                  <span>•</span>
                  <span>{template.ports.length} port{template.ports.length > 1 ? 's' : ''}</span>
                </div>
              </Link>
            ))}
          </div>
        </div>
      )}

      {/* Stats Grid */}
      {!isLoading && (
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4 mb-8">
        {statCards.map((stat) => (
          <div
            key={stat.name}
            className="bg-panel-card border border-panel-border rounded-xl p-6"
          >
            <div className="flex items-center gap-4">
              <div className={clsx('p-3 rounded-lg bg-panel-dark', stat.color)}>
                <stat.icon className="h-6 w-6" />
              </div>
              <div>
                <p className="text-sm text-gray-400">{stat.name}</p>
                <p className="text-2xl font-bold text-white">{stat.value}</p>
              </div>
            </div>
          </div>
        ))}
      </div>
      )}

      {/* Resource Usage (Admin) */}
      {isAdmin && stats && (
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4 mb-8">
          <div className="bg-panel-card border border-panel-border rounded-xl p-6">
            <div className="flex items-center gap-3 mb-4">
              <CpuChipIcon className="h-5 w-5 text-blue-400" />
              <h3 className="text-lg font-semibold text-white">Memory Allocation</h3>
            </div>
            <p className="text-3xl font-bold text-white">
              {(stats.totalAllocatedMemory / 1024).toFixed(1)} GB
            </p>
            <p className="text-sm text-gray-400 mt-1">Total allocated across all servers</p>
          </div>

          <div className="bg-panel-card border border-panel-border rounded-xl p-6">
            <div className="flex items-center gap-3 mb-4">
              <CircleStackIcon className="h-5 w-5 text-purple-400" />
              <h3 className="text-lg font-semibold text-white">Disk Allocation</h3>
            </div>
            <p className="text-3xl font-bold text-white">
              {(stats.totalAllocatedDisk / 1024).toFixed(1)} GB
            </p>
            <p className="text-sm text-gray-400 mt-1">Total allocated across all servers</p>
          </div>
        </div>
      )}

      {/* Recent Servers */}
      <div className="bg-panel-card border border-panel-border rounded-xl">
        <div className="px-6 py-4 border-b border-panel-border">
          <h2 className="text-lg font-semibold text-white">Your Servers</h2>
        </div>
        <div className="divide-y divide-panel-border">
          {servers?.slice(0, 5).map((server) => (
            <Link
              key={server.id}
              to={`/servers/${server.id}`}
              className="flex items-center justify-between px-6 py-4 hover:bg-panel-dark/50 transition-colors"
            >
              <div className="flex items-center gap-4">
                <div className={clsx('w-3 h-3 rounded-full', getStatusColor(server.status))} />
                <div>
                  <p className="font-medium text-white">{server.name}</p>
                  <p className="text-sm text-gray-400">
                    {server.identifier} • {server.nodeName}
                  </p>
                </div>
              </div>
              <div className="text-right">
                <p className="text-sm text-gray-400">{server.status}</p>
                <p className="text-xs text-gray-500">
                  {server.memoryLimit} MB • Port {server.port}
                </p>
              </div>
            </Link>
          ))}
          {(!servers || servers.length === 0) && (
            <div className="px-6 py-8 text-center">
              <ServerIcon className="h-12 w-12 text-gray-600 mx-auto mb-3" />
              <p className="text-gray-400">No servers found</p>
              <p className="text-sm text-gray-500">
                Contact an administrator to create a server for you
              </p>
            </div>
          )}
        </div>
      </div>
    </div>
  )
}
