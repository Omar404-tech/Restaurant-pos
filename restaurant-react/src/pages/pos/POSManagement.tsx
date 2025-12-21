import { useEffect, useState } from 'react'
import { posManagementService, BranchMenuPrice } from '../../services/posManagement.service'
import { formatCurrency } from '../../lib/utils'
import { 
  Store, DollarSign, Save, RotateCcw, Copy, Percent, 
  Check, X, Eye, EyeOff, Search
} from 'lucide-react'

interface Branch {
  id: string
  code: string
  name: string
  name_ar: string
  priceCount: number
}

export default function POSManagement() {
  const [branches, setBranches] = useState<Branch[]>([])
  const [selectedBranch, setSelectedBranch] = useState<string | null>(null)
  const [prices, setPrices] = useState<BranchMenuPrice[]>([])
  const [loading, setLoading] = useState(true)
  const [saving, setSaving] = useState(false)
  const [searchTerm, setSearchTerm] = useState('')
  const [editedPrices, setEditedPrices] = useState<Record<string, { price: number; is_available: boolean }>>({})
  const [showCopyModal, setShowCopyModal] = useState(false)
  const [showPercentModal, setShowPercentModal] = useState(false)
  const [percentValue, setPercentValue] = useState<string>('')
  const [copySourceBranch, setCopySourceBranch] = useState<string>('')

  useEffect(() => {
    fetchBranches()
  }, [])

  useEffect(() => {
    if (selectedBranch) {
      fetchPrices(selectedBranch)
    }
  }, [selectedBranch])

  const fetchBranches = async () => {
    const { data } = await posManagementService.getBranchesWithPriceCounts()
    setBranches((data || []) as unknown as Branch[])
    setLoading(false)
  }

  const fetchPrices = async (branchId: string) => {
    setLoading(true)
    const { data } = await posManagementService.getBranchPrices(branchId)
    setPrices(data || [])
    setEditedPrices({})
    setLoading(false)
  }

  const handlePriceChange = (id: string, field: 'price' | 'is_available', value: number | boolean) => {
    const current = prices.find(p => p.id === id)
    if (!current) return

    setEditedPrices(prev => ({
      ...prev,
      [id]: {
        price: field === 'price' ? value as number : (prev[id]?.price ?? current.price),
        is_available: field === 'is_available' ? value as boolean : (prev[id]?.is_available ?? current.is_available)
      }
    }))
  }

  const hasChanges = Object.keys(editedPrices).length > 0

  const handleSave = async () => {
    if (!selectedBranch || !hasChanges) return
    
    setSaving(true)
    
    for (const [id, updates] of Object.entries(editedPrices)) {
      await posManagementService.updateBranchPrice(id, updates)
    }
    
    await fetchPrices(selectedBranch)
    setSaving(false)
  }

  const handleResetToDefault = async () => {
    if (!selectedBranch) return
    if (!confirm('هل أنت متأكد من إعادة تعيين جميع الأسعار للقيم الافتراضية؟')) return
    
    setSaving(true)
    await posManagementService.resetToDefaultPrices(selectedBranch)
    await fetchPrices(selectedBranch)
    setSaving(false)
  }

  const handleCopyPrices = async () => {
    if (!selectedBranch || !copySourceBranch) return
    
    setSaving(true)
    await posManagementService.copyPricesFromBranch(copySourceBranch, selectedBranch)
    await fetchPrices(selectedBranch)
    setShowCopyModal(false)
    setCopySourceBranch('')
    setSaving(false)
  }

  const handleApplyPercent = async () => {
    if (!selectedBranch || !percentValue) return
    
    const percent = parseFloat(percentValue)
    if (isNaN(percent)) return
    
    setSaving(true)
    await posManagementService.applyPercentageChange(selectedBranch, percent)
    await fetchPrices(selectedBranch)
    setShowPercentModal(false)
    setPercentValue('')
    setSaving(false)
  }

  const filteredPrices = prices.filter(p => {
    if (!searchTerm) return true
    const term = searchTerm.toLowerCase()
    return (
      p.menu_item?.name?.toLowerCase().includes(term) ||
      p.menu_item?.name_ar?.toLowerCase().includes(term) ||
      p.menu_item?.code?.toLowerCase().includes(term)
    )
  })

  const selectedBranchData = branches.find(b => b.id === selectedBranch)

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">إدارة نقاط البيع</h1>
          <p className="text-gray-600 mt-1">تحديد أسعار المنتجات لكل فرع</p>
        </div>
      </div>

      {/* Branch Selection */}
      <div className="bg-white rounded-lg shadow-sm border border-gray-200 p-6">
        <h2 className="text-lg font-semibold text-gray-900 mb-4 flex items-center gap-2">
          <Store className="w-5 h-5 text-blue-600" />
          اختر الفرع
        </h2>
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
          {branches.map(branch => (
            <button
              key={branch.id}
              onClick={() => setSelectedBranch(branch.id)}
              className={`p-4 rounded-lg border-2 text-right transition-all ${
                selectedBranch === branch.id
                  ? 'border-blue-600 bg-blue-50'
                  : 'border-gray-200 hover:border-blue-300 hover:bg-gray-50'
              }`}
            >
              <div className="flex items-center justify-between">
                <span className={`px-2 py-1 rounded text-xs font-medium ${
                  selectedBranch === branch.id ? 'bg-blue-600 text-white' : 'bg-gray-100 text-gray-600'
                }`}>
                  {branch.code}
                </span>
                {selectedBranch === branch.id && (
                  <Check className="w-5 h-5 text-blue-600" />
                )}
              </div>
              <h3 className="font-semibold text-gray-900 mt-2">{branch.name_ar || branch.name}</h3>
              <p className="text-sm text-gray-500 mt-1">{branch.priceCount} منتج</p>
            </button>
          ))}
        </div>
      </div>

      {/* Price Management */}
      {selectedBranch && (
        <div className="bg-white rounded-lg shadow-sm border border-gray-200">
          {/* Toolbar */}
          <div className="p-4 border-b border-gray-200">
            <div className="flex flex-wrap items-center justify-between gap-4">
              <div className="flex items-center gap-2">
                <DollarSign className="w-5 h-5 text-green-600" />
                <h2 className="text-lg font-semibold text-gray-900">
                  أسعار {selectedBranchData?.name_ar || selectedBranchData?.name}
                </h2>
              </div>
              
              <div className="flex flex-wrap items-center gap-2">
                {/* Search */}
                <div className="relative">
                  <Search className="absolute right-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400" />
                  <input
                    type="text"
                    placeholder="بحث..."
                    value={searchTerm}
                    onChange={(e) => setSearchTerm(e.target.value)}
                    className="pr-10 pl-4 py-2 border border-gray-300 rounded-lg text-sm w-48"
                  />
                </div>

                {/* Actions */}
                <button
                  onClick={() => setShowPercentModal(true)}
                  className="flex items-center gap-2 px-3 py-2 text-sm bg-purple-50 text-purple-700 rounded-lg hover:bg-purple-100"
                  title="تطبيق نسبة مئوية"
                >
                  <Percent className="w-4 h-4" />
                  نسبة
                </button>
                
                <button
                  onClick={() => setShowCopyModal(true)}
                  className="flex items-center gap-2 px-3 py-2 text-sm bg-orange-50 text-orange-700 rounded-lg hover:bg-orange-100"
                  title="نسخ من فرع آخر"
                >
                  <Copy className="w-4 h-4" />
                  نسخ
                </button>
                
                <button
                  onClick={handleResetToDefault}
                  className="flex items-center gap-2 px-3 py-2 text-sm bg-gray-50 text-gray-700 rounded-lg hover:bg-gray-100"
                  title="إعادة للافتراضي"
                >
                  <RotateCcw className="w-4 h-4" />
                  افتراضي
                </button>

                {hasChanges && (
                  <button
                    onClick={handleSave}
                    disabled={saving}
                    className="flex items-center gap-2 px-4 py-2 text-sm bg-blue-600 text-white rounded-lg hover:bg-blue-700 disabled:opacity-50"
                  >
                    {saving ? (
                      <span className="w-4 h-4 border-2 border-white border-t-transparent rounded-full animate-spin" />
                    ) : (
                      <Save className="w-4 h-4" />
                    )}
                    حفظ التغييرات
                  </button>
                )}
              </div>
            </div>
          </div>

          {/* Price Table */}
          <div className="overflow-x-auto">
            <table className="w-full">
              <thead className="bg-gray-50">
                <tr>
                  <th className="px-4 py-3 text-right text-sm font-medium text-gray-600">الكود</th>
                  <th className="px-4 py-3 text-right text-sm font-medium text-gray-600">المنتج</th>
                  <th className="px-4 py-3 text-right text-sm font-medium text-gray-600">التصنيف</th>
                  <th className="px-4 py-3 text-right text-sm font-medium text-gray-600">السعر الافتراضي</th>
                  <th className="px-4 py-3 text-right text-sm font-medium text-gray-600">سعر الفرع</th>
                  <th className="px-4 py-3 text-center text-sm font-medium text-gray-600">متاح</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-200">
                {loading ? (
                  <tr>
                    <td colSpan={6} className="px-4 py-8 text-center">
                      <div className="w-8 h-8 border-4 border-blue-600 border-t-transparent rounded-full animate-spin mx-auto" />
                    </td>
                  </tr>
                ) : filteredPrices.length === 0 ? (
                  <tr>
                    <td colSpan={6} className="px-4 py-8 text-center text-gray-500">
                      لا توجد منتجات
                    </td>
                  </tr>
                ) : (
                  filteredPrices.map(item => {
                    const edited = editedPrices[item.id]
                    const currentPrice = edited?.price ?? item.price
                    const currentAvailable = edited?.is_available ?? item.is_available
                    const defaultPrice = item.menu_item?.price || 0
                    const priceDiff = currentPrice - defaultPrice
                    
                    return (
                      <tr key={item.id} className={edited ? 'bg-yellow-50' : ''}>
                        <td className="px-4 py-3">
                          <span className="text-sm font-mono text-gray-600">
                            {item.menu_item?.code}
                          </span>
                        </td>
                        <td className="px-4 py-3">
                          <div>
                            <p className="font-medium text-gray-900">{item.menu_item?.name_ar}</p>
                            <p className="text-sm text-gray-500">{item.menu_item?.name}</p>
                          </div>
                        </td>
                        <td className="px-4 py-3">
                          <span className="px-2 py-1 bg-gray-100 text-gray-700 rounded text-sm">
                            {item.menu_item?.category?.name_ar || '-'}
                          </span>
                        </td>
                        <td className="px-4 py-3">
                          <span className="text-gray-600">{formatCurrency(defaultPrice)}</span>
                        </td>
                        <td className="px-4 py-3">
                          <div className="flex items-center gap-2">
                            <input
                              type="number"
                              value={currentPrice}
                              onChange={(e) => handlePriceChange(item.id, 'price', parseFloat(e.target.value) || 0)}
                              className="w-24 px-3 py-1.5 border border-gray-300 rounded-lg text-sm focus:ring-2 focus:ring-blue-500"
                              min="0"
                              step="0.01"
                              aria-label={`سعر ${item.menu_item?.name_ar}`}
                            />
                            {priceDiff !== 0 && (
                              <span className={`text-xs font-medium ${priceDiff > 0 ? 'text-green-600' : 'text-red-600'}`}>
                                {priceDiff > 0 ? '+' : ''}{priceDiff.toFixed(2)}
                              </span>
                            )}
                          </div>
                        </td>
                        <td className="px-4 py-3 text-center">
                          <button
                            onClick={() => handlePriceChange(item.id, 'is_available', !currentAvailable)}
                            className={`p-2 rounded-lg transition-colors ${
                              currentAvailable 
                                ? 'bg-green-100 text-green-700 hover:bg-green-200' 
                                : 'bg-red-100 text-red-700 hover:bg-red-200'
                            }`}
                            title={currentAvailable ? 'متاح - اضغط للإخفاء' : 'غير متاح - اضغط للإظهار'}
                          >
                            {currentAvailable ? <Eye className="w-4 h-4" /> : <EyeOff className="w-4 h-4" />}
                          </button>
                        </td>
                      </tr>
                    )
                  })
                )}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {/* Copy Modal */}
      {showCopyModal && (
        <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50">
          <div className="bg-white rounded-lg p-6 w-full max-w-md">
            <div className="flex items-center justify-between mb-4">
              <h3 className="text-lg font-bold text-gray-900">نسخ الأسعار من فرع آخر</h3>
              <button onClick={() => setShowCopyModal(false)} className="p-2 hover:bg-gray-100 rounded-lg" title="إغلاق">
                <X className="w-5 h-5" />
              </button>
            </div>
            <p className="text-gray-600 mb-4">اختر الفرع المصدر لنسخ أسعاره إلى الفرع الحالي</p>
            <select
              value={copySourceBranch}
              onChange={(e) => setCopySourceBranch(e.target.value)}
              className="w-full px-4 py-2 border border-gray-300 rounded-lg mb-4"
              aria-label="اختر الفرع المصدر"
            >
              <option value="">اختر الفرع...</option>
              {branches.filter(b => b.id !== selectedBranch).map(branch => (
                <option key={branch.id} value={branch.id}>
                  {branch.name_ar || branch.name}
                </option>
              ))}
            </select>
            <div className="flex gap-2">
              <button
                onClick={() => setShowCopyModal(false)}
                className="flex-1 px-4 py-2 border border-gray-300 rounded-lg hover:bg-gray-50"
              >
                إلغاء
              </button>
              <button
                onClick={handleCopyPrices}
                disabled={!copySourceBranch || saving}
                className="flex-1 px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 disabled:opacity-50"
              >
                {saving ? 'جاري النسخ...' : 'نسخ الأسعار'}
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Percent Modal */}
      {showPercentModal && (
        <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50">
          <div className="bg-white rounded-lg p-6 w-full max-w-md">
            <div className="flex items-center justify-between mb-4">
              <h3 className="text-lg font-bold text-gray-900">تطبيق نسبة مئوية</h3>
              <button onClick={() => setShowPercentModal(false)} className="p-2 hover:bg-gray-100 rounded-lg" title="إغلاق">
                <X className="w-5 h-5" />
              </button>
            </div>
            <p className="text-gray-600 mb-4">أدخل النسبة المئوية للزيادة أو النقصان (مثال: 10 للزيادة 10%، -5 للنقصان 5%)</p>
            <input
              type="number"
              value={percentValue}
              onChange={(e) => setPercentValue(e.target.value)}
              placeholder="مثال: 10 أو -5"
              className="w-full px-4 py-2 border border-gray-300 rounded-lg mb-4"
              aria-label="النسبة المئوية"
            />
            <div className="flex gap-2">
              <button
                onClick={() => setShowPercentModal(false)}
                className="flex-1 px-4 py-2 border border-gray-300 rounded-lg hover:bg-gray-50"
              >
                إلغاء
              </button>
              <button
                onClick={handleApplyPercent}
                disabled={!percentValue || saving}
                className="flex-1 px-4 py-2 bg-purple-600 text-white rounded-lg hover:bg-purple-700 disabled:opacity-50"
              >
                {saving ? 'جاري التطبيق...' : 'تطبيق'}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
