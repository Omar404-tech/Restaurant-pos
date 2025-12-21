import { useEffect, useState } from 'react'
import { useParams, Link } from 'react-router-dom'
import { purchaseService, PurchaseOrderWithDetails } from '../../services/purchase.service'
import { useAuth } from '../../contexts/AuthContext'
import { formatDate, formatCurrency, formatNumber } from '../../lib/utils'
import { ArrowRight, Package, CheckCircle, XCircle, Clock, Truck, FileText } from 'lucide-react'

export default function PurchaseOrderDetail() {
  const { id } = useParams<{ id: string }>()
  const { user } = useAuth()
  const [order, setOrder] = useState<PurchaseOrderWithDetails | null>(null)
  const [loading, setLoading] = useState(true)
  const [processing, setProcessing] = useState(false)

  useEffect(() => {
    if (id) fetchOrder()
  }, [id])

  const fetchOrder = async () => {
    if (!id) return
    console.log('Fetching order with id:', id)
    const { data, error } = await purchaseService.getOrderById(id)
    console.log('Order fetch result:', { data, error })
    if (error) {
      console.error('Error fetching order:', error)
      alert('فشل في تحميل أمر الشراء: ' + error.message)
    } else if (data) {
      setOrder(data)
    }
    setLoading(false)
  }

  const handleApprove = async () => {
    if (!id || !user) return
    if (!confirm('هل تريد الموافقة على أمر الشراء؟')) return
    
    setProcessing(true)
    const { error } = await purchaseService.approveOrder(id, user.id)
    if (error) {
      alert('فشل في الموافقة: ' + error.message)
    } else {
      alert('تمت الموافقة بنجاح')
      fetchOrder()
    }
    setProcessing(false)
  }

  const handleReject = async () => {
    if (!id || !user) return
    const reason = prompt('سبب الرفض:')
    if (!reason) return
    
    setProcessing(true)
    const { error } = await purchaseService.rejectOrder(id, user.id, reason)
    if (error) {
      alert('فشل في الرفض: ' + error.message)
    } else {
      alert('تم الرفض')
      fetchOrder()
    }
    setProcessing(false)
  }

  const handleReceive = async () => {
    if (!id || !user) return
    if (!confirm('هل تم استلام البضاعة؟')) return
    
    setProcessing(true)
    const { error } = await purchaseService.receiveOrder(id, user.id)
    if (error) {
      alert('فشل في تسجيل الاستلام: ' + error.message)
    } else {
      alert('تم تسجيل الاستلام بنجاح')
      fetchOrder()
    }
    setProcessing(false)
  }

  const getStatusBadge = (status: string) => {
    const config: Record<string, { bg: string; text: string; icon: typeof Clock; label: string }> = {
      draft: { bg: 'bg-gray-100', text: 'text-gray-800', icon: FileText, label: 'مسودة' },
      pending: { bg: 'bg-yellow-100', text: 'text-yellow-800', icon: Clock, label: 'في انتظار الموافقة' },
      approved: { bg: 'bg-blue-100', text: 'text-blue-800', icon: CheckCircle, label: 'موافق عليه' },
      sent: { bg: 'bg-purple-100', text: 'text-purple-800', icon: Truck, label: 'تم الإرسال للمورد' },
      received: { bg: 'bg-green-100', text: 'text-green-800', icon: Package, label: 'تم الاستلام' },
      rejected: { bg: 'bg-red-100', text: 'text-red-800', icon: XCircle, label: 'مرفوض' },
      cancelled: { bg: 'bg-gray-100', text: 'text-gray-800', icon: XCircle, label: 'ملغي' },
    }
    const c = config[status] || config.pending
    const Icon = c.icon
    return (
      <span className={`inline-flex items-center gap-1 px-3 py-1 rounded-full text-sm font-medium ${c.bg} ${c.text}`}>
        <Icon className="w-4 h-4" />
        {c.label}
      </span>
    )
  }

  if (loading) {
    return (
      <div className="flex items-center justify-center h-64">
        <div className="w-8 h-8 border-4 border-blue-600 border-t-transparent rounded-full animate-spin" />
      </div>
    )
  }

  if (!order) {
    return (
      <div className="text-center py-12">
        <p className="text-gray-500">أمر الشراء غير موجود</p>
        <Link to="/purchase/orders" className="text-blue-600 hover:underline mt-2 inline-block">
          العودة للقائمة
        </Link>
      </div>
    )
  }

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-4">
          <Link to="/purchase/orders" className="p-2 hover:bg-gray-100 rounded-lg">
            <ArrowRight className="w-5 h-5" />
          </Link>
          <div>
            <h1 className="text-2xl font-bold text-gray-900">أمر شراء #{order.order_number}</h1>
            <p className="text-gray-600">تفاصيل أمر الشراء</p>
          </div>
        </div>
        {getStatusBadge(order.status)}
      </div>

      {/* Order Info */}
      <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
        <div className="bg-white rounded-lg shadow-sm border border-gray-100 p-6">
          <h3 className="text-lg font-semibold text-gray-900 mb-4">معلومات الأمر</h3>
          <div className="space-y-3">
            <div className="flex justify-between">
              <span className="text-gray-500">رقم الأمر</span>
              <span className="font-medium">{order.order_number}</span>
            </div>
            <div className="flex justify-between">
              <span className="text-gray-500">تاريخ الأمر</span>
              <span className="font-medium">{formatDate(order.order_date)}</span>
            </div>
            <div className="flex justify-between">
              <span className="text-gray-500">المورد</span>
              <span className="font-medium">{order.supplier?.name_ar || '-'}</span>
            </div>
            <div className="flex justify-between">
              <span className="text-gray-500">الفرع</span>
              <span className="font-medium">{order.branch?.name_ar || '-'}</span>
            </div>
            <div className="flex justify-between">
              <span className="text-gray-500">تاريخ التسليم المتوقع</span>
              <span className="font-medium">{order.expected_delivery_date ? formatDate(order.expected_delivery_date) : '-'}</span>
            </div>
          </div>
        </div>

        <div className="bg-white rounded-lg shadow-sm border border-gray-100 p-6">
          <h3 className="text-lg font-semibold text-gray-900 mb-4">ملخص مالي</h3>
          <div className="space-y-3">
            <div className="flex justify-between">
              <span className="text-gray-500">عدد الأصناف</span>
              <span className="font-medium">{formatNumber(order.items?.length || 0)}</span>
            </div>
            <div className="flex justify-between">
              <span className="text-gray-500">إجمالي الكمية</span>
              <span className="font-medium">{formatNumber(order.items?.reduce((sum, i) => sum + (i.quantity || 0), 0) || 0)}</span>
            </div>
            <div className="flex justify-between text-lg font-bold pt-2 border-t">
              <span>الإجمالي</span>
              <span className="text-blue-600">{formatCurrency(order.total_amount || 0)}</span>
            </div>
          </div>
        </div>
      </div>

      {/* Items Table */}
      <div className="bg-white rounded-lg shadow-sm border border-gray-100 overflow-hidden">
        <div className="p-4 border-b border-gray-100">
          <h3 className="text-lg font-semibold text-gray-900">الأصناف</h3>
        </div>
        <div className="overflow-x-auto">
          <table className="w-full">
            <thead className="bg-gray-50">
              <tr>
                <th className="px-4 py-3 text-right text-sm font-medium text-gray-700">الصنف</th>
                <th className="px-4 py-3 text-right text-sm font-medium text-gray-700">الكمية</th>
                <th className="px-4 py-3 text-right text-sm font-medium text-gray-700">سعر الوحدة</th>
                <th className="px-4 py-3 text-right text-sm font-medium text-gray-700">الإجمالي</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-100">
              {order.items?.map((item, index) => (
                <tr key={item.id || index} className={index % 2 === 0 ? 'bg-white' : 'bg-gray-50'}>
                  <td className="px-4 py-3">
                    <div>
                      <p className="font-medium text-gray-900">{item.item?.name_ar || '-'}</p>
                      <p className="text-sm text-gray-500">{item.item?.code || '-'}</p>
                    </div>
                  </td>
                  <td className="px-4 py-3">{formatNumber(item.quantity)}</td>
                  <td className="px-4 py-3">{formatCurrency(item.unit_price || 0)}</td>
                  <td className="px-4 py-3 font-medium">{formatCurrency(item.total_price || (item.quantity * (item.unit_price || 0)))}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>

      {/* Notes */}
      {order.notes && (
        <div className="bg-white rounded-lg shadow-sm border border-gray-100 p-6">
          <h3 className="text-lg font-semibold text-gray-900 mb-2">ملاحظات</h3>
          <p className="text-gray-600">{order.notes}</p>
        </div>
      )}

      {/* Actions */}
      <div className="flex gap-3 justify-end">
        {order.status === 'pending' && (
          <>
            <button
              type="button"
              onClick={handleReject}
              disabled={processing}
              className="px-6 py-2 bg-red-600 text-white rounded-lg hover:bg-red-700 disabled:opacity-50"
            >
              رفض
            </button>
            <button
              type="button"
              onClick={handleApprove}
              disabled={processing}
              className="px-6 py-2 bg-green-600 text-white rounded-lg hover:bg-green-700 disabled:opacity-50"
            >
              موافقة
            </button>
          </>
        )}
        {(order.status === 'approved' || order.status === 'sent') && (
          <button
            type="button"
            onClick={handleReceive}
            disabled={processing}
            className="px-6 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 disabled:opacity-50"
          >
            تأكيد الاستلام
          </button>
        )}
      </div>
    </div>
  )
}
