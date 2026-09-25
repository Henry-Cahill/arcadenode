import { useState } from 'react'
import { useQuery } from '@tanstack/react-query'
import { cartridgeService } from '@/services/api'
import type { CartridgeListItem } from '@/types'


interface CartridgeSelectorProps {
  selectedCartridge: CartridgeListItem | null
  onSelect: (cartridge: CartridgeListItem | null) => void
}

export function CartridgeSelector({ selectedCartridge, onSelect }: CartridgeSelectorProps) {
  const [searchTerm, setSearchTerm] = useState('')
  const [selectedCategory, setSelectedCategory] = useState<string | null>(null)

  const { data: cartridges = [], isLoading } = useQuery({
    queryKey: ['cartridges'],
    queryFn: cartridgeService.getAll,
  })

  const { data: categories = [] } = useQuery({
    queryKey: ['cartridge-categories'],
    queryFn: cartridgeService.getCategories,
  })

  const filteredCartridges = cartridges.filter((cartridge) => {
    const matchesSearch = 
      cartridge.name.toLowerCase().includes(searchTerm.toLowerCase()) ||
      cartridge.description.toLowerCase().includes(searchTerm.toLowerCase()) ||
      cartridge.tags.some(tag => tag.toLowerCase().includes(searchTerm.toLowerCase()))
    
    const matchesCategory = !selectedCategory || cartridge.category === selectedCategory

    return matchesSearch && matchesCategory
  })

  if (isLoading) {
    return (
      <div className="flex items-center justify-center py-12">
        <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-500"></div>
      </div>
    )
  }

  return (
    <div className="space-y-4">
      {/* Search and Filter */}
      <div className="flex gap-4">
        <div className="flex-1">
          <input
            type="text"
            placeholder="Search cartridges..."
            value={searchTerm}
            onChange={(e) => setSearchTerm(e.target.value)}
            className="w-full px-4 py-2 bg-panel-dark border border-panel-border rounded-lg text-white placeholder-gray-400 focus:outline-none focus:ring-2 focus:ring-primary-500"
          />
        </div>
        <select
          value={selectedCategory || ''}
          onChange={(e) => setSelectedCategory(e.target.value || null)}
          className="px-4 py-2 bg-panel-dark border border-panel-border rounded-lg text-white focus:outline-none focus:ring-2 focus:ring-primary-500"
        >
          <option value="">All Categories</option>
          {categories.map((cat) => (
            <option key={cat.name} value={cat.name}>
              {cat.name} ({cat.count})
            </option>
          ))}
        </select>
      </div>

      {/* Cartridge Grid */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
        {filteredCartridges.map((cartridge) => (
          <CartridgeCard
            key={cartridge.id}
            cartridge={cartridge}
            isSelected={selectedCartridge?.id === cartridge.id}
            onSelect={() => onSelect(cartridge)}
          />
        ))}
      </div>

      {filteredCartridges.length === 0 && (
        <div className="text-center py-12 text-gray-400">
          No cartridges found matching your search.
        </div>
      )}
    </div>
  )
}

interface CartridgeCardProps {
  cartridge: CartridgeListItem
  isSelected: boolean
  onSelect: () => void
}

function CartridgeCard({ cartridge, isSelected, onSelect }: CartridgeCardProps) {
  const [iconFailed, setIconFailed] = useState(false)

  return (
    <button
      onClick={onSelect}
      className={`
        w-full text-left p-4 rounded-lg border-2 transition-all
        ${isSelected 
          ? 'border-blue-500 bg-blue-500/10' 
          : 'border-panel-border bg-panel-card hover:border-primary-600 hover:bg-panel-dark'
        }
      `}
    >
      <div className="flex items-start gap-3">
        {/* Icon */}
        <div className="flex-shrink-0 w-12 h-12 rounded-lg bg-panel-dark flex items-center justify-center overflow-hidden">
          {cartridge.icon && !iconFailed ? (
            <img 
              src={cartridge.icon} 
              alt={cartridge.name} 
              className="w-full h-full object-cover"
              onError={() => setIconFailed(true)}
            />
          ) : (
            <span className="text-2xl">🎮</span>
          )}
        </div>

        {/* Content */}
        <div className="flex-1 min-w-0">
          <h3 className="font-semibold text-white truncate">{cartridge.name}</h3>
          <p className="text-sm text-gray-400 line-clamp-2 mt-1">{cartridge.description}</p>
          
          {/* Tags */}
          <div className="flex flex-wrap gap-1 mt-2">
            <span className="px-2 py-0.5 text-xs bg-blue-500/20 text-blue-400 rounded">
              {cartridge.category}
            </span>
            {cartridge.tags.slice(0, 2).map((tag) => (
              <span 
                key={tag} 
                className="px-2 py-0.5 text-xs bg-panel-dark text-gray-400 rounded"
              >
                {tag}
              </span>
            ))}
          </div>

          {/* Specs */}
          <div className="flex gap-4 mt-2 text-xs text-gray-500">
            <span>💾 {cartridge.recommendedMemory} MB</span>
            <span>🔌 Port {cartridge.defaultPort}</span>
          </div>
        </div>

        {/* Selection indicator */}
        {isSelected && (
          <div className="flex-shrink-0">
            <div className="w-6 h-6 rounded-full bg-blue-500 flex items-center justify-center">
              <svg className="w-4 h-4 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" />
              </svg>
            </div>
          </div>
        )}
      </div>
    </button>
  )
}
