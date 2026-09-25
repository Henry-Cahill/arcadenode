import { useState, useEffect } from 'react'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { useNavigate } from 'react-router-dom'
import toast from 'react-hot-toast'
import { nodeService, cartridgeService } from '@/services/api'
import { getErrorMessage } from '@/lib/errorHandler'
import type { CartridgeListItem, CartridgeDetail } from '@/types'
import { CartridgeSelector } from '@/components/cartridges/CartridgeSelector'
import { DynamicVariableForm } from '@/components/cartridges/DynamicVariableForm'
import { usePageTitle } from '@/lib/usePageTitle'
import {
  ServerIcon,
  ArrowLeftIcon,
  ArrowRightIcon,
  CheckIcon,
  ExclamationTriangleIcon,
  CpuChipIcon,
  CircleStackIcon,
  GlobeAltIcon,
} from '@heroicons/react/24/outline'
import clsx from 'clsx'

type WizardStep = 'cartridge' | 'configure' | 'resources' | 'review'

export default function DeployWizard() {
  usePageTitle('Deploy Server')
  const navigate = useNavigate()
  const queryClient = useQueryClient()
  
  const [currentStep, setCurrentStep] = useState<WizardStep>('cartridge')
  const [selectedCartridge, setSelectedCartridge] = useState<CartridgeListItem | null>(null)
  const [selectedNode, setSelectedNode] = useState<string>('')
  const [serverName, setServerName] = useState('')
  const [description, setDescription] = useState('')
  const [variables, setVariables] = useState<Record<string, string>>({})
  const [resources, setResources] = useState({
    memory: 2048,
    cpu: 100,
    disk: 10240,
  })
  const [errors, setErrors] = useState<Record<string, string>>({})
  const [showAdvanced, setShowAdvanced] = useState(false)

  // Fetch cartridge detail when selected
  const { data: cartridgeDetail, isLoading: cartridgeDetailLoading } = useQuery({
    queryKey: ['cartridge', selectedCartridge?.id],
    queryFn: () => cartridgeService.getById(selectedCartridge!.id),
    enabled: !!selectedCartridge?.id,
  })

  const { data: nodes } = useQuery({
    queryKey: ['nodes'],
    queryFn: nodeService.getAll,
  })

  // Initialize defaults when cartridge detail loads
  useEffect(() => {
    if (cartridgeDetail) {
      setServerName(`My ${cartridgeDetail.name} Server`)
      setResources({
        memory: cartridgeDetail.resources?.memory?.recommended || 2048,
        cpu: cartridgeDetail.resources?.cpu?.recommended || 100,
        disk: 10240,
      })
      
      // Initialize variables with defaults
      const defaultVars: Record<string, string> = {}
      cartridgeDetail.variables?.forEach((v) => {
        if (v.default !== undefined && v.default !== null) {
          defaultVars[v.envVariable] = String(v.default)
        }
      })
      setVariables(defaultVars)
    }
  }, [cartridgeDetail])

  const deployMutation = useMutation({
    mutationFn: () =>
      cartridgeService.createServer({
        cartridgeId: selectedCartridge!.id,
        name: serverName,
        description,
        nodeId: selectedNode,
        variables,
        memoryLimit: resources.memory,
        cpuLimit: resources.cpu,
        diskLimit: resources.disk,
      }),
    onSuccess: (server) => {
      queryClient.invalidateQueries({ queryKey: ['servers'] })
      navigate(`/servers/${server.id}`)
    },
    onError: (error: unknown) => {
      toast.error(getErrorMessage(error, 'Failed to deploy server'))
    },
  })

  const steps: { id: WizardStep; name: string }[] = [
    { id: 'cartridge', name: 'Select Game' },
    { id: 'configure', name: 'Configure' },
    { id: 'resources', name: 'Resources' },
    { id: 'review', name: 'Review & Deploy' },
  ]

  const currentStepIndex = steps.findIndex((s) => s.id === currentStep)

  const handleCartridgeSelect = (cartridge: CartridgeListItem | null) => {
    setSelectedCartridge(cartridge)
    // Reset form when cartridge changes
    setVariables({})
    setErrors({})
  }

  const validateStep = (): boolean => {
    const newErrors: Record<string, string> = {}

    if (currentStep === 'cartridge') {
      if (!selectedCartridge) {
        newErrors.cartridge = 'Please select a game'
      }
    }

    if (currentStep === 'configure') {
      if (!serverName.trim()) {
        newErrors.serverName = 'Server name is required'
      }
      if (!selectedNode) {
        newErrors.node = 'Please select a node'
      }
      
      // Validate required variables
      cartridgeDetail?.variables?.forEach((v) => {
        if (v.required && !variables[v.envVariable]?.trim()) {
          newErrors[v.envVariable] = `${v.name} is required`
        }
        if (v.validation?.pattern && variables[v.envVariable]) {
          const regex = new RegExp(v.validation.pattern)
          if (!regex.test(variables[v.envVariable])) {
            newErrors[v.envVariable] = `Invalid format for ${v.name}`
          }
        }
      })
    }

    setErrors(newErrors)
    return Object.keys(newErrors).length === 0
  }

  const handleNext = () => {
    if (!validateStep()) return

    const nextIndex = currentStepIndex + 1
    if (nextIndex < steps.length) {
      setCurrentStep(steps[nextIndex].id)
    }
  }

  const handleBack = () => {
    const prevIndex = currentStepIndex - 1
    if (prevIndex >= 0) {
      setCurrentStep(steps[prevIndex].id)
    }
  }

  const handleDeploy = () => {
    if (!validateStep()) return
    deployMutation.mutate()
  }

  return (
    <div className="max-w-4xl mx-auto">
      {/* Header */}
      <div className="mb-8">
        <h1 className="text-2xl font-bold text-white mb-2">Deploy New Server</h1>
        <p className="text-gray-400">Set up a new game server in just a few steps</p>
      </div>

      {/* Progress Steps */}
      <div className="mb-8">
        <div className="flex items-center justify-between">
          {steps.map((step, index) => (
            <div key={step.id} className="flex items-center">
              <div
                className={clsx(
                  'flex items-center justify-center w-10 h-10 rounded-full font-medium',
                  index < currentStepIndex
                    ? 'bg-primary-600 text-white'
                    : index === currentStepIndex
                    ? 'bg-primary-600 text-white ring-4 ring-primary-600/30'
                    : 'bg-panel-dark text-gray-500'
                )}
              >
                {index < currentStepIndex ? (
                  <CheckIcon className="w-5 h-5" />
                ) : (
                  index + 1
                )}
              </div>
              <span
                className={clsx(
                  'ml-3 font-medium hidden sm:block',
                  index <= currentStepIndex ? 'text-white' : 'text-gray-500'
                )}
              >
                {step.name}
              </span>
              {index < steps.length - 1 && (
                <div
                  className={clsx(
                    'w-12 sm:w-24 h-1 mx-4 rounded',
                    index < currentStepIndex ? 'bg-primary-600' : 'bg-panel-dark'
                  )}
                />
              )}
            </div>
          ))}
        </div>
      </div>

      {/* Step Content */}
      <div className="bg-panel-card rounded-xl border border-panel-border p-6 mb-6">
        {/* Step 1: Select Cartridge */}
        {currentStep === 'cartridge' && (
          <div>
            <h2 className="text-xl font-semibold text-white mb-4">Select a Game</h2>
            <CartridgeSelector
              selectedCartridge={selectedCartridge}
              onSelect={handleCartridgeSelect}
            />
            {errors.cartridge && (
              <p className="mt-4 text-red-400 text-sm">{errors.cartridge}</p>
            )}
          </div>
        )}

        {/* Step 2: Configure */}
        {currentStep === 'configure' && cartridgeDetail && (
          <div>
            <h2 className="text-xl font-semibold text-white mb-4">
              Configure {cartridgeDetail.name}
            </h2>

            {cartridgeDetailLoading ? (
              <div className="flex items-center justify-center py-12">
                <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-primary-500" />
              </div>
            ) : (
              <div className="space-y-6">
                {/* Basic Settings */}
                <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                  <div>
                    <label className="block text-sm font-medium text-gray-300 mb-2">
                      Server Name *
                    </label>
                    <input
                      type="text"
                      value={serverName}
                      onChange={(e) => setServerName(e.target.value)}
                      className={clsx(
                        'w-full bg-panel-dark border rounded-lg px-4 py-2 text-white focus:outline-none focus:ring-2 focus:ring-primary-500',
                        errors.serverName ? 'border-red-500' : 'border-panel-border'
                      )}
                    />
                    {errors.serverName && (
                      <p className="mt-1 text-red-400 text-sm">{errors.serverName}</p>
                    )}
                  </div>

                  <div>
                    <label className="block text-sm font-medium text-gray-300 mb-2">
                      Node *
                    </label>
                    <select
                      value={selectedNode}
                      onChange={(e) => setSelectedNode(e.target.value)}
                      className={clsx(
                        'w-full bg-panel-dark border rounded-lg px-4 py-2 text-white focus:outline-none focus:ring-2 focus:ring-primary-500',
                        errors.node ? 'border-red-500' : 'border-panel-border'
                      )}
                    >
                      <option value="">Select a node</option>
                      {nodes?.filter((n) => n.isOnline).map((node) => (
                        <option key={node.id} value={node.id}>
                          {node.name} ({node.fqdn})
                        </option>
                      ))}
                    </select>
                    {errors.node && (
                      <p className="mt-1 text-red-400 text-sm">{errors.node}</p>
                    )}
                  </div>
                </div>

                <div>
                  <label className="block text-sm font-medium text-gray-300 mb-2">
                    Description
                  </label>
                  <textarea
                    value={description}
                    onChange={(e) => setDescription(e.target.value)}
                    rows={2}
                    className="w-full bg-panel-dark border border-panel-border rounded-lg px-4 py-2 text-white focus:outline-none focus:ring-2 focus:ring-primary-500"
                    placeholder="Optional server description"
                  />
                </div>

                {/* Cartridge Variables */}
                {cartridgeDetail.variables && cartridgeDetail.variables.length > 0 && (
                  <div>
                    <div className="flex items-center justify-between mb-4">
                      <h3 className="text-lg font-medium text-white">Game Settings</h3>
                      <button
                        type="button"
                        onClick={() => setShowAdvanced(!showAdvanced)}
                        className="text-sm text-primary-400 hover:text-primary-300"
                      >
                        {showAdvanced ? 'Hide Advanced' : 'Show Advanced'}
                      </button>
                    </div>
                    <DynamicVariableForm
                      variables={cartridgeDetail.variables || []}
                      groups={cartridgeDetail.variableGroups || []}
                      values={variables}
                      onChange={setVariables}
                      errors={errors}
                      showAdvanced={showAdvanced}
                    />
                  </div>
                )}
              </div>
            )}
          </div>
        )}

        {/* Step 3: Resources */}
        {currentStep === 'resources' && cartridgeDetail && (
          <div>
            <h2 className="text-xl font-semibold text-white mb-4">Resource Allocation</h2>

            <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
              <div className="bg-panel-dark rounded-xl p-6">
                <div className="flex items-center gap-3 mb-4">
                  <CpuChipIcon className="w-8 h-8 text-primary-400" />
                  <div>
                    <h3 className="font-semibold text-white">Memory</h3>
                    <p className="text-sm text-gray-400">RAM allocation</p>
                  </div>
                </div>
                <div className="space-y-2">
                  <input
                    type="range"
                    min={cartridgeDetail.resources?.memory?.min || 512}
                    max={cartridgeDetail.resources?.memory?.max || 16384}
                    step="256"
                    value={resources.memory}
                    onChange={(e) =>
                      setResources((r) => ({ ...r, memory: parseInt(e.target.value) }))
                    }
                    className="w-full accent-primary-500"
                  />
                  <div className="flex justify-between text-sm">
                    <span className="text-gray-400">
                      {cartridgeDetail.resources?.memory?.min || 512} MB
                    </span>
                    <span className="text-white font-medium">{resources.memory} MB</span>
                    <span className="text-gray-400">
                      {cartridgeDetail.resources?.memory?.max || 16384} MB
                    </span>
                  </div>
                </div>
              </div>

              <div className="bg-panel-dark rounded-xl p-6">
                <div className="flex items-center gap-3 mb-4">
                  <ServerIcon className="w-8 h-8 text-green-400" />
                  <div>
                    <h3 className="font-semibold text-white">CPU</h3>
                    <p className="text-sm text-gray-400">Processing power</p>
                  </div>
                </div>
                <div className="space-y-2">
                  <input
                    type="range"
                    min={cartridgeDetail.resources?.cpu?.min || 25}
                    max={cartridgeDetail.resources?.cpu?.max || 400}
                    step="25"
                    value={resources.cpu}
                    onChange={(e) =>
                      setResources((r) => ({ ...r, cpu: parseInt(e.target.value) }))
                    }
                    className="w-full accent-green-500"
                  />
                  <div className="flex justify-between text-sm">
                    <span className="text-gray-400">
                      {cartridgeDetail.resources?.cpu?.min || 25}%
                    </span>
                    <span className="text-white font-medium">{resources.cpu}%</span>
                    <span className="text-gray-400">
                      {cartridgeDetail.resources?.cpu?.max || 400}%
                    </span>
                  </div>
                </div>
              </div>

              <div className="bg-panel-dark rounded-xl p-6">
                <div className="flex items-center gap-3 mb-4">
                  <CircleStackIcon className="w-8 h-8 text-blue-400" />
                  <div>
                    <h3 className="font-semibold text-white">Disk</h3>
                    <p className="text-sm text-gray-400">Storage space</p>
                  </div>
                </div>
                <div className="space-y-2">
                  <input
                    type="range"
                    min={cartridgeDetail.resources?.disk?.min || 1024}
                    max={(cartridgeDetail.resources?.disk?.min || 1024) * 10}
                    step="1024"
                    value={resources.disk}
                    onChange={(e) =>
                      setResources((r) => ({ ...r, disk: parseInt(e.target.value) }))
                    }
                    className="w-full accent-blue-500"
                  />
                  <div className="flex justify-between text-sm">
                    <span className="text-gray-400">
                      {((cartridgeDetail.resources?.disk?.min || 1024) / 1024).toFixed(0)} GB
                    </span>
                    <span className="text-white font-medium">
                      {(resources.disk / 1024).toFixed(1)} GB
                    </span>
                    <span className="text-gray-400">
                      {(((cartridgeDetail.resources?.disk?.min || 1024) * 10) / 1024).toFixed(0)} GB
                    </span>
                  </div>
                </div>
              </div>
            </div>

            {/* Port Information */}
            {cartridgeDetail.ports && cartridgeDetail.ports.length > 0 && (
              <div className="mt-6">
                <h3 className="text-lg font-medium text-white mb-4">Network Ports</h3>
                <div className="bg-panel-dark rounded-xl p-4">
                  <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                    {cartridgeDetail.ports.map((port) => (
                      <div
                        key={port.name}
                        className="flex items-center justify-between p-3 bg-panel-border rounded-lg"
                      >
                        <div className="flex items-center gap-3">
                          <GlobeAltIcon className="w-5 h-5 text-gray-400" />
                          <div>
                            <p className="text-white font-medium">{port.name}</p>
                            <p className="text-xs text-gray-400">{port.description}</p>
                          </div>
                        </div>
                        <div className="text-right">
                          <p className="text-white font-mono">{port.default}</p>
                          <p className="text-xs text-gray-400">{port.protocol}</p>
                        </div>
                      </div>
                    ))}
                  </div>
                </div>
              </div>
            )}
          </div>
        )}

        {/* Step 4: Review */}
        {currentStep === 'review' && cartridgeDetail && (
          <div>
            <h2 className="text-xl font-semibold text-white mb-4">Review & Deploy</h2>

            <div className="space-y-6">
              {/* Summary Card */}
              <div className="bg-panel-dark rounded-xl p-6">
                <div className="flex items-start gap-4">
                  {cartridgeDetail.icon?.startsWith('http') ? (
                    <img src={cartridgeDetail.icon} alt={cartridgeDetail.name} className="w-16 h-16 rounded-lg object-cover" />
                  ) : (
                    <span className="text-5xl">{cartridgeDetail.icon || '🎮'}</span>
                  )}
                  <div className="flex-1">
                    <h3 className="text-xl font-bold text-white">{serverName}</h3>
                    <p className="text-gray-400">{cartridgeDetail.name}</p>
                    {description && (
                      <p className="text-sm text-gray-500 mt-2">{description}</p>
                    )}
                    <div className="flex flex-wrap gap-2 mt-3">
                      {cartridgeDetail.tags?.map((tag) => (
                        <span
                          key={tag}
                          className="px-2 py-0.5 bg-panel-border rounded text-xs text-gray-400"
                        >
                          {tag}
                        </span>
                      ))}
                    </div>
                  </div>
                </div>
              </div>

              {/* Configuration Summary */}
              <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                <div className="bg-panel-dark rounded-xl p-4">
                  <h4 className="font-medium text-white mb-3">Resources</h4>
                  <div className="space-y-2 text-sm">
                    <div className="flex justify-between">
                      <span className="text-gray-400">Memory</span>
                      <span className="text-white">{resources.memory} MB</span>
                    </div>
                    <div className="flex justify-between">
                      <span className="text-gray-400">CPU</span>
                      <span className="text-white">{resources.cpu}%</span>
                    </div>
                    <div className="flex justify-between">
                      <span className="text-gray-400">Disk</span>
                      <span className="text-white">{(resources.disk / 1024).toFixed(1)} GB</span>
                    </div>
                  </div>
                </div>

                <div className="bg-panel-dark rounded-xl p-4">
                  <h4 className="font-medium text-white mb-3">Network</h4>
                  <div className="space-y-2 text-sm">
                    {cartridgeDetail.ports?.map((port) => (
                      <div key={port.name} className="flex justify-between">
                        <span className="text-gray-400">{port.name}</span>
                        <span className="text-white font-mono">
                          {port.default}/{port.protocol}
                        </span>
                      </div>
                    ))}
                  </div>
                </div>
              </div>

              {/* Key Settings */}
              <div className="bg-panel-dark rounded-xl p-4">
                <h4 className="font-medium text-white mb-3">Key Settings</h4>
                <div className="grid grid-cols-2 md:grid-cols-3 gap-4 text-sm">
                  {cartridgeDetail.variables
                    ?.filter((v) => v.required || v.userEditable)
                    .slice(0, 6)
                    .map((v) => (
                      <div key={v.envVariable}>
                        <span className="text-gray-400 block">{v.name}</span>
                        <span className="text-white">
                          {v.ui?.component === 'password'
                            ? '••••••••'
                            : variables[v.envVariable] || v.default || '-'}
                        </span>
                      </div>
                    ))}
                </div>
              </div>

              {/* Node Info */}
              <div className="bg-panel-dark rounded-xl p-4">
                <h4 className="font-medium text-white mb-3">Deployment Target</h4>
                <div className="text-sm">
                  <span className="text-gray-400">Node: </span>
                  <span className="text-white">
                    {nodes?.find((n) => n.id === selectedNode)?.name || selectedNode}
                  </span>
                </div>
              </div>

              {deployMutation.isError && (
                <div className="p-4 bg-red-500/10 border border-red-500/30 rounded-lg">
                  <div className="flex gap-3">
                    <ExclamationTriangleIcon className="w-5 h-5 text-red-500 flex-shrink-0" />
                    <div>
                      <p className="text-red-400">
                        Failed to deploy server. Please try again.
                      </p>
                      <p className="text-red-400/70 text-sm mt-1">
                        {getErrorMessage(deployMutation.error, 'Unknown error')}
                      </p>
                    </div>
                  </div>
                </div>
              )}
            </div>
          </div>
        )}
      </div>

      {/* Navigation Buttons */}
      <div className="flex justify-between">
        <button
          onClick={currentStepIndex === 0 ? () => navigate('/servers') : handleBack}
          className="flex items-center gap-2 px-4 py-2 bg-panel-dark hover:bg-panel-border text-white font-medium rounded-lg transition-colors"
        >
          <ArrowLeftIcon className="w-5 h-5" />
          {currentStepIndex === 0 ? 'Cancel' : 'Back'}
        </button>

        {currentStep === 'review' ? (
          <button
            onClick={handleDeploy}
            disabled={deployMutation.isPending}
            className="flex items-center gap-2 px-6 py-2 bg-primary-600 hover:bg-primary-700 disabled:opacity-50 disabled:cursor-not-allowed text-white font-medium rounded-lg transition-colors"
          >
            {deployMutation.isPending ? (
              <>
                <div className="animate-spin rounded-full h-5 w-5 border-b-2 border-white" />
                Deploying...
              </>
            ) : (
              <>
                <ServerIcon className="w-5 h-5" />
                Deploy Server
              </>
            )}
          </button>
        ) : (
          <button
            onClick={handleNext}
            disabled={currentStep === 'configure' && cartridgeDetailLoading}
            className="flex items-center gap-2 px-4 py-2 bg-primary-600 hover:bg-primary-700 disabled:opacity-50 text-white font-medium rounded-lg transition-colors"
          >
            Next
            <ArrowRightIcon className="w-5 h-5" />
          </button>
        )}
      </div>
    </div>
  )
}
