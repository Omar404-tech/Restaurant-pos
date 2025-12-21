import { useState, useEffect, FormEvent, useRef } from 'react'
import { useNavigate } from 'react-router-dom'
import { supabase, fixEncodingInData } from '../../lib/supabase'
import { useAuth } from '../../contexts/AuthContext'
import { Save, ArrowRight, AlertCircle, Plus, Trash2, Barcode, Search } from 'lucide-react'

interface Supplier {
  id: string
  name_ar: string
  code: string
}

interface Item {
  id: string
  code: string
  barcode: string | null
  name_ar: string
  purchase_price: number
}

interface ReturnItem {
  item_id: string
  quantity: number
  unit_price: number
  reason: string
  notes: string
}

export default function SupplierReturnForm() {
  const navigate = useNavigate()
  const { user } = useAuth()
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState('')
  const [suppliers, setSuppliers] = useState<Supplier[]>([])
  const [items, setItems] = useState<Item[]>([])

  const [formData, setFormData] = useState({
    supplier_id: '',
    return_reason: '',
    notes: '',
  })

  const [returnItems, setReturnItems] = useState<ReturnItem[]>([
    { item_id: '', quantity: 1, unit_price: 0, reason: '', notes: '' },
  ])

  const [barcodeInput, setBarcodeInput] = useState('')
  const [barcodeError, setBarcodeError] = useState('')
  const barcodeInputRef = useRef<HTMLInputElement>(null)

  useEffect(() => {
    fetchData()
  }, [])

  const fetchData = async () => {
    const [suppliersRes, itemsRes] = await Promise.all([
      supabase.from('suppliers').select('id, name_ar, code').eq('status', 'active').order('name_ar'),
      supabase.from('items').select('id, code, barcode, name_ar, purchase_price').eq('status', 'active').order('name_ar'),
    ])
    setSuppliers((fixEncodingInData(suppliersRes.data) as Supplier[]) || [])
    setItems((fixEncodingInData(itemsRes.data) as Item[]) || [])
  }

  const generateReturnNumber = () => {
    const date = new Date()
    const year = date.getFullYear()
    const month = (date.getMonth() + 1).toString().padStart(2, '0')
    const random = Math.floor(Math.random() * 10000).toString().padStart(4, '0')
    return `SRT-${year}-${month}-${random}`
  }

  const addItem = () => {
    setReturnItems([...returnItems, { item_id: '', quantity: 1, unit_price: 0, reason: '', notes: '' }])
  }

  const removeItem = (index: number) => {
    if (returnItems.length > 1) {
      setReturnItems(returnItems.filter((_, i) => i !== index))
    }
  }

  const updateItem = (index: number, field: keyof ReturnItem, value: string | number) => {
    const updated = [...returnItems]
    updated[index] = { ...updated[index], [field]: value }
    
    // Auto-fill unit price when item is selected
    if (field === 'item_id' && typeof value === 'string') {
      const item = items.find(i => i.id === value)
      if (item?.purchase_price) {
        updated[index].unit_price = item.purchase_price
      }
    }
    
    setReturnItems(updated)
  }

  // Barcode search function
  const handleBarcodeSearch = () => {
    if (!barcodeInput.trim()) return
    setBarcodeError('')

    // Search by barcode or code
    const item = items.find(i => i.barcode === barcodeInput.trim() || i.code === barcodeInput.trim())

    if (item) {
      // Check if item already exists in list
      const existingIndex = returnItems.findIndex(ri => ri.item_id === item.id)
      if (existingIndex >= 0) {
        // Increment quantity
        const updated = [...returnItems]
        updated[existingIndex].quantity += 1
        setReturnItems(updated)
      } else {
        // Add new item
        const newItem: ReturnItem = {
          item_id: item.id,
          quantity: 1,
          unit_price: item.purchase_price || 0,
          reason: '',
          notes: '',
        }
        // Replace empty item or add new
        const emptyIndex = returnItems.findIndex(ri => !ri.item_id)
        if (emptyIndex >= 0) {
          const updated = [...returnItems]
          updated[emptyIndex] = newItem
          setReturnItems(updated)
        } else {
          setReturnItems([...returnItems, newItem])
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

  // Calculate totals
  const calculateTotal = () => {
    return returnItems.reduce((sum, item) => sum + item.quantity * item.unit_price, 0)
  }

  const handleSubmit = async (e: FormEvent) => {
    e.preventDefault()
    setError('')
    setLoading(true)

    if (!formData.supplier_id) {
      setError('يرجى اختيار المورد')
      setLoading(false)
      return
    }

    const validItems = returnItems.filter(item => item.item_id && item.quantity > 0)
    if (validItems.length === 0) {
      setError('يرجى إضافة صنف واحد على الأقل')
      setLoading(false)
      return
    }

    // Create multiple supplier returns (one per item as per current schema)
    const returnNumber = generateReturnNumber()
    
    for (let i = 0; i < validItems.length; i++) {
      const item = validItems[i]
      const itemReturnNumber = validItems.length > 1 ? `${returnNumber}-${i + 1}` : returnNumber
      
      const { error: insertError } = await supabase.from('supplier_returns').insert({
        return_number: itemReturnNumber,
        supplier_id: formData.supplier_id,
        item_id: item.item_id,
        quantity: item.quantity,
        unit_price: item.unit_price,
        total_amount: item.quantity * item.unit_price,
        reason: item.reason || formData.return_reason,
        description: item.notes || formData.notes,
        status: 'pending',
        registered_by: user?.id,
        registered_at: new Date().toISOString(),
      })

      if (insertError) {
        setError('فشل في حفظ المرتجع: ' + insertError.message)
        setLoading(false)
        return
      }
    }

    navigate('/returns')
    setLoading(false)
  }

  return (
    <div className="max-w-4xl mx-auto">
      <div className="flex items-center gap-4 mb-6">
        <button
          type="button"
          onClick={() => navigate('/returns')}
          className="p-2 hover:bg-gray-100 rounded-lg"
          title="رجوع"
        >
          <ArrowRight className="w-5 h-5" />
        </button>
        <div>
          <h1 className="text-2xl font-bold text-gray-900">مرتجع جديد للمورد</h1>
          <p className="text-gray-600">إضافة مرتجع من المخزن الرئيسي للمورد</p>
        </div>
      </div>

      {error && (
        <div className="mb-6 p-4 bg-red-50 border border-red-200 rounded-lg flex items-center gap-3">
          <AlertCircle className="w-5 h-5 text-red-500 shrink-0" />
          <p className="text-red-700">{error}</p>
        </div>
      )}

      <form onSubmit={handleSubmit} className="space-y-6">
        {/* Supplier Selection */}
        <div className="bg-white rounded-lg shadow-sm border border-gray-100 p-6">
          <h2 className="text-lg font-semibold text-gray-900 mb-4">معلومات المرتجع</h2>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
            <div>
              <label htmlFor="supplier_id" className="block text-sm font-medium text-gray-700 mb-2">
                المورد <span className="text-red-500">*</span>
              </label>
              <select
                id="supplier_id"
                value={formData.supplier_id}
                onChange={(e) => setFormData({ ...formData, supplier_id: e.target.value })}
                required
                className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500"
              >
                <option value="">اختر المورد</option>
                {suppliers.map((s) => (
                  <option key={s.id} value={s.id}>
                    {s.name_ar} ({s.code})
                  </option>
                ))}
              </select>
            </div>

            <div>
              <label htmlFor="return_reason" className="block text-sm font-medium text-gray-700 mb-2">
                سبب الإرجاع العام
              </label>
              <input
                id="return_reason"
                type="text"
                value={formData.return_reason}
                onChange={(e) => setFormData({ ...formData, return_reason: e.target.value })}
                className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500"
                placeholder="مثال: انتهاء الصلاحية، تالف..."
              />
            </div>

            <div className="md:col-span-2">
              <label htmlFor="notes" className="block text-sm font-medium text-gray-700 mb-2">
                ملاحظات عامة
              </label>
              <textarea
                id="notes"
                value={formData.notes}
                onChange={(e) => setFormData({ ...formData, notes: e.target.value })}
                rows={2}
                className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500"
                placeholder="ملاحظات إضافية..."
              />
            </div>
          </div>
        </div>

        {/* Items */}
        <div className="bg-white rounded-lg shadow-sm border border-gray-100 p-6">
          <div className="flex items-center justify-between mb-4">
            <h2 className="text-lg font-semibold text-gray-900">الأصناف</h2>
            <button
              type="button"
              onClick={addItem}
              className="flex items-center gap-2 px-3 py-1.5 text-blue-600 hover:bg-blue-50 rounded-lg"
            >
              <Plus className="w-4 h-4" />
              إضافة صنف
            </button>
          </div>

          {/* Barcode Scanner Input */}
          <div className="mb-4 p-4 bg-teal-50 border border-teal-200 rounded-lg">
            <label className="flex items-center gap-2 text-sm font-medium text-teal-800 mb-2">
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
                className="flex-1 px-4 py-2 border border-teal-300 rounded-lg focus:ring-2 focus:ring-teal-500"
                dir="ltr"
              />
              <button
                type="button"
                onClick={handleBarcodeSearch}
                className="px-4 py-2 bg-teal-600 text-white rounded-lg hover:bg-teal-700"
                title="بحث بالباركود"
                aria-label="بحث بالباركود"
              >
                <Search className="w-5 h-5" />
              </button>
            </div>
            {barcodeError && <p className="text-red-600 text-sm mt-2">{barcodeError}</p>}
            <p className="text-xs text-teal-600 mt-1">
              استخدم قارئ الباركود أو أدخل الكود يدوياً ثم اضغط Enter
            </p>
          </div>

          {/* Items Table */}
          <div className="overflow-x-auto">
            <table className="w-full">
              <thead>
                <tr className="border-b border-gray-200">
                  <th className="text-right py-3 px-2 text-sm font-medium text-gray-700">الصنف</th>
                  <th className="text-right py-3 px-2 text-sm font-medium text-gray-700">الكمية</th>
                  <th className="text-right py-3 px-2 text-sm font-medium text-gray-700">سعر الوحدة</th>
                  <th className="text-right py-3 px-2 text-sm font-medium text-gray-700">الإجمالي</th>
                  <th className="text-right py-3 px-2 text-sm font-medium text-gray-700">السبب</th>
                  <th className="py-3 px-2"></th>
                </tr>
              </thead>
              <tbody>
                {returnItems.map((item, index) => (
                  <tr key={index} className="border-b border-gray-100">
                    <td className="py-3 px-2">
                      <select
                        value={item.item_id}
                        onChange={(e) => updateItem(index, 'item_id', e.target.value)}
                        className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 text-sm"
                        aria-label="اختر الصنف"
                      >
                        <option value="">اختر الصنف</option>
                        {items.map((i) => (
                          <option key={i.id} value={i.id}>
                            {i.name_ar} ({i.code})
                          </option>
                        ))}
                      </select>
                    </td>
                    <td className="py-3 px-2">
                      <input
                        type="number"
                        min="1"
                        value={item.quantity}
                        onChange={(e) => updateItem(index, 'quantity', Number(e.target.value))}
                        className="w-20 px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 text-sm"
                        dir="ltr"
                        aria-label="الكمية"
                      />
                    </td>
                    <td className="py-3 px-2">
                      <input
                        type="number"
                        min="0"
                        step="0.01"
                        value={item.unit_price}
                        onChange={(e) => updateItem(index, 'unit_price', Number(e.target.value))}
                        className="w-24 px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 text-sm"
                        dir="ltr"
                        aria-label="سعر الوحدة"
                      />
                    </td>
                    <td className="py-3 px-2 text-sm font-medium text-gray-900">
                      {(item.quantity * item.unit_price).toLocaleString('ar-EG')} ج.م
                    </td>
                    <td className="py-3 px-2">
                      <input
                        type="text"
                        value={item.reason}
                        onChange={(e) => updateItem(index, 'reason', e.target.value)}
                        className="w-32 px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 text-sm"
                        placeholder="السبب"
                        aria-label="السبب"
                      />
                    </td>
                    <td className="py-3 px-2">
                      <button
                        type="button"
                        onClick={() => removeItem(index)}
                        disabled={returnItems.length === 1}
                        className="p-2 text-red-500 hover:bg-red-50 rounded-lg disabled:opacity-30 disabled:cursor-not-allowed"
                        title="حذف"
                      >
                        <Trash2 className="w-4 h-4" />
                      </button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>

          {/* Total */}
          <div className="mt-4 pt-4 border-t border-gray-100 flex justify-end">
            <div className="bg-gray-50 rounded-lg p-4">
              <div className="flex justify-between gap-8">
                <span className="text-gray-600">إجمالي قيمة المرتجع:</span>
                <span className="font-bold text-lg text-red-600">
                  {calculateTotal().toLocaleString('ar-EG')} ج.م
                </span>
              </div>
              <p className="text-xs text-gray-500 mt-1">
                عدد الأصناف: {returnItems.filter(i => i.item_id).length}
              </p>
            </div>
          </div>
        </div>

        {/* Actions */}
        <div className="flex items-center gap-4">
          <button
            type="submit"
            disabled={loading}
            className="flex items-center gap-2 px-6 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 disabled:opacity-50"
          >
            {loading ? (
              <>
                <span className="w-5 h-5 border-2 border-white border-t-transparent rounded-full animate-spin" />
                جاري الحفظ...
              </>
            ) : (
              <>
                <Save className="w-5 h-5" />
                حفظ المرتجع
              </>
            )}
          </button>
          <button
            type="button"
            onClick={() => navigate('/returns')}
            className="px-6 py-2 text-gray-700 hover:bg-gray-100 rounded-lg"
          >
            إلغاء
          </button>
        </div>
      </form>
    </div>
  )
}
