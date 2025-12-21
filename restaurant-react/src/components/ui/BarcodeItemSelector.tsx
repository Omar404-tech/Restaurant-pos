import { useState, useEffect } from 'react'
import { supabase, fixEncodingInData } from '../../lib/supabase'
import BarcodeScanner from './BarcodeScanner'
import { AlertCircle, Package, Check } from 'lucide-react'

interface Item {
  id: string
  code: string
  barcode: string | null
  name_ar: string
  name: string
  purchase_price: number
  unit?: { id: string; name_ar: string; code: string } | null
}

interface BarcodeItemSelectorProps {
  onItemSelect: (item: Item) => void
  selectedItemId?: string
  branchId?: string // Optional: to check inventory availability
  showInventory?: boolean
  className?: string
  disabled?: boolean
}

/**
 * BarcodeItemSelector Component
 * - Combines barcode scanning with item selection
 * - Shows item details after scanning
 * - Optionally shows inventory availability
 */
export default function BarcodeItemSelector({
  onItemSelect,
  selectedItemId,
  branchId,
  showInventory = false,
  className = '',
  disabled = false
}: BarcodeItemSelectorProps) {
  const [items, setItems] = useState<Item[]>([])
  const [selectedItem, setSelectedItem] = useState<Item | null>(null)
  const [inventoryQty, setInventoryQty] = useState<number | null>(null)
  const [error, setError] = useState('')
  const [loading, setLoading] = useState(false)
  const [searchMode, setSearchMode] = useState<'barcode' | 'dropdown'>('barcode')

  useEffect(() => {
    fetchItems()
  }, [])

  useEffect(() => {
    if (selectedItemId && items.length > 0) {
      const item = items.find(i => i.id === selectedItemId)
      if (item) {
        setSelectedItem(item)
        if (showInventory && branchId) {
          fetchInventory(item.id, branchId)
        }
      }
    }
  }, [selectedItemId, items, branchId, showInventory])

  const fetchItems = async () => {
    const { data, error } = await supabase
      .from('items')
      .select('id, code, barcode, name_ar, name, purchase_price, unit:units(id, name_ar, code)')
      .eq('status', 'active')
      .order('name_ar')
    
    if (!error && data) {
      setItems(fixEncodingInData(data) as unknown as Item[])
    }
  }

  const fetchInventory = async (itemId: string, branchId: string) => {
    const { data } = await supabase
      .from('inventory')
      .select('quantity')
      .eq('item_id', itemId)
      .eq('branch_id', branchId)
      .single()
    
    setInventoryQty(data?.quantity || 0)
  }

  const handleBarcodeScan = async (barcode: string) => {
    setError('')
    setLoading(true)

    // Search by barcode first, then by code
    let item = items.find(i => i.barcode === barcode)
    if (!item) {
      item = items.find(i => i.code === barcode)
    }

    if (item) {
      setSelectedItem(item)
      onItemSelect(item)
      if (showInventory && branchId) {
        await fetchInventory(item.id, branchId)
      }
    } else {
      setError(`لم يتم العثور على صنف بالباركود: ${barcode}`)
      setSelectedItem(null)
      setInventoryQty(null)
    }

    setLoading(false)
  }

  const handleDropdownSelect = async (itemId: string) => {
    setError('')
    const item = items.find(i => i.id === itemId)
    if (item) {
      setSelectedItem(item)
      onItemSelect(item)
      if (showInventory && branchId) {
        await fetchInventory(item.id, branchId)
      }
    } else {
      setSelectedItem(null)
      setInventoryQty(null)
    }
  }

  const clearSelection = () => {
    setSelectedItem(null)
    setInventoryQty(null)
    setError('')
  }

  return (
    <div className={`space-y-3 ${className}`}>
      {/* Mode Toggle */}
      <div className="flex items-center gap-2 mb-2">
        <button
          type="button"
          onClick={() => setSearchMode('barcode')}
          className={`px-3 py-1 text-sm rounded-lg ${
            searchMode === 'barcode' 
              ? 'bg-blue-600 text-white' 
              : 'bg-gray-100 text-gray-700 hover:bg-gray-200'
          }`}
        >
          باركود
        </button>
        <button
          type="button"
          onClick={() => setSearchMode('dropdown')}
          className={`px-3 py-1 text-sm rounded-lg ${
            searchMode === 'dropdown' 
              ? 'bg-blue-600 text-white' 
              : 'bg-gray-100 text-gray-700 hover:bg-gray-200'
          }`}
        >
          قائمة
        </button>
      </div>

      {/* Barcode Scanner Mode */}
      {searchMode === 'barcode' && (
        <BarcodeScanner
          onScan={handleBarcodeScan}
          placeholder="امسح الباركود أو أدخل كود الصنف"
          disabled={disabled || loading}
        />
      )}

      {/* Dropdown Mode */}
      {searchMode === 'dropdown' && (
        <select
          value={selectedItem?.id || ''}
          onChange={(e) => handleDropdownSelect(e.target.value)}
          disabled={disabled}
          className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500"
          aria-label="اختر الصنف"
        >
          <option value="">اختر الصنف</option>
          {items.map(item => (
            <option key={item.id} value={item.id}>
              {item.name_ar} ({item.code}) {item.barcode ? `- ${item.barcode}` : ''}
            </option>
          ))}
        </select>
      )}

      {/* Error Message */}
      {error && (
        <div className="flex items-center gap-2 p-2 bg-red-50 border border-red-200 rounded-lg text-red-700 text-sm">
          <AlertCircle className="w-4 h-4 shrink-0" />
          <span>{error}</span>
        </div>
      )}

      {/* Selected Item Display */}
      {selectedItem && (
        <div className="flex items-center gap-3 p-3 bg-green-50 border border-green-200 rounded-lg">
          <div className="p-2 bg-green-100 rounded-lg">
            <Package className="w-5 h-5 text-green-600" />
          </div>
          <div className="flex-1">
            <div className="flex items-center gap-2">
              <span className="font-medium text-green-800">{selectedItem.name_ar}</span>
              <Check className="w-4 h-4 text-green-600" />
            </div>
            <div className="text-sm text-green-600">
              كود: {selectedItem.code}
              {selectedItem.barcode && ` | باركود: ${selectedItem.barcode}`}
              {selectedItem.unit && ` | ${selectedItem.unit.name_ar}`}
            </div>
            {showInventory && inventoryQty !== null && (
              <div className={`text-sm mt-1 ${inventoryQty > 0 ? 'text-blue-600' : 'text-red-600'}`}>
                الكمية المتاحة: {inventoryQty}
              </div>
            )}
          </div>
          <button
            type="button"
            onClick={clearSelection}
            className="text-gray-400 hover:text-gray-600"
            title="مسح"
          >
            ×
          </button>
        </div>
      )}

      {/* Loading */}
      {loading && (
        <div className="flex items-center gap-2 text-gray-500 text-sm">
          <span className="w-4 h-4 border-2 border-blue-600 border-t-transparent rounded-full animate-spin" />
          جاري البحث...
        </div>
      )}
    </div>
  )
}
