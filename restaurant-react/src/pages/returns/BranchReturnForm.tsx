import { useState, useEffect, FormEvent, useRef } from 'react'
import { useNavigate } from 'react-router-dom'
import { supabase, fixEncodingInData } from '../../lib/supabase'
import { useAuth } from '../../contexts/AuthContext'
import { Save, ArrowRight, AlertCircle, Plus, Trash2, Barcode, Search } from 'lucide-react'

interface Branch {
  id: string
  name_ar: string
  code: string
  is_main_warehouse: boolean
}

interface Item {
  id: string
  code: string
  name_ar: string
}

interface ReturnItem {
  item_id: string
  quantity: number
  reason: string
  notes: string
}

export default function BranchReturnForm() {
  const navigate = useNavigate()
  const { user } = useAuth()
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState('')
  const [items, setItems] = useState<Item[]>([])
  const [branches, setBranches] = useState<Branch[]>([])
  const [mainWarehouse, setMainWarehouse] = useState<Branch | null>(null)

  const [formData, setFormData] = useState({
    from_branch_id: '',
    return_reason: '',
    notes: '',
  })

  const [returnItems, setReturnItems] = useState<ReturnItem[]>([
    { item_id: '', quantity: 1, reason: '', notes: '' },
  ])
  const [barcodeInput, setBarcodeInput] = useState('')
  const [barcodeError, setBarcodeError] = useState('')
  const barcodeInputRef = useRef<HTMLInputElement>(null)

  // Get user role
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  const userRole = typeof user?.role === 'object' ? (user.role as any)?.name : user?.role
  const isBranchSupervisor = userRole === 'branch_supervisor'

  useEffect(() => {
    fetchData()
  }, [user])

  const fetchData = async () => {
    const [branchesRes, itemsRes] = await Promise.all([
      supabase.from('branches').select('id, name_ar, code, is_main_warehouse').eq('status', 'active').order('name_ar'),
      supabase.from('items').select('id, code, name_ar').eq('status', 'active').order('name_ar'),
    ])
    
    const branchList = fixEncodingInData(branchesRes.data) as Branch[] || []
    
    // Set main warehouse
    const mainWh = branchList.find(b => b.is_main_warehouse)
    if (mainWh) {
      setMainWarehouse(mainWh)
    }
    
    // Filter out main warehouse from branch list (only show actual branches)
    const actualBranches = branchList.filter(b => !b.is_main_warehouse)
    setBranches(actualBranches)
    
    // Auto-select branch for branch supervisor
    if (isBranchSupervisor && user?.branch_id) {
      setFormData(prev => ({ ...prev, from_branch_id: user.branch_id as string }))
    }
    
    setItems(fixEncodingInData(itemsRes.data) as Item[] || [])
  }

  const generateReturnNumber = () => {
    const date = new Date()
    const year = date.getFullYear()
    const month = (date.getMonth() + 1).toString().padStart(2, '0')
    const random = Math.floor(Math.random() * 10000).toString().padStart(4, '0')
    return `BRT-${year}-${month}-${random}`
  }

  const addItem = () => {
    setReturnItems([...returnItems, { item_id: '', quantity: 1, reason: '', notes: '' }])
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
          reason: '',
          notes: ''
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

  const removeItem = (index: number) => {
    if (returnItems.length > 1) {
      setReturnItems(returnItems.filter((_, i) => i !== index))
    }
  }

  const updateItem = (index: number, field: keyof ReturnItem, value: string | number) => {
    const updated = [...returnItems]
    updated[index] = { ...updated[index], [field]: value }
    setReturnItems(updated)
  }

  const handleSubmit = async (e: FormEvent) => {
    e.preventDefault()
    setError('')
    setLoading(true)

    if (!user?.id) {
      setError('يرجى تسجيل الدخول أولاً')
      setLoading(false)
      return
    }

    if (!formData.from_branch_id) {
      setError('يرجى اختيار الفرع المصدر')
      setLoading(false)
      return
    }

    if (!mainWarehouse) {
      setError('لم يتم تحديد المخزن الرئيسي')
      setLoading(false)
      return
    }

    if (!formData.return_reason || formData.return_reason.trim() === '') {
      setError('يرجى إدخال سبب الإرجاع')
      setLoading(false)
      return
    }

    const validItems = returnItems.filter(item => item.item_id && item.quantity > 0)
    console.log('Return items before submit:', returnItems)
    console.log('Valid items:', validItems)
    
    if (validItems.length === 0) {
      setError('يرجى إضافة صنف واحد على الأقل')
      setLoading(false)
      return
    }

    // Create branch return
    const returnNumber = generateReturnNumber()
    console.log('Creating branch return:', {
      return_number: returnNumber,
      from_branch_id: formData.from_branch_id,
      to_branch_id: mainWarehouse.id,
      return_reason: formData.return_reason,
      requested_by: user.id,
    })

    const { data: returnData, error: returnError } = await supabase
      .from('branch_returns')
      .insert({
        return_number: returnNumber,
        return_date: new Date().toISOString(),
        from_branch_id: formData.from_branch_id,
        to_branch_id: mainWarehouse.id,
        status: 'pending',
        return_reason: formData.return_reason.trim(),
        total_items: validItems.length,
        total_quantity: validItems.reduce((sum, item) => sum + item.quantity, 0),
        notes: formData.notes || '',
        requested_by: user.id,
        requested_at: new Date().toISOString(),
      })
      .select()
      .single()

    if (returnError) {
      console.error('Error creating branch return:', returnError)
      setError('فشل في حفظ المرتجع: ' + returnError.message)
      setLoading(false)
      return
    }

    console.log('Branch return created:', returnData)

    // Create return items
    const itemsToInsert = validItems.map(item => ({
      return_id: returnData.id,
      item_id: item.item_id,
      requested_quantity: item.quantity,
      item_reason: item.reason || '',
      notes: item.notes || '',
    }))

    console.log('Creating return items:', itemsToInsert)

    const { error: itemsError } = await supabase
      .from('branch_return_items')
      .insert(itemsToInsert)

    if (itemsError) {
      console.error('Error creating return items:', itemsError)
      setError('فشل في حفظ الأصناف: ' + itemsError.message)
    } else {
      console.log('Return items created successfully')
      navigate('/returns')
    }
    setLoading(false)
  }

  return (
    <div className="max-w-3xl mx-auto">
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
          <h1 className="text-2xl font-bold text-gray-900">مرتجع جديد للرئيسي</h1>
          <p className="text-gray-600">إضافة مرتجع من الفرع للمخزن الرئيسي</p>
        </div>
      </div>

      {error && (
        <div className="mb-6 p-4 bg-red-50 border border-red-200 rounded-lg flex items-center gap-3">
          <AlertCircle className="w-5 h-5 text-red-500 shrink-0" />
          <p className="text-red-700">{error}</p>
        </div>
      )}

      <form onSubmit={handleSubmit} className="space-y-6">
        {/* Branch Selection */}
        <div className="bg-white rounded-lg shadow-sm border border-gray-100 p-6">
          <h2 className="text-lg font-semibold text-gray-900 mb-4">معلومات التحويل</h2>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-6 mb-6">
            <div>
              <label htmlFor="from_branch" className="block text-sm font-medium text-gray-700 mb-2">
                من الفرع <span className="text-red-500">*</span>
              </label>
              <select
                id="from_branch"
                value={formData.from_branch_id}
                onChange={(e) => setFormData({ ...formData, from_branch_id: e.target.value })}
                className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 disabled:bg-gray-100"
                aria-label="من الفرع"
                disabled={isBranchSupervisor}
              >
                <option value="">اختر الفرع</option>
                {branches.map((branch) => (
                  <option key={branch.id} value={branch.id}>
                    {branch.name_ar} ({branch.code})
                  </option>
                ))}
              </select>
              {isBranchSupervisor && (
                <p className="text-xs text-gray-500 mt-1">يتم تحديد الفرع تلقائياً بناءً على فرعك</p>
              )}
            </div>
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-2">
                إلى المخزن الرئيسي
              </label>
              <div className="px-4 py-2 bg-blue-50 border border-blue-200 rounded-lg text-blue-800 font-medium">
                {mainWarehouse?.name_ar || 'جاري التحميل...'} ({mainWarehouse?.code})
              </div>
            </div>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
            <div>
              <label htmlFor="return_reason" className="block text-sm font-medium text-gray-700 mb-2">
                سبب الإرجاع <span className="text-red-500">*</span>
              </label>
              <input
                id="return_reason"
                type="text"
                value={formData.return_reason}
                onChange={(e) => setFormData({ ...formData, return_reason: e.target.value })}
                className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500"
                placeholder="مثال: فائض مخزون، قرب انتهاء الصلاحية..."
                required
              />
            </div>

            <div>
              <label htmlFor="notes" className="block text-sm font-medium text-gray-700 mb-2">
                ملاحظات
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
          <div className="mb-4 p-4 bg-purple-50 border border-purple-200 rounded-lg">
            <label className="flex items-center gap-2 text-sm font-medium text-purple-800 mb-2">
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
                className="flex-1 px-4 py-2 border border-purple-300 rounded-lg focus:ring-2 focus:ring-purple-500"
                dir="ltr"
              />
              <button
                type="button"
                onClick={handleBarcodeSearch}
                className="px-4 py-2 bg-purple-600 text-white rounded-lg hover:bg-purple-700"
                title="بحث بالباركود"
                aria-label="بحث بالباركود"
              >
                <Search className="w-5 h-5" />
              </button>
            </div>
            {barcodeError && <p className="text-red-600 text-sm mt-2">{barcodeError}</p>}
            <p className="text-xs text-purple-600 mt-1">استخدم قارئ الباركود أو أدخل الكود يدوياً ثم اضغط Enter</p>
          </div>

          <div className="space-y-4">
            {returnItems.map((item, index) => (
              <div key={index} className="flex gap-4 items-start p-4 bg-gray-50 rounded-lg">
                <div className="flex-1 grid grid-cols-1 md:grid-cols-4 gap-4">
                  <div>
                    <label className="block text-xs text-gray-500 mb-1">الصنف</label>
                    <select
                      value={item.item_id}
                      onChange={(e) => updateItem(index, 'item_id', e.target.value)}
                      className="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:ring-2 focus:ring-blue-500"
                      aria-label="الصنف"
                    >
                      <option value="">اختر</option>
                      {items.map((i) => (
                        <option key={i.id} value={i.id}>
                          {i.name_ar}
                        </option>
                      ))}
                    </select>
                  </div>
                  <div>
                    <label className="block text-xs text-gray-500 mb-1">الكمية</label>
                    <input
                      type="number"
                      min="1"
                      step="1"
                      value={item.quantity}
                      onChange={(e) => {
                        const val = parseInt(e.target.value, 10)
                        updateItem(index, 'quantity', isNaN(val) ? 1 : val)
                      }}
                      onFocus={(e) => e.target.select()}
                      className="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:ring-2 focus:ring-blue-500"
                      dir="ltr"
                      aria-label="الكمية"
                    />
                  </div>
                  <div>
                    <label className="block text-xs text-gray-500 mb-1">السبب</label>
                    <input
                      type="text"
                      value={item.reason}
                      onChange={(e) => updateItem(index, 'reason', e.target.value)}
                      className="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:ring-2 focus:ring-blue-500"
                      placeholder="السبب"
                      aria-label="السبب"
                    />
                  </div>
                  <div>
                    <label className="block text-xs text-gray-500 mb-1">ملاحظات</label>
                    <input
                      type="text"
                      value={item.notes}
                      onChange={(e) => updateItem(index, 'notes', e.target.value)}
                      className="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:ring-2 focus:ring-blue-500"
                      placeholder="ملاحظات"
                      aria-label="ملاحظات"
                    />
                  </div>
                </div>
                {returnItems.length > 1 && (
                  <button
                    type="button"
                    onClick={() => removeItem(index)}
                    className="p-2 text-red-500 hover:bg-red-50 rounded-lg"
                    title="حذف"
                  >
                    <Trash2 className="w-4 h-4" />
                  </button>
                )}
              </div>
            ))}
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
                حفظ
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
