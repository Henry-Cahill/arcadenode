import type { ServerStatus } from '@/types'

export const getStatusColor = (status: ServerStatus): string => {
  switch (status) {
    case 'Running':
      return 'bg-green-500'
    case 'Starting':
    case 'Stopping':
      return 'bg-yellow-500 animate-pulse-status'
    case 'Stopped':
      return 'bg-gray-500'
    case 'Error':
      return 'bg-red-500'
    case 'Installing':
      return 'bg-blue-500 animate-pulse-status'
    case 'Suspended':
      return 'bg-orange-500'
    default:
      return 'bg-gray-500'
  }
}
