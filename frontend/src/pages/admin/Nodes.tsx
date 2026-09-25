import { useState } from 'react'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { useForm } from 'react-hook-form'
import toast from 'react-hot-toast'
import { nodeService } from '@/services/api'
import { getErrorMessage } from '@/lib/errorHandler'
import type { CreateNodeRequest, NodeConnectionTestResult } from '@/types'
import { PlusIcon, TrashIcon, CubeIcon, SignalIcon, ArrowPathIcon, CheckCircleIcon, XCircleIcon } from '@heroicons/react/24/outline'
import clsx from 'clsx'
import { usePageTitle } from '@/lib/usePageTitle'

export default function Nodes() {
  usePageTitle('Nodes')
  const queryClient = useQueryClient()
  const [showCreateModal, setShowCreateModal] = useState(false)
  const [showDeleteConfirm, setShowDeleteConfirm] = useState<string | null>(null)
  const [testingConnection, setTestingConnection] = useState(false)
  const [connectionResult, setConnectionResult] = useState<NodeConnectionTestResult | null>(null)

  const { data: nodes, isLoading } = useQuery({
    queryKey: ['nodes'],
    queryFn: nodeService.getAll,
  })

  const createMutation = useMutation({
    mutationFn: nodeService.create,
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['nodes'] })
      setShowCreateModal(false)
      reset()
      setConnectionResult(null)
      toast.success('Node created successfully')
    },
    onError: (error: unknown) => {
      console.error('Node creation error:', error)
      toast.error(getErrorMessage(error, 'Failed to create node'))
    },
  })

  const deleteMutation = useMutation({
    mutationFn: nodeService.delete,
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['nodes'] })
      toast.success('Node deleted successfully')
    },
    onError: (error: unknown) => {
      toast.error(getErrorMessage(error, 'Failed to delete node'))
    },
  })

  const testNodeMutation = useMutation({
    mutationFn: nodeService.testNodeConnection,
    onSuccess: (result) => {
      queryClient.invalidateQueries({ queryKey: ['nodes'] })
      if (result.success) {
        toast.success(`Node is online! Docker ${result.dockerVersion}`)
      } else {
        toast.error(result.message)
      }
    },
    onError: (error: unknown) => {
      toast.error(getErrorMessage(error, 'Failed to test connection'))
    },
  })

  const handleTestConnection = async (dockerEndpoint: string) => {
    setTestingConnection(true)
    setConnectionResult(null)
    try {
      const result = await nodeService.testConnection(dockerEndpoint)
      setConnectionResult(result)
      if (result.success) {
        toast.success('Connection successful!')
      } else {
        toast.error(result.message)
      }
    } catch (error) {
      setConnectionResult({
        success: false,
        message: getErrorMessage(error, 'Failed to test connection'),
        dockerVersion: null,
        operatingSystem: null,
        containerCount: null,
        memoryTotal: null,
        memoryAvailable: null,
      })
      toast.error('Failed to test connection')
    } finally {
      setTestingConnection(false)
    }
  }

  const {
    register,
    handleSubmit,
    reset,
    formState: { errors },
  } = useForm<CreateNodeRequest>({
    defaultValues: {
      daemonPort: 8080,
      sftpPort: 2022,
      totalMemory: 0,
      totalDisk: 0,
      dockerEndpoint: 'tcp://arcadenode_node:2375',
    },
  })

  const onSubmit = (data: CreateNodeRequest) => {
    // Clean up NaN values from numeric fields (valueAsNumber returns NaN for empty inputs)
    const cleanedData: CreateNodeRequest = {
      name: data.name,
      fqdn: data.fqdn,
      description: data.description || undefined,
      daemonPort: isNaN(data.daemonPort as number) ? 8080 : (data.daemonPort || 8080),
      sftpPort: isNaN(data.sftpPort as number) ? 2022 : (data.sftpPort || 2022),
      totalMemory: isNaN(data.totalMemory as number) ? 0 : (data.totalMemory || 0),
      totalDisk: isNaN(data.totalDisk as number) ? 0 : (data.totalDisk || 0),
      memoryOverallocate: isNaN(data.memoryOverallocate as number) ? 0 : (data.memoryOverallocate || 0),
      diskOverallocate: isNaN(data.diskOverallocate as number) ? 0 : (data.diskOverallocate || 0),
      dockerEndpoint: data.dockerEndpoint || 'tcp://arcadenode_node:2375',
      useSsl: data.useSsl || false,
    }
    console.log('Submitting node data:', cleanedData)
    createMutation.mutate(cleanedData)
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
        <h1 className="text-2xl font-bold text-white">Nodes</h1>
        <button
          onClick={() => setShowCreateModal(true)}
          className="flex items-center gap-2 px-4 py-2 bg-primary-600 hover:bg-primary-700 text-white font-medium rounded-lg transition-colors"
        >
          <PlusIcon className="h-5 w-5" />
          Create Node
        </button>
      </div>

      {nodes && nodes.length > 0 ? (
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
          {nodes.map((node) => (
            <div
              key={node.id}
              className="bg-panel-card border border-panel-border rounded-xl p-6"
            >
              <div className="flex items-start justify-between mb-4">
                <div className="flex items-center gap-3">
                  <div
                    className={clsx(
                      'w-3 h-3 rounded-full',
                      node.isOnline ? 'bg-green-500' : 'bg-red-500'
                    )}
                  />
                  <div>
                    <h3 className="font-semibold text-white">{node.name}</h3>
                    <p className="text-sm text-gray-400">{node.fqdn}</p>
                  </div>
                </div>
                <div className="flex items-center gap-1">
                  <button
                    onClick={() => testNodeMutation.mutate(node.id)}
                    disabled={testNodeMutation.isPending}
                    className="p-2 text-gray-400 hover:text-blue-400 hover:bg-blue-500/10 rounded-lg transition-colors disabled:opacity-50"
                    title="Test connection"
                  >
                    <SignalIcon className={clsx('h-5 w-5', testNodeMutation.isPending && 'animate-pulse')} />
                  </button>
                  <button
                    onClick={() => setShowDeleteConfirm(node.id)}
                    disabled={node.serverCount > 0}
                    className="p-2 text-gray-400 hover:text-red-400 hover:bg-red-500/10 rounded-lg transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
                    title={node.serverCount > 0 ? 'Cannot delete node with servers' : 'Delete node'}
                  >
                    <TrashIcon className="h-5 w-5" />
                  </button>
                </div>
              </div>

              <div className="space-y-3 text-sm">
                <div className="flex justify-between">
                  <span className="text-gray-400">Status</span>
                  <span className={node.isOnline ? 'text-green-400' : 'text-red-400'}>
                    {node.isOnline ? 'Online' : 'Offline'}
                  </span>
                </div>
                <div className="flex justify-between">
                  <span className="text-gray-400">Servers</span>
                  <span className="text-gray-300">{node.serverCount}</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-gray-400">Memory</span>
                  <span className="text-gray-300">
                    {node.allocatedMemory} / {node.totalMemory || '∞'} MB
                  </span>
                </div>
                <div className="flex justify-between">
                  <span className="text-gray-400">Disk</span>
                  <span className="text-gray-300">
                    {node.allocatedDisk} / {node.totalDisk || '∞'} MB
                  </span>
                </div>
                <div className="flex justify-between">
                  <span className="text-gray-400">Daemon Port</span>
                  <span className="text-gray-300">{node.daemonPort}</span>
                </div>
              </div>

              {node.description && (
                <p className="mt-4 text-sm text-gray-500">{node.description}</p>
              )}
            </div>
          ))}
        </div>
      ) : (
        <div className="bg-panel-card border border-panel-border rounded-xl p-12 text-center">
          <CubeIcon className="h-16 w-16 text-gray-600 mx-auto mb-4" />
          <h3 className="text-lg font-medium text-white mb-2">No nodes found</h3>
          <p className="text-gray-400 mb-6">
            Create your first node to start deploying servers
          </p>
          <button
            onClick={() => setShowCreateModal(true)}
            className="inline-flex items-center gap-2 px-4 py-2 bg-primary-600 hover:bg-primary-700 text-white font-medium rounded-lg transition-colors"
          >
            <PlusIcon className="h-5 w-5" />
            Create Node
          </button>
        </div>
      )}

      {/* Delete Confirmation Modal */}
      {showDeleteConfirm && (
        <div className="fixed inset-0 bg-black/70 flex items-center justify-center z-50 backdrop-blur-sm">
          <div className="bg-panel-card border border-panel-border rounded-xl p-6 max-w-md mx-4 shadow-2xl">
            <h3 className="text-xl font-semibold text-white mb-2">Delete Node</h3>
            <p className="text-gray-400 mb-4">
              Are you sure you want to delete this node? This action cannot be undone.
            </p>
            <div className="flex justify-end gap-3">
              <button
                onClick={() => setShowDeleteConfirm(null)}
                className="px-4 py-2 bg-gray-700 hover:bg-gray-600 text-white font-medium rounded-lg transition-colors"
              >
                Cancel
              </button>
              <button
                onClick={() => {
                  deleteMutation.mutate(showDeleteConfirm)
                  setShowDeleteConfirm(null)
                }}
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
                    Delete Node
                  </>
                )}
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Create Modal */}
      {showCreateModal && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50">
          <div className="bg-panel-card border border-panel-border rounded-xl p-6 w-full max-w-lg mx-4">
            <h2 className="text-xl font-semibold text-white mb-4">Create Node</h2>
            <form onSubmit={handleSubmit(onSubmit)} className="space-y-4">
              <div>
                <label className="block text-sm font-medium text-gray-300 mb-1">Name</label>
                <input
                  type="text"
                  {...register('name', { required: 'Name is required' })}
                  className="w-full px-4 py-2 bg-panel-dark border border-panel-border rounded-lg text-white focus:outline-none focus:ring-2 focus:ring-primary-500"
                  placeholder="My Node"
                />
                {errors.name && (
                  <p className="mt-1 text-sm text-red-400">{errors.name.message}</p>
                )}
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-300 mb-1">FQDN</label>
                <input
                  type="text"
                  {...register('fqdn', { required: 'FQDN is required' })}
                  className="w-full px-4 py-2 bg-panel-dark border border-panel-border rounded-lg text-white focus:outline-none focus:ring-2 focus:ring-primary-500"
                  placeholder="node.example.com"
                />
                {errors.fqdn && (
                  <p className="mt-1 text-sm text-red-400">{errors.fqdn.message}</p>
                )}
              </div>

              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label className="block text-sm font-medium text-gray-300 mb-1">
                    Daemon Port
                  </label>
                  <input
                    type="number"
                    {...register('daemonPort', { valueAsNumber: true })}
                    className="w-full px-4 py-2 bg-panel-dark border border-panel-border rounded-lg text-white focus:outline-none focus:ring-2 focus:ring-primary-500"
                  />
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-300 mb-1">SFTP Port</label>
                  <input
                    type="number"
                    {...register('sftpPort', { valueAsNumber: true })}
                    className="w-full px-4 py-2 bg-panel-dark border border-panel-border rounded-lg text-white focus:outline-none focus:ring-2 focus:ring-primary-500"
                  />
                </div>
              </div>

              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label className="block text-sm font-medium text-gray-300 mb-1">
                    Total Memory (MB)
                  </label>
                  <input
                    type="number"
                    {...register('totalMemory', { valueAsNumber: true })}
                    className="w-full px-4 py-2 bg-panel-dark border border-panel-border rounded-lg text-white focus:outline-none focus:ring-2 focus:ring-primary-500"
                    placeholder="0 = unlimited"
                  />
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-300 mb-1">
                    Total Disk (MB)
                  </label>
                  <input
                    type="number"
                    {...register('totalDisk', { valueAsNumber: true })}
                    className="w-full px-4 py-2 bg-panel-dark border border-panel-border rounded-lg text-white focus:outline-none focus:ring-2 focus:ring-primary-500"
                    placeholder="0 = unlimited"
                  />
                </div>
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-300 mb-1">
                  Docker Endpoint
                </label>
                <div className="flex gap-2">
                  <input
                    type="text"
                    {...register('dockerEndpoint')}
                    className="flex-1 px-4 py-2 bg-panel-dark border border-panel-border rounded-lg text-white focus:outline-none focus:ring-2 focus:ring-primary-500"
                  />
                  <button
                    type="button"
                    onClick={() => {
                      const endpoint = (document.querySelector('input[name="dockerEndpoint"]') as HTMLInputElement)?.value
                      if (endpoint) {
                        handleTestConnection(endpoint)
                      } else {
                        toast.error('Please enter a Docker endpoint first')
                      }
                    }}
                    disabled={testingConnection}
                    className="px-3 py-2 bg-blue-600 hover:bg-blue-700 disabled:bg-blue-800 text-white font-medium rounded-lg transition-colors flex items-center gap-1"
                  >
                    {testingConnection ? (
                      <ArrowPathIcon className="h-4 w-4 animate-spin" />
                    ) : (
                      <SignalIcon className="h-4 w-4" />
                    )}
                    Test
                  </button>
                </div>
                <p className="mt-1 text-xs text-gray-500">e.g., tcp://192.168.1.100:2375</p>
              </div>

              {/* Connection Test Result */}
              {connectionResult && (
                <div className={clsx(
                  'p-4 rounded-lg border',
                  connectionResult.success
                    ? 'bg-green-500/10 border-green-500/30'
                    : 'bg-red-500/10 border-red-500/30'
                )}>
                  <div className="flex items-center gap-2 mb-2">
                    {connectionResult.success ? (
                      <CheckCircleIcon className="h-5 w-5 text-green-400" />
                    ) : (
                      <XCircleIcon className="h-5 w-5 text-red-400" />
                    )}
                    <span className={connectionResult.success ? 'text-green-400' : 'text-red-400'}>
                      {connectionResult.message}
                    </span>
                  </div>
                  {connectionResult.success && (
                    <div className="grid grid-cols-2 gap-2 text-sm text-gray-400">
                      <div>Docker: <span className="text-gray-300">{connectionResult.dockerVersion}</span></div>
                      <div>OS: <span className="text-gray-300">{connectionResult.operatingSystem}</span></div>
                      <div>Containers: <span className="text-gray-300">{connectionResult.containerCount}</span></div>
                      <div>Memory: <span className="text-gray-300">{connectionResult.memoryTotal ? Math.round(connectionResult.memoryTotal / 1024 / 1024 / 1024) + ' GB' : 'N/A'}</span></div>
                    </div>
                  )}
                </div>
              )}

              <div>
                <label className="block text-sm font-medium text-gray-300 mb-1">Description</label>
                <textarea
                  {...register('description')}
                  rows={2}
                  className="w-full px-4 py-2 bg-panel-dark border border-panel-border rounded-lg text-white focus:outline-none focus:ring-2 focus:ring-primary-500"
                />
              </div>

              <div className="flex justify-end gap-3 pt-4">
                <button
                  type="button"
                  onClick={() => {
                    setShowCreateModal(false)
                    reset()
                    setConnectionResult(null)
                  }}
                  className="px-4 py-2 text-gray-400 hover:text-white transition-colors"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={createMutation.isPending}
                  className="px-4 py-2 bg-primary-600 hover:bg-primary-700 disabled:bg-primary-800 text-white font-medium rounded-lg transition-colors"
                >
                  {createMutation.isPending ? 'Creating...' : 'Create Node'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  )
}
