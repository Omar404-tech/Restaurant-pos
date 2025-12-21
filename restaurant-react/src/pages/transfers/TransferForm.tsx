import { useState, useEffect, FormEvent, useRef } from 'react'
import { useNavigate } from 'react-router-dom'
import { transfersService } from '../../services/transfers.service'
import { branchesService } from '../../services/branches.service'
import { inventoryService, InventoryWithDetails } from '../../services/inventory.service'
import { useAuth } from '../../contexts/AuthContext'
import { Branch, Item } from '../../types/database.types'
import { Save, ArrowRight, AlertCircle, Plus, Trash2, Barcode, Search } from 'lucide-react'


interface TransferItem {
  item_id: string
  requested_quantity: number
  notes?: string
  availableQty?: number // Track available quantity
}

export default function TransferForm() {
  const navigate = useNavigate()
  const { user } = useAuth()
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState('')
  const [branches, setBranches] = useState<Branch[]>([])
  const [items, setItems] = useState<Item[]>([])

  const [fromBranch, setFromBranch] = useState('')
  const [toBranch, setToBranch] = useState('')
  const [notes, setNotes] = useState('')
  const [transferItems, setTransferItems] = useState<TransferItem[]>([{ item_id: '', requested_quantity: 1 }])
  const [sourceInventory, setSourceInventory] = useState<InventoryWithDetails[]>([])
  const [barcodeInput, setBarcodeInput] = useState('')
  const [barcodeError, setBarcodeError] = useState('')
  const barcodeInputRef = useRef<HTMLInputElement>(null)

  useEffect(() => {
    fetchData()
  }, [])

  // Fetch source branch inventory when fromBranch changes
  useEffect(() => {
    if (fromBranch) {
      fetchSourceInventory(fromBranch)
    } else {
      setSourceInventory([])
    }
  }, [fromBranch])

  const fetchSourceInventory = async (branchId: string) => {
    const { data } = await inventoryService.getStockByBranch(branchId)
    setSourceInventory(data || [])
  }

  // Get available quantity for an item in source branch
  const getAvailableQty = (itemId: string): number => {
    const inv = sourceInventory.find(i => i.item_id === itemId)
    return inv?.quantity || 0
  }

  const fetchData = async () => {
    const [branchesRes, itemsRes] = await Promise.all([
      branchesService.getActive(),
      inventoryService.getAllItems(),
    ])
    setBranches(branchesRes.data || [])
    setItems(itemsRes.data || [])
  }

  const handleAddItem = () => {
    setTransferItems([...transferItems, { item_id: '', requested_quantity: 1 }])
  }

  // Barcode search function
  const handleBarcodeSearch = async () => {
    if (!barcodeInput.trim()) return
    setBarcodeError('')

    // Search by barcode or code
    const item = items.find(i => 
      (i as Item & { barcode?: string }).barcode === barcodeInput.trim() || 
      i.code === barcodeInput.trim()
    )

    if (item) {
      // Check if item already exists in list
      const existingIndex = transferItems.findIndex(ti => ti.item_id === item.id)
      if (existingIndex >= 0) {
        // Increment quantity
        const updated = [...transferItems]
        updated[existingIndex].requested_quantity += 1
        setTransferItems(updated)
      } else {
        // Add new item
        const availableQty = getAvailableQty(item.id)
        const newItem: TransferItem = {
          item_id: item.id,
          requested_quantity: 1,
          availableQty
        }
        // Replace empty item or add new
        const emptyIndex = transferItems.findIndex(ti => !ti.item_id)
        if (emptyIndex >= 0) {
          const updated = [...transferItems]
          updated[emptyIndex] = newItem
          setTransferItems(updated)
        } else {
          setTransferItems([...transferItems, newItem])
        }
      }
      setBarcodeInput('')
      barcodeInputRef.current?.focus()
    } else {
      setBarcodeError(`لم يتم العثور على صنف بالباركود: ${barcodeInput}`)
    }
  }

  const handleBarcodeKeyPress = (e: React.KeyboardEvent<HTMLInputElement>) => {
    if (e.key === 'Enter') {
      e.preventDefault()
      handleBarcodeSearch()
    }
  }

  const handleRemoveItem = (index: number) => {
    setTransferItems(transferItems.filter((_, i) => i !== index))
  }

  const handleItemChange = (index: number, field: keyof TransferItem, value: string | number) => {
    const updated = [...transferItems]
    updated[index] = { ...updated[index], [field]: value }
    // Update available quantity when item changes
    if (field === 'item_id' && typeof value === 'string') {
      updated[index].availableQty = getAvailableQty(value)
    }
    setTransferItems(updated)
  }

  const handleSubmit = async (e: FormEvent) => {
    e.preventDefault()
    setError('')

    if (!fromBranch || !toBranch) {
      setError('يرجى اختيار الفرع المرسل والمستلم')
      return
    }
    if (fromBranch === toBranch) {
      setError('لا يمكن التحويل لنفس الفرع')
      return
    }
    const validItems = transferItems.filter(i => i.item_id && i.requested_quantity > 0)
    if (validItems.length === 0) {
      setError('يرجى إضافة صنف واحد على الأقل')
      return
    }

    // Check if all quantities are available
    const insufficientItems: string[] = []
    for (const item of validItems) {
      const availableQty = getAvailableQty(item.item_id)
      if (item.requested_quantity > availableQty) {
        const itemName = items.find(i => i.id === item.item_id)?.name_ar || ''
        insufficientItems.push(`${itemName}: متوفر ${availableQty} - مطلوب ${item.requested_quantity}`)
      }
    }
    if (insufficientItems.length > 0) {
      setError(`الكمية غير متوفرة في المخزن المصدر:\n${insufficientItems.join('\n')}`)
      return
    }

    setLoading(true)
    const { error } = await transfersService.create({
      from_branch_id: fromBranch,
      to_branch_id: toBranch,
      notes,
      requested_by: user?.id || '',
      items: validItems,
    })

    if (error) {
      setError('فشل في إنشاء التحويل')
    } else {
      navigate('/transfers')
    }
    setLoading(false)
  }

  return (
    <div className="max-w-3xl mx-auto">
      <div className="flex items-center gap-4 mb-6">
        <button onClick={() => navigate('/transfers')} className="p-2 hover:bg-gray-100 rounded-lg" title="رجوع">
          <ArrowRight className="w-5 h-5" />
        </button>
        <div>
          <h1 className="text-2xl font-bold text-gray-900">تحويل جديد</h1>
          <p className="text-gray-600">إنشاء طلب تحويل مخزون بين الفروع</p>
        </div>
      </div>

      {error && (
        <div className="mb-6 p-4 bg-red-50 border border-red-200 rounded-lg flex items-center gap-3">
          <AlertCircle className="w-5 h-5 text-red-500 shrink-0" />
          <p className="text-red-700">{error}</p>
        </div>
      )}

      <form onSubmit={handleSubmit} className="bg-white rounded-lg shadow-sm border border-gray-100 p-6 space-y-6">
        <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">من فرع <span className="text-red-500">*</span></label>
            <select value={fromBranch} onChange={(e) => setFromBranch(e.target.value)} required
              aria-label="من فرع"
              className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500">
              <option value="">اختر الفرع</option>
              {branches.map(b => <option key={b.id} value={b.id}>{b.name_ar}</option>)}
            </select>
          </div>
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">إلى فرع <span className="text-red-500">*</span></label>
            <select value={toBranch} onChange={(e) => setToBranch(e.target.value)} required
              aria-label="إلى فرع"
              className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500">
              <option value="">اختر الفرع</option>
              {branches.map(b => <option key={b.id} value={b.id}>{b.name_ar}</option>)}
            </select>
          </div>
        </div>

        <div>
          <div className="flex items-center justify-between mb-4">
            <label className="text-sm font-medium text-gray-700">الأصناف <span className="text-red-500">*</span></label>
            <button type="button" onClick={handleAddItem} className="flex items-center gap-1 text-sm text-blue-600 hover:text-blue-700">
              <Plus className="w-4 h-4" /> إضافة صنف
            </button>
          </div>

          {/* Barcode Scanner Input */}
          <div className="mb-4 p-4 bg-blue-50 border border-blue-200 rounded-lg">
            <label className="flex items-center gap-2 text-sm font-medium text-blue-800 mb-2">
              <Barcode className="w-4 h-4" />
              إضافة صنف بالباركود
            </label>
            <div className="flex gap-2">
              <input
                ref={barcodeInputRef}
                type="text"
                value={barcodeInput}
                onChange={(e) => setBarcodeInput(e.target.value)}
                onKeyPress={handleBarcodeKeyPress}
                placeholder="امسح الباركود أو أدخل كود الصنف"
                className="flex-1 px-4 py-2 border border-blue-300 rounded-lg focus:ring-2 focus:ring-blue-500"
                dir="ltr"
              />
              <button
                type="button"
                onClick={handleBarcodeSearch}
                className="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700"
                title="بحث بالباركود"
                aria-label="بحث بالباركود"
              >
                <Search className="w-5 h-5" />
              </button>
            </div>
            {barcodeError && (
              <p className="text-red-600 text-sm mt-2">{barcodeError}</p>
            )}
            <p className="text-xs text-blue-600 mt-1">استخدم قارئ الباركود أو أدخل الكود يدوياً ثم اضغط Enter</p>
          </div>

          <div className="space-y-3">
            {transferItems.map((item, index) => {
              const availableQty = item.item_id ? getAvailableQty(item.item_id) : 0
              const isInsufficient = item.item_id && item.requested_quantity > availableQty
              return (
                <div key={index} className={`flex gap-3 items-start p-3 rounded-lg ${isInsufficient ? 'bg-red-50 border border-red-200' : 'bg-gray-50'}`}>
                  <div className="flex-1">
                    <select value={item.item_id} onChange={(e) => handleItemChange(index, 'item_id', e.target.value)}
                      aria-label="الصنف"
                      className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 text-sm">
                      <option value="">اختر الصنف</option>
                      {items.map(i => <option key={i.id} value={i.id}>{i.name_ar} ({i.code})</option>)}
                    </select>
                    {item.item_id && fromBranch && (
                      <p className={`text-xs mt-1 ${isInsufficient ? 'text-red-600 font-medium' : 'text-gray-500'}`}>
                        متوفر: {availableQty} {isInsufficient && '⚠️ الكمية غير كافية'}
                      </p>
                    )}
                  </div>
                  <div className="w-24">
                    <input type="number" min="1" value={item.requested_quantity}
                      onChange={(e) => handleItemChange(index, 'requested_quantity', Number(e.target.value))}
                      aria-label="الكمية"
                      className={`w-full px-3 py-2 border rounded-lg focus:ring-2 focus:ring-blue-500 text-sm ${isInsufficient ? 'border-red-400 bg-red-50' : 'border-gray-300'}`} placeholder="الكمية" />
                  </div>
                  {transferItems.length > 1 && (
                    <button type="button" onClick={() => handleRemoveItem(index)} className="p-2 text-red-500 hover:bg-red-50 rounded-lg" title="حذف">
                      <Trash2 className="w-4 h-4" />
                    </button>
                  )}
                </div>
              )
            })}
          </div>
        </div>

        <div>
          <label className="block text-sm font-medium text-gray-700 mb-2">ملاحظات</label>
          <textarea value={notes} onChange={(e) => setNotes(e.target.value)} rows={2}
            className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500" placeholder="ملاحظات إضافية..." />
        </div>

        <div className="flex items-center gap-4 pt-6 border-t border-gray-100">
          <button type="submit" disabled={loading}
            className="flex items-center gap-2 px-6 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 disabled:opacity-50">
            {loading ? <><span className="w-5 h-5 border-2 border-white border-t-transparent rounded-full animate-spin" />جاري الإرسال...</> : <><Save className="w-5 h-5" />إرسال الطلب</>}
          </button>
          <button type="button" onClick={() => navigate('/transfers')} className="px-6 py-2 text-gray-700 hover:bg-gray-100 rounded-lg">إلغاء</button>
        </div>
      </form>
    </div>
  )
}
