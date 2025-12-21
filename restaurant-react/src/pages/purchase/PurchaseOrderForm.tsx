import { useState, useEffect, FormEvent } from 'react'
import { useNavigate } from 'react-router-dom'
import { supabase } from '../../lib/supabase'
import { branchesService } from '../../services/branches.service'
import { inventoryService } from '../../services/inventory.service'
import { suppliersService } from '../../services/suppliers.service'
import { useAuth } from '../../contexts/AuthContext'
import { Branch, Item, Supplier } from '../../types/database.types'
import { Save, ArrowRight, AlertCircle, Plus, Trash2 } from 'lucide-react'

interface OrderItem {
  item_id: string
  quantity: number
  unit_price: number
  notes: string
}

export default function PurchaseOrderForm() {
  const navigate = useNavigate()
  const { user } = useAuth()

  const [loading, setLoading] = useState(false)
  const [fetchLoading, setFetchLoading] = useState(true)
  const [error, setError] = useState('')

  const [branches, setBranches] = useState<Branch[]>([])
  const [items, setItems] = useState<Item[]>([])
  const [suppliers, setSuppliers] = useState<Supplier[]>([])

  const [formData, setFormData] = useState({
    supplier_id: '',
    branch_id: user?.branch_id || '',
    expected_delivery_date: '',
    notes: '',
  })

  const [orderItems, setOrderItems] = useState<OrderItem[]>([
    { item_id: '', quantity: 1, unit_price: 0, notes: '' }
  ])

  useEffect(() => {
    fetchData()
  }, [])

  const fetchData = async () => {
    const [branchesRes, itemsRes, suppliersRes] = await Promise.all([
      branchesService.getActive(),
      inventoryService.getAllItems(),
      suppliersService.getActive()
    ])
    if (branchesRes.data) setBranches(branchesRes.data)
    if (itemsRes.data) setItems(itemsRes.data.filter(i => i.status === 'active'))
    if (suppliersRes.data) setSuppliers(suppliersRes.data)
    setFetchLoading(false)
  }


  const calculateTotal = () => {
    return orderItems.reduce((sum, item) => sum + (item.quantity * item.unit_price), 0)
  }

  const handleAddItem = () => {
    setOrderItems([...orderItems, { item_id: '', quantity: 1, unit_price: 0, notes: '' }])
  }

  const handleRemoveItem = (index: number) => {
    if (orderItems.length > 1) {
      setOrderItems(orderItems.filter((_, i) => i !== index))
    }
  }

  const handleItemChange = (index: number, field: keyof OrderItem, value: string | number) => {
    const updated = [...orderItems]
    updated[index] = { ...updated[index], [field]: value }
    setOrderItems(updated)
  }

  const handleSubmit = async (e: FormEvent) => {
    e.preventDefault()
    setError('')

    // Check if user is logged in
    if (!user?.id) {
      setError('يجب تسجيل الدخول أولاً')
      return
    }

    const validItems = orderItems.filter(item => item.item_id && item.quantity > 0 && item.unit_price > 0)
    if (validItems.length === 0) {
      setError('يجب إضافة صنف واحد على الأقل مع السعر')
      return
    }

    setLoading(true)

    const orderNumber = `PO-${Date.now()}`
    const totalAmount = calculateTotal()

    const { data: order, error: orderError } = await supabase
      .from('purchase_orders')
      .insert({
        order_number: orderNumber,
        order_date: new Date().toISOString(),
        supplier_id: formData.supplier_id,
        branch_id: formData.branch_id,
        subtotal: totalAmount,
        total_amount: totalAmount,
        status: 'pending',
        expected_delivery_date: formData.expected_delivery_date || null,
        notes: formData.notes || null,
        created_by: user.id,
      })
      .select()
      .single()

    if (orderError) {
      console.error('Purchase order error:', orderError)
      setError('فشل في حفظ أمر الشراء: ' + (orderError.message || 'خطأ غير معروف'))
      setLoading(false)
      return
    }

    const orderItemsData = validItems.map(item => ({
      order_id: order.id,
      item_id: item.item_id,
      quantity: item.quantity,
      unit_price: item.unit_price,
      total_price: item.quantity * item.unit_price,
      notes: item.notes || null,
    }))

    const { error: itemsError } = await supabase
      .from('purchase_order_items')
      .insert(orderItemsData)

    if (itemsError) {
      setError('فشل في حفظ أصناف الأمر')
    } else {
      navigate('/purchase/orders')
    }
    setLoading(false)
  }

  const handleChange = (field: string, value: string) => {
    setFormData(prev => ({ ...prev, [field]: value }))
  }

  if (fetchLoading) {
    return (
      <div className="flex items-center justify-center h-64">
        <div className="w-8 h-8 border-4 border-blue-600 border-t-transparent rounded-full animate-spin" />
      </div>
    )
  }

  return (
    <div className="max-w-5xl mx-auto">
      <div className="flex items-center gap-4 mb-6">
        <button type="button" onClick={() => navigate(-1)} className="p-2 hover:bg-gray-100 rounded-lg" title="رجوع">
          <ArrowRight className="w-5 h-5" />
        </button>
        <div>
          <h1 className="text-2xl font-bold text-gray-900">أمر شراء جديد</h1>
          <p className="text-gray-600">إنشاء أمر شراء جديد</p>
        </div>
      </div>

      {error && (
        <div className="mb-6 p-4 bg-red-50 border border-red-200 rounded-lg flex items-center gap-3">
          <AlertCircle className="w-5 h-5 text-red-500 shrink-0" />
          <p className="text-red-700">{error}</p>
        </div>
      )}

      <form onSubmit={handleSubmit} className="space-y-6">
        <div className="bg-white rounded-lg shadow-sm border border-gray-100 p-6">
          <h2 className="text-lg font-semibold text-gray-900 mb-4">معلومات الأمر</h2>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-2">المورد <span className="text-red-500">*</span></label>
              <select value={formData.supplier_id} onChange={(e) => handleChange('supplier_id', e.target.value)} required
                aria-label="المورد" className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500">
                <option value="">اختر المورد</option>
                {suppliers.map(s => <option key={s.id} value={s.id}>{s.name_ar} ({s.code})</option>)}
              </select>
            </div>
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-2">الفرع <span className="text-red-500">*</span></label>
              <select value={formData.branch_id} onChange={(e) => handleChange('branch_id', e.target.value)} required
                aria-label="الفرع" className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500">
                <option value="">اختر الفرع</option>
                {branches.map(b => <option key={b.id} value={b.id}>{b.name_ar}</option>)}
              </select>
            </div>
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-2">تاريخ التسليم المتوقع</label>
              <input type="date" value={formData.expected_delivery_date} onChange={(e) => handleChange('expected_delivery_date', e.target.value)}
                aria-label="تاريخ التسليم المتوقع" className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500" dir="ltr" />
            </div>
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-2">ملاحظات</label>
              <input type="text" value={formData.notes} onChange={(e) => handleChange('notes', e.target.value)}
                className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500" placeholder="ملاحظات..." />
            </div>
          </div>
        </div>


        {/* Order Items */}
        <div className="bg-white rounded-lg shadow-sm border border-gray-100 p-6">
          <div className="flex items-center justify-between mb-4">
            <h2 className="text-lg font-semibold text-gray-900">الأصناف</h2>
            <button type="button" onClick={handleAddItem}
              className="flex items-center gap-2 px-4 py-2 text-blue-600 hover:bg-blue-50 rounded-lg">
              <Plus className="w-4 h-4" />
              إضافة صنف
            </button>
          </div>

          <div className="overflow-x-auto">
            <table className="w-full">
              <thead>
                <tr className="border-b border-gray-200">
                  <th className="text-right py-3 px-2 text-sm font-medium text-gray-700">الصنف</th>
                  <th className="text-right py-3 px-2 text-sm font-medium text-gray-700">الكمية</th>
                  <th className="text-right py-3 px-2 text-sm font-medium text-gray-700">سعر الوحدة</th>
                  <th className="text-right py-3 px-2 text-sm font-medium text-gray-700">الإجمالي</th>
                  <th className="py-3 px-2"></th>
                </tr>
              </thead>
              <tbody>
                {orderItems.map((item, index) => (
                  <tr key={index} className="border-b border-gray-100">
                    <td className="py-3 px-2">
                      <select value={item.item_id} onChange={(e) => handleItemChange(index, 'item_id', e.target.value)}
                        aria-label="اختر الصنف" className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 text-sm">
                        <option value="">اختر الصنف</option>
                        {items.map(i => <option key={i.id} value={i.id}>{i.name_ar} ({i.code})</option>)}
                      </select>
                    </td>
                    <td className="py-3 px-2">
                      <input type="number" min="1" value={item.quantity} onChange={(e) => handleItemChange(index, 'quantity', Number(e.target.value))}
                        aria-label="الكمية" className="w-24 px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 text-sm" dir="ltr" />
                    </td>
                    <td className="py-3 px-2">
                      <input type="number" min="0" step="0.01" value={item.unit_price} onChange={(e) => handleItemChange(index, 'unit_price', Number(e.target.value))}
                        aria-label="سعر الوحدة" className="w-28 px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 text-sm" dir="ltr" />
                    </td>
                    <td className="py-3 px-2 text-sm font-medium text-gray-900">
                      {(item.quantity * item.unit_price).toLocaleString('ar-EG')} ج.م
                    </td>
                    <td className="py-3 px-2">
                      <button type="button" onClick={() => handleRemoveItem(index)} disabled={orderItems.length === 1}
                        className="p-2 text-red-500 hover:bg-red-50 rounded-lg disabled:opacity-30 disabled:cursor-not-allowed" title="حذف">
                        <Trash2 className="w-4 h-4" />
                      </button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>

          <div className="mt-4 pt-4 border-t border-gray-100 flex justify-end">
            <div className="bg-gray-50 rounded-lg p-4">
              <div className="flex justify-between gap-8">
                <span className="text-gray-600">الإجمالي:</span>
                <span className="font-bold text-lg text-gray-900">{calculateTotal().toLocaleString('ar-EG')} ج.م</span>
              </div>
            </div>
          </div>
        </div>

        {/* Actions */}
        <div className="flex items-center gap-4">
          <button type="submit" disabled={loading}
            className="flex items-center gap-2 px-6 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 disabled:opacity-50">
            {loading ? (
              <><span className="w-5 h-5 border-2 border-white border-t-transparent rounded-full animate-spin" />جاري الحفظ...</>
            ) : (
              <><Save className="w-5 h-5" />حفظ الأمر</>
            )}
          </button>
          <button type="button" onClick={() => navigate(-1)} className="px-6 py-2 text-gray-700 hover:bg-gray-100 rounded-lg">
            إلغاء
          </button>
        </div>
      </form>
    </div>
  )
}
