import { useState, useEffect } from 'react'
import { useNavigate, useParams } from 'react-router-dom'
import { supabase, fixEncodingInData } from '../../lib/supabase'
import { useAuth } from '../../contexts/AuthContext'
import { formatDate, getStatusColor, translateStatus } from '../../lib/utils'
import { ArrowRight, Package, Truck, Check, X } from 'lucide-react'

interface SupplierReturn {
  id: string
  return_number: string
  registered_at: string
  quantity: number
  reason: string
  description: string
  status: string
  item: { id: string; code: string; name_ar: string }
  supplier: { id: string; name_ar: string; code: string }
}

export default function SupplierReturnDetail() {
  const { id } = useParams()
  const navigate = useNavigate()
  const { user } = useAuth()
  const [returnData, setReturnData] = useState<SupplierReturn | null>(null)
  const [loading, setLoading] = useState(true)
  const [actionLoading, setActionLoading] = useState(false)

  useEffect(() => {
    if (id) fetchReturn(id)
  }, [id])

  const fetchReturn = async (returnId: string) => {
    const { data } = await supabase
      .from('supplier_returns')
      .select(`
        id, return_number, registered_at, quantity, reason, description, status,
        item:items(id, code, name_ar),
        supplier:suppliers(id, name_ar, code)
      `)
      .eq('id', returnId)
      .single()
    
    setReturnData(fixEncodingInData(data) as unknown as SupplierReturn)
    setLoading(false)
  }

  const handleApprove = async () => {
    if (!returnData || !user) return
    setActionLoading(true)
    
    // Update status to approved
    // Note: Inventory deduction is handled by database trigger (trg_update_inventory_on_return)
    const { error } = await supabase
      .from('supplier_returns')
      .update({ 
        status: 'approved',
        approved_by: user.id,
        approved_at: new Date().toISOString(),
        updated_at: new Date().toISOString()
      })
      .eq('id', returnData.id)
    
    if (error) {
      console.error('Approve error:', error)
      alert('حدث خطأ: ' + error.message)
    } else {
      fetchReturn(returnData.id)
    }
    setActionLoading(false)
  }

  const handleReject = async () => {
    if (!returnData || !user) return
    const reason = prompt('سبب الرفض:')
    if (reason === null) return
    setActionLoading(true)
    
    await supabase
      .from('supplier_returns')
      .update({ 
        status: 'rejected',
        rejected_by: user.id,
        rejected_at: new Date().toISOString(),
        description: returnData.description ? `${returnData.description}\nسبب الرفض: ${reason}` : `سبب الرفض: ${reason}`,
        updated_at: new Date().toISOString()
      })
      .eq('id', returnData.id)
    
    fetchReturn(returnData.id)
    setActionLoading(false)
  }

  const handleComplete = async () => {
    if (!returnData || !user) return
    setActionLoading(true)
    
    // Note: Inventory deduction was already handled by database trigger (trg_update_inventory_on_return)
    // when status changed to 'approved'. This function marks it as 'received' (shipped to supplier).
    
    // Update status to received (enum values: pending, approved, rejected, received)
    const { error } = await supabase
      .from('supplier_returns')
      .update({ 
        status: 'received',
        received_by_supplier_at: new Date().toISOString(),
        updated_at: new Date().toISOString()
      })
      .eq('id', returnData.id)
    
    if (error) {
      console.error('Complete error:', error)
      alert('حدث خطأ: ' + error.message)
    } else {
      fetchReturn(returnData.id)
    }
    setActionLoading(false)
  }

  if (loading) {
    return <div className="flex items-center justify-center h-64"><div className="w-8 h-8 border-4 border-blue-600 border-t-transparent rounded-full animate-spin" /></div>
  }

  if (!returnData) {
    return <div className="text-center py-12"><p className="text-gray-600">المرتجع غير موجود</p></div>
  }

  // Get user role
  const userRole = typeof user?.role === 'object' && user?.role !== null 
    ? (user.role as { name: string }).name 
    : user?.role

  const canApprove = returnData.status === 'pending' && (userRole === 'admin' || userRole === 'warehouse_manager')
  const canComplete = returnData.status === 'approved' && (userRole === 'admin' || userRole === 'warehouse_manager')

  return (
    <div className="max-w-3xl mx-auto space-y-6">
      <div className="flex items-center gap-4">
        <button type="button" onClick={() => navigate('/returns')} className="p-2 hover:bg-gray-100 rounded-lg" title="رجوع">
          <ArrowRight className="w-5 h-5" />
        </button>
        <div className="flex-1">
          <h1 className="text-2xl font-bold text-gray-900">مرتجع للمورد</h1>
          <p className="text-gray-600">{returnData.return_number}</p>
        </div>
        <span className={`px-3 py-1 rounded-full text-sm font-medium ${getStatusColor(returnData.status)}`}>
          {translateStatus(returnData.status)}
        </span>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
        <div className="bg-white rounded-lg shadow-sm border border-gray-100 p-6">
          <h3 className="font-semibold text-gray-900 mb-4 flex items-center gap-2"><Truck className="w-5 h-5" /> المورد</h3>
          <p className="text-lg font-medium">{returnData.supplier?.name_ar}</p>
          <p className="text-sm text-gray-500">{returnData.supplier?.code}</p>
        </div>
        <div className="bg-white rounded-lg shadow-sm border border-gray-100 p-6">
          <h3 className="font-semibold text-gray-900 mb-4 flex items-center gap-2"><Package className="w-5 h-5" /> الصنف</h3>
          <p className="text-lg font-medium">{returnData.item?.name_ar}</p>
          <p className="text-sm text-gray-500">{returnData.item?.code}</p>
        </div>
      </div>

      <div className="bg-white rounded-lg shadow-sm border border-gray-100 p-6">
        <h3 className="font-semibold text-gray-900 mb-4">تفاصيل المرتجع</h3>
        <div className="grid grid-cols-2 gap-4 text-sm">
          <div><span className="text-gray-500">التاريخ:</span> <span className="font-medium">{formatDate(returnData.registered_at)}</span></div>
          <div><span className="text-gray-500">الكمية:</span> <span className="font-medium">{returnData.quantity}</span></div>
          <div><span className="text-gray-500">السبب:</span> <span className="font-medium">{returnData.reason || '-'}</span></div>
          {returnData.description && <div className="col-span-2"><span className="text-gray-500">ملاحظات:</span> <span className="font-medium">{returnData.description}</span></div>}
        </div>
      </div>

      {(canApprove || canComplete) && (
        <div className="flex gap-3">
          {canApprove && (
            <>
              <button type="button" onClick={handleApprove} disabled={actionLoading}
                className="flex items-center gap-2 px-6 py-2 bg-green-600 text-white rounded-lg hover:bg-green-700 disabled:opacity-50">
                <Check className="w-5 h-5" /> موافقة
              </button>
              <button type="button" onClick={handleReject} disabled={actionLoading}
                className="flex items-center gap-2 px-6 py-2 bg-red-600 text-white rounded-lg hover:bg-red-700 disabled:opacity-50">
                <X className="w-5 h-5" /> رفض
              </button>
            </>
          )}
          {canComplete && (
            <button type="button" onClick={handleComplete} disabled={actionLoading}
              className="flex items-center gap-2 px-6 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 disabled:opacity-50">
              <Check className="w-5 h-5" /> تأكيد الإرجاع للمورد
            </button>
          )}
        </div>
      )}
    </div>
  )
}
