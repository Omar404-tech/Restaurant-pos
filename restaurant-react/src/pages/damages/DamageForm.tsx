import { useState, useEffect, FormEvent, useRef } from 'react'
import { useNavigate } from 'react-router-dom'
import { damagesService } from '../../services/damages.service'
import { branchesService } from '../../services/branches.service'
import { inventoryService } from '../../services/inventory.service'
import { useAuth } from '../../contexts/AuthContext'
import { Branch, Item, DamageReason } from '../../types/database.types'
import { Save, ArrowRight, AlertCircle, Barcode, Search, Check } from 'lucide-react'

export default function DamageForm() {
  const navigate = useNavigate()
  const { user } = useAuth()
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState('')
  const [branches, setBranches] = useState<Branch[]>([])
  const [items, setItems] = useState<Item[]>([])
  const [reasons, setReasons] = useState<DamageReason[]>([])

  // Get branch_id - handle both direct and nested formats
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  const userObj = user as any
  const userBranchId = userObj?.branch_id || userObj?.branch?.id || ''
  const [branchId, setBranchId] = useState(userBranchId)
  const [itemId, setItemId] = useState('')
  const [quantity, setQuantity] = useState(1)
  const [unitCost, setUnitCost] = useState(0)
  const [reasonId, setReasonId] = useState('')
  const [description, setDescription] = useState('')
  const [barcodeInput, setBarcodeInput] = useState('')
  const [barcodeError, setBarcodeError] = useState('')
  const [selectedItemName, setSelectedItemName] = useState('')
  const barcodeInputRef = useRef<HTMLInputElement>(null)

  useEffect(() => {
    fetchData()
  }, [])

  const fetchData = async () => {
    const [branchesRes, itemsRes, reasonsRes] = await Promise.all([
      branchesService.getActive(),
      inventoryService.getAllItems(),
      damagesService.getReasons(),
    ])
    setBranches(branchesRes.data || [])
    setItems(itemsRes.data || [])
    setReasons(reasonsRes.data || [])
  }

  const handleItemChange = (id: string) => {
    setItemId(id)
    const item = items.find(i => i.id === id)
    if (item) {
      if (item.purchase_price) {
        setUnitCost(item.purchase_price)
      }
      setSelectedItemName(item.name_ar)
    } else {
      setSelectedItemName('')
    }
  }

  // Barcode search function
  const handleBarcodeSearch = () => {
    if (!barcodeInput.trim()) return
    setBarcodeError('')

    // Search by barcode or code
    const item = items.find(i => 
      (i as Item & { barcode?: string }).barcode === barcodeInput.trim() || 
      i.code === barcodeInput.trim()
    )

    if (item) {
      setItemId(item.id)
      setSelectedItemName(item.name_ar)
      if (item.purchase_price) {
        setUnitCost(item.purchase_price)
      }
      setBarcodeInput('')
      setBarcodeError('')
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

  const handleSubmit = async (e: FormEvent) => {
    e.preventDefault()
    setError('')

    if (!branchId || !itemId || !reasonId) {
      setError('يرجى ملء جميع الحقول المطلوبة')
      return
    }

    setLoading(true)
    const { error } = await damagesService.create({
      branch_id: branchId,
      item_id: itemId,
      quantity,
      unit_cost: unitCost,
      reason_id: reasonId,
      description,
      registered_by: user?.id || '',
    })

    if (error) {
      setError('فشل في تسجيل التالف')
    } else {
      navigate('/damages')
    }
    setLoading(false)
  }

  return (
    <div className="max-w-2xl mx-auto">
      <div className="flex items-center gap-4 mb-6">
        <button onClick={() => navigate('/damages')} className="p-2 hover:bg-gray-100 rounded-lg" title="رجوع">
          <ArrowRight className="w-5 h-5" />
        </button>
        <div>
          <h1 className="text-2xl font-bold text-gray-900">تسجيل تالف</h1>
          <p className="text-gray-600">تسجيل صنف تالف أو هالك</p>
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
            <label className="block text-sm font-medium text-gray-700 mb-2">الفرع <span className="text-red-500">*</span></label>
            <select value={branchId} onChange={(e) => setBranchId(e.target.value)} required
              aria-label="الفرع"
              className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500">
              <option value="">اختر الفرع</option>
              {branches.map(b => <option key={b.id} value={b.id}>{b.name_ar}</option>)}
            </select>
          </div>
          <div className="md:col-span-2">
            <label className="flex items-center gap-2 text-sm font-medium text-gray-700 mb-2">
              <Barcode className="w-4 h-4" />
              البحث بالباركود
            </label>
            <div className="flex gap-2">
              <input
                ref={barcodeInputRef}
                type="text"
                value={barcodeInput}
                onChange={(e) => setBarcodeInput(e.target.value)}
                onKeyPress={handleBarcodeKeyPress}
                placeholder="امسح الباركود أو أدخل كود الصنف"
                className="flex-1 px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500"
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
            {barcodeError && <p className="text-red-600 text-sm mt-1">{barcodeError}</p>}
            {selectedItemName && (
              <div className="flex items-center gap-2 mt-2 p-2 bg-green-50 border border-green-200 rounded-lg text-green-700">
                <Check className="w-4 h-4" />
                <span>تم اختيار: {selectedItemName}</span>
              </div>
            )}
          </div>
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">الصنف <span className="text-red-500">*</span></label>
            <select value={itemId} onChange={(e) => handleItemChange(e.target.value)} required
              aria-label="الصنف"
              className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500">
              <option value="">اختر الصنف</option>
              {items.map(i => <option key={i.id} value={i.id}>{i.name_ar} ({i.code})</option>)}
            </select>
          </div>
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">الكمية <span className="text-red-500">*</span></label>
            <input type="number" min="1" value={quantity} onChange={(e) => setQuantity(Number(e.target.value))} required
              aria-label="الكمية"
              className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500" />
          </div>
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">تكلفة الوحدة</label>
            <input type="number" step="0.01" value={unitCost} onChange={(e) => setUnitCost(Number(e.target.value))}
              aria-label="تكلفة الوحدة"
              className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500" dir="ltr" />
          </div>
          <div className="md:col-span-2">
            <label className="block text-sm font-medium text-gray-700 mb-2">سبب التلف <span className="text-red-500">*</span></label>
            <select value={reasonId} onChange={(e) => setReasonId(e.target.value)} required
              aria-label="سبب التلف"
              className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500">
              <option value="">اختر السبب</option>
              {reasons.map(r => <option key={r.id} value={r.id}>{r.name_ar}</option>)}
            </select>
          </div>
          <div className="md:col-span-2">
            <label className="block text-sm font-medium text-gray-700 mb-2">وصف إضافي</label>
            <textarea value={description} onChange={(e) => setDescription(e.target.value)} rows={3}
              className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500" placeholder="وصف تفصيلي للتلف..." />
          </div>
        </div>

        {quantity > 0 && unitCost > 0 && (
          <div className="p-4 bg-red-50 rounded-lg">
            <p className="text-sm text-gray-600">إجمالي التكلفة المقدرة:</p>
            <p className="text-xl font-bold text-red-600">{(quantity * unitCost).toLocaleString('ar-EG')} ج.م</p>
          </div>
        )}

        <div className="flex items-center gap-4 pt-6 border-t border-gray-100">
          <button type="submit" disabled={loading}
            className="flex items-center gap-2 px-6 py-2 bg-red-600 text-white rounded-lg hover:bg-red-700 disabled:opacity-50">
            {loading ? <><span className="w-5 h-5 border-2 border-white border-t-transparent rounded-full animate-spin" />جاري التسجيل...</> : <><Save className="w-5 h-5" />تسجيل التالف</>}
          </button>
          <button type="button" onClick={() => navigate('/damages')} className="px-6 py-2 text-gray-700 hover:bg-gray-100 rounded-lg">إلغاء</button>
        </div>
      </form>
    </div>
  )
}
