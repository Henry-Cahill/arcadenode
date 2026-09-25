import { useQuery } from '@tanstack/react-query'
import { Link } from 'react-router-dom'
import { serverService } from '@/services/api'
import { ServerIcon, PlusIcon } from '@heroicons/react/24/outline'
import clsx from 'clsx'
import { getStatusColor } from '@/lib/statusColors'
import type { ServerStatus } from '@/types'
import { useAuthStore } from '@/stores/authStore'
import { usePageTitle } from '@/lib/usePageTitle'

export default function Servers() {
  usePageTitle('Servers')
  const { user } = useAuthStore()
  const isAdmin = user?.role === 'Admin' || user?.role === 'SuperAdmin'

  const { data: servers, isLoading } = useQuery({
    queryKey: ['servers'],
    queryFn: serverService.getAll,
  })


  const getStatusText = (status: ServerStatus) => {
    switch (status) {
      case 'Running':
        return 'text-green-400'
      case 'Starting':
      case 'Stopping':
        return 'text-yellow-400'
      case 'Stopped':
        return 'text-gray-400'
      case 'Error':
        return 'text-red-400'
      case 'Installing':
        return 'text-blue-400'
      case 'Suspended':
        return 'text-orange-400'
      default:
        return 'text-gray-400'
    }
  }

  if (isLoading) {
    return (
      <div className="flex items-center justify-center min-h-[400px]">
        <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-primary-500" />
      </div>
    )
  }

  return (
    <div>
      <div className="flex items-center justify-between mb-6">
        <h1 className="text-2xl font-bold text-white">Servers</h1>
        {isAdmin && (
          <Link
            to="/admin/deploy"
            className="flex items-center gap-2 px-4 py-2 bg-primary-600 hover:bg-primary-700 text-white font-medium rounded-lg transition-colors"
          >
            <PlusIcon className="h-5 w-5" />
            Deploy Server
          </Link>
        )}
      </div>

      {servers && servers.length > 0 ? (
        <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-4">
          {servers.map((server) => (
            <Link
              key={server.id}
              to={`/servers/${server.id}`}
              className="bg-panel-card border border-panel-border rounded-xl p-5 hover:border-primary-500/50 transition-colors group"
            >
              <div className="flex items-start justify-between mb-4">
                <div className="flex items-center gap-3">
                  <div className={clsx('w-3 h-3 rounded-full', getStatusColor(server.status))} />
                  <div>
                    <h3 className="font-semibold text-white group-hover:text-primary-400 transition-colors">
                      {server.name}
                    </h3>
                    <p className="text-xs text-gray-500">{server.identifier}</p>
                  </div>
                </div>
                <span className={clsx('text-xs font-medium', getStatusText(server.status))}>
                  {server.status}
                </span>
              </div>

              <div className="space-y-2 text-sm">
                <div className="flex justify-between">
                  <span className="text-gray-400">Node</span>
                  <span className="text-gray-300">{server.nodeName}</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-gray-400">Address</span>
                  <span className="text-gray-300 font-mono">
                    {server.ipAddress}:{server.port}
                  </span>
                </div>
                <div className="flex justify-between">
                  <span className="text-gray-400">Memory</span>
                  <span className="text-gray-300">{server.memoryLimit} MB</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-gray-400">CPU</span>
                  <span className="text-gray-300">{server.cpuLimit}%</span>
                </div>
              </div>

              {server.description && (
                <p className="mt-4 text-sm text-gray-500 line-clamp-2">{server.description}</p>
              )}
            </Link>
          ))}
        </div>
      ) : (
        <div className="bg-panel-card border border-panel-border rounded-xl p-12 text-center">
          <ServerIcon className="h-16 w-16 text-gray-600 mx-auto mb-4" />
          <h3 className="text-lg font-medium text-white mb-2">No servers found</h3>
          <p className="text-gray-400 mb-6">
            {isAdmin
              ? 'Create your first server to get started'
              : 'Contact an administrator to create a server for you'}
          </p>
          {isAdmin && (
            <Link
              to="/admin/deploy"
              className="inline-flex items-center gap-2 px-4 py-2 bg-primary-600 hover:bg-primary-700 text-white font-medium rounded-lg transition-colors"
            >
              <PlusIcon className="h-5 w-5" />
              Deploy Server
            </Link>
          )}
        </div>
      )}
    </div>
  )
}
