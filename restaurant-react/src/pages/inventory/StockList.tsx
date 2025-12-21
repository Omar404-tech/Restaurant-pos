import { useEffect, useState, useRef } from 'react'
import { Link } from 'react-router-dom'
import { inventoryService, InventoryWithDetails } from '../../services/inventory.service'
import { branchesService } from '../../services/branches.service'
import { Branch } from '../../types/database.types'
import { Package, Search, Filter, Plus, Download, Upload } from 'lucide-react'
import { formatNumber } from '../../lib/utils'
import { exportToExcel, inventoryColumns, parseCSV, readFileAsText } from '../../lib/excel'

export default function StockList() {
  const [stock, setStock] = useState<InventoryWithDetails[]>([])
  const [branches, setBranches] = useState<Branch[]>([])
  const [categories, setCategories] = useState<{ id: string; name_ar: string }[]>([])
  const [loading, setLoading] = useState(true)
  const [selectedBranch, setSelectedBranch] = useState<string>('')
  const [selectedCategory, setSelectedCategory] = useState<string>('')
  const [search, setSearch] = useState('')
  const [isMainWarehouse, setIsMainWarehouse] = useState(true)
  const fileInputRef = useRef<HTMLInputElement>(null)

  useEffect(() => {
    fetchData()
  }, [])

  useEffect(() => {
    fetchStock()
  }, [selectedBranch])

  const fetchData = async () => {
    const [branchesRes, categoriesRes] = await Promise.all([
      branchesService.getActive(),
      inventoryService.getCategories(),
    ])
    const allBranches = branchesRes.data || []
    // Filter out main warehouse from dropdown (it's the default option)
    const nonMainBranches = allBranches.filter(b => !b.is_main_warehouse)
    setBranches(nonMainBranches)
    setCategories(categoriesRes.data || [])
    
    // Get main warehouse ID and fetch its stock
    const mainWarehouse = allBranches.find(b => b.is_main_warehouse)
    if (mainWarehouse) {
      const stockRes = await inventoryService.getStockByBranch(mainWarehouse.id)
      setStock(stockRes.data || [])
    }
    setLoading(false)
  }

  const fetchStock = async () => {
    setLoading(true)
    
    if (selectedBranch) {
      // Fetch selected branch stock
      const { data } = await inventoryService.getStockByBranch(selectedBranch)
      setStock(data || [])
      setIsMainWarehouse(false)
    } else {
      // Fetch main warehouse stock (not all stock)
      const { data: allBranches } = await branchesService.getActive()
      const mainWarehouse = allBranches?.find(b => b.is_main_warehouse)
      if (mainWarehouse) {
        const { data } = await inventoryService.getStockByBranch(mainWarehouse.id)
        setStock(data || [])
      } else {
        setStock([])
      }
      setIsMainWarehouse(true)
    }
    
    setLoading(false)
  }

  const filteredStock = stock.filter((inv) => {
    const item = inv.item as { name_ar?: string; code?: string; category?: { id: string } }
    const matchesSearch =
      item?.name_ar?.includes(search) ||
      item?.code?.toLowerCase().includes(search.toLowerCase())
    const matchesCategory = !selectedCategory || item?.category?.id === selectedCategory
    return matchesSearch && matchesCategory
  })

  // Group by category for display
  const groupedStock = filteredStock.reduce(
    (acc, inv) => {
      const item = inv.item as { category?: { name_ar: string } }
      const categoryName = item?.category?.name_ar || 'بدون تصنيف'
      if (!acc[categoryName]) {
        acc[categoryName] = []
      }
      acc[categoryName].push(inv)
      return acc
    },
    {} as Record<string, InventoryWithDetails[]>
  )

  // Get selected branch name
  const selectedBranchName = selectedBranch 
    ? branches.find(b => b.id === selectedBranch)?.name_ar || 'الفرع'
    : 'المخزن الرئيسي'

  // Format date helper
  const formatDate = (date: string) => {
    const d = new Date(date)
    return `${d.getDate()}/${d.getMonth() + 1}/${d.getFullYear()}`
  }

  // Generate document number
  const getDocNumber = (date: string, index: number) => {
    const d = new Date(date)
    return `${d.getDate()}/${d.getMonth() + 1}/${d.getFullYear()}-${String(index + 1).padStart(2, '0')}`
  }

  // Export to Excel
  const handleExport = () => {
    const exportData = filteredStock.map(inv => {
      const item = inv.item as { code?: string; name_ar?: string; unit?: { name_ar?: string; code?: string } | string }
      const branch = inv.branch as { name_ar?: string }
      // Handle unit as object or string
      const unitValue = typeof item?.unit === 'object' 
        ? (item?.unit?.name_ar || item?.unit?.code || '') 
        : (item?.unit || '')
      return {
        item_code: item?.code || '',
        item_name: item?.name_ar || '',
        branch_name: branch?.name_ar || selectedBranchName,
        quantity: inv.quantity || 0,
        unit: unitValue,
        min_quantity: inv.min_quantity || 0,
      }
    })
    exportToExcel(exportData, inventoryColumns, `مخزون_${selectedBranchName}`)
  }

  // Import from Excel
  const handleImport = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0]
    if (!file) return
    
    // Confirm before replacing data
    if (!confirm('سيتم حذف بيانات المخزون الحالية واستبدالها بالبيانات الجديدة. هل تريد المتابعة؟')) {
      return
    }
    
    try {
      setLoading(true)
      const text = await readFileAsText(file)
      const data = parseCSV(text)
      console.log('Imported data:', data)
      
      if (data.length === 0) {
        alert('الملف فارغ أو غير صالح')
        setLoading(false)
        return
      }
      
      // Get target branch (selected or main warehouse)
      let targetBranchId = selectedBranch
      if (!targetBranchId) {
        const { data: allBranches } = await branchesService.getActive()
        const mainWarehouse = allBranches?.find(b => b.is_main_warehouse)
        targetBranchId = mainWarehouse?.id || ''
      }
      if (!targetBranchId) {
        alert('يرجى اختيار الفرع أولاً')
        setLoading(false)
        return
      }
      
      // Clear old inventory for this branch first
      console.log('Clearing old inventory for branch:', targetBranchId)
      const { error: clearError } = await inventoryService.clearBranchInventory(targetBranchId)
      if (clearError) {
        console.error('Failed to clear inventory:', clearError)
        alert('فشل في مسح البيانات القديمة: ' + clearError.message)
        setLoading(false)
        return
      }
      
      // Get all items to match by code
      const { data: allItems } = await inventoryService.getAllItems()
      const itemMap = new Map((allItems || []).map(i => [i.code?.toLowerCase(), i]))
      
      // Get units for mapping
      const { data: units } = await inventoryService.getUnits()
      const defaultUnit = units?.find(u => u.code === 'PC' || u.code === 'KG') || units?.[0]
      
      let successCount = 0
      let newItemsCount = 0
      let errorCount = 0
      const errors: string[] = []
      
      console.log('CSV Headers:', Object.keys(data[0] || {}))
      console.log('Default unit:', defaultUnit)
      
      for (const row of data) {
        // Get item data from CSV
        const itemCode = (row['كود الصنف'] || row['item_code'] || row['كود'] || '').toString().trim()
        const itemName = (row['اسم الصنف'] || row['item_name'] || row['الاسم'] || '').toString().trim()
        const quantity = parseFloat(row['الكمية'] || row['quantity'] || row['الرصيد إجمالي'] || '0')
        // Handle unit - could be string or [object Object] from bad export
        let unitRaw = row['الوحدة'] || row['unit'] || row['وصف المحتوى'] || ''
        const unitName = (typeof unitRaw === 'object' ? '' : unitRaw.toString()).trim()
        
        console.log('Processing row:', { itemCode, itemName, quantity, unitName, row })
        
        if (!itemCode) {
          errorCount++
          errors.push(`سطر بدون كود صنف`)
          continue
        }
        
        let item = itemMap.get(itemCode.toLowerCase())
        
        // If item doesn't exist, create it
        if (!item) {
          // Find matching unit or use default
          const matchedUnit = units?.find(u => 
            u.name_ar === unitName || 
            u.code?.toLowerCase() === unitName.toLowerCase()
          ) || defaultUnit
          
          if (!matchedUnit) {
            errorCount++
            errors.push(`لا توجد وحدة قياس للصنف ${itemCode}`)
            continue
          }
          
          console.log(`Creating new item: ${itemCode} - ${itemName || itemCode}, unit: ${matchedUnit.code}`)
          const { data: newItem, error: createError } = await inventoryService.createItem({
            code: itemCode,
            name: itemName || itemCode,
            name_ar: itemName || itemCode,
            unit: matchedUnit.id, // Use unit_id
            min_stock_level: 0,
            status: 'active',
          })
          
          if (createError || !newItem) {
            errorCount++
            errors.push(`فشل إنشاء الصنف ${itemCode}: ${createError?.message || 'خطأ غير معروف'}`)
            console.log(`Failed to create item: ${itemCode}`, createError)
            continue
          }
          
          item = newItem
          itemMap.set(itemCode.toLowerCase(), newItem)
          newItemsCount++
          console.log(`Created new item: ${newItem.code} - ${newItem.name_ar}`)
        }
        
        // Update stock
        const { error: stockError } = await inventoryService.updateStock(targetBranchId, item.id, quantity)
        
        if (stockError) {
          errorCount++
          errors.push(`فشل تحديث مخزون ${itemCode}: ${stockError.message}`)
        } else {
          successCount++
        }
      }
      
      // Show result
      let message = `تم استيراد ${successCount} سجل بنجاح`
      if (newItemsCount > 0) {
        message += `\nتم إنشاء ${newItemsCount} صنف جديد`
      }
      if (errorCount > 0) {
        message += `\nفشل ${errorCount} سجل`
        if (errors.length <= 5) {
          message += `:\n${errors.join('\n')}`
        }
      }
      alert(message)
      
      // Refresh data
      const { data: freshData } = await inventoryService.getStockByBranch(targetBranchId)
      setStock(freshData || [])
      setLoading(false)
      
    } catch (error) {
      console.error('Import error:', error)
      alert('فشل في قراءة الملف')
      setLoading(false)
    }
    
    // Reset input
    if (fileInputRef.current) {
      fileInputRef.current.value = ''
    }
  }

  if (loading) {
    return (
      <div className="flex items-center justify-center h-64">
        <div className="w-8 h-8 border-4 border-blue-600 border-t-transparent rounded-full animate-spin" />
      </div>
    )
  }

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">{selectedBranchName}</h1>
          <p className="text-gray-600">أرصدة المخزون والكميات المتاحة</p>
        </div>
        <div className="flex items-center gap-2">
          <button
            type="button"
            onClick={handleExport}
            className="flex items-center gap-2 px-4 py-2 bg-green-600 text-white rounded-lg hover:bg-green-700"
            title="تصدير إلى Excel"
          >
            <Download className="w-5 h-5" />
            تصدير
          </button>
          <button
            type="button"
            onClick={() => fileInputRef.current?.click()}
            className="flex items-center gap-2 px-4 py-2 bg-orange-600 text-white rounded-lg hover:bg-orange-700"
            title="استيراد من Excel"
          >
            <Upload className="w-5 h-5" />
            استيراد
          </button>
          <input
            ref={fileInputRef}
            type="file"
            accept=".csv,.xlsx,.xls"
            onChange={handleImport}
            className="hidden"
            aria-label="استيراد ملف Excel"
          />
          <Link
            to="/inventory/items/new"
            className="flex items-center gap-2 px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700"
          >
            <Plus className="w-5 h-5" />
            إضافة صنف
          </Link>
        </div>
      </div>

      {/* Filters */}
      <div className="bg-white rounded-lg shadow-sm border border-gray-100 p-4">
        <div className="flex items-center gap-2 mb-3">
          <Filter className="w-5 h-5 text-gray-400" />
          <span className="font-medium text-gray-700">تصفية</span>
        </div>
        <div className="flex flex-wrap gap-4">
          <div className="relative flex-1 min-w-[200px]">
            <Search className="absolute right-3 top-1/2 -translate-y-1/2 w-5 h-5 text-gray-400" />
            <input
              type="text"
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              placeholder="بحث بالاسم أو الكود..."
              aria-label="بحث"
              className="w-full pr-10 pl-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
            />
          </div>

          <select
            value={selectedBranch}
            onChange={(e) => setSelectedBranch(e.target.value)}
            aria-label="الفرع"
            className="px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
          >
            <option value="">المخزن الرئيسي</option>
            {branches.map((branch) => (
              <option key={branch.id} value={branch.id}>
                {branch.name_ar}
              </option>
            ))}
          </select>

          <select
            value={selectedCategory}
            onChange={(e) => setSelectedCategory(e.target.value)}
            aria-label="المجموعة"
            className="px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
          >
            <option value="">جميع المجموعات</option>
            {categories.map((cat) => (
              <option key={cat.id} value={cat.id}>
                {cat.name_ar}
              </option>
            ))}
          </select>

          <button
            type="button"
            onClick={() => {
              setSearch('')
              setSelectedBranch('')
              setSelectedCategory('')
            }}
            className="px-4 py-2 text-gray-600 bg-gray-100 rounded-lg hover:bg-gray-200"
          >
            إعادة تعيين
          </button>
        </div>
      </div>

      {/* Stats */}
      <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
        <div className="bg-white rounded-lg shadow-sm p-4 border border-gray-100">
          <p className="text-sm text-gray-500">إجمالي الأصناف</p>
          <p className="text-2xl font-bold text-gray-900">{formatNumber(filteredStock.length)}</p>
        </div>
        <div className="bg-white rounded-lg shadow-sm p-4 border border-gray-100">
          <p className="text-sm text-gray-500">إجمالي الكمية</p>
          <p className="text-2xl font-bold text-blue-600">
            {formatNumber(filteredStock.reduce((sum, i) => sum + (i.quantity || 0), 0))}
          </p>
        </div>
        <div className="bg-white rounded-lg shadow-sm p-4 border border-gray-100">
          <p className="text-sm text-gray-500">عدد المجموعات</p>
          <p className="text-2xl font-bold text-green-600">{formatNumber(Object.keys(groupedStock).length)}</p>
        </div>
        <div className="bg-white rounded-lg shadow-sm p-4 border border-gray-100">
          <p className="text-sm text-gray-500">مخزون منخفض</p>
          <p className="text-2xl font-bold text-red-600">
            {formatNumber(filteredStock.filter((i) => i.quantity < (i.item?.min_stock_level || 10)).length)}
          </p>
        </div>
      </div>

      {/* Stock Table */}
      <div className="bg-white rounded-lg shadow-sm border border-gray-100 overflow-hidden">
        {filteredStock.length === 0 ? (
          <div className="text-center py-12">
            <Package className="w-12 h-12 text-gray-300 mx-auto mb-4" />
            <p className="text-gray-500">لا توجد بيانات</p>
          </div>
        ) : isMainWarehouse || !selectedBranch ? (
          /* Main Warehouse Table - Blue Header */
          <div className="overflow-x-auto">
            <table className="w-full">
              <thead className="bg-blue-100">
                <tr>
                  <th className="px-4 py-3 text-right text-sm font-medium text-gray-700">م</th>
                  <th className="px-4 py-3 text-right text-sm font-medium text-gray-700">مجموعة</th>
                  <th className="px-4 py-3 text-right text-sm font-medium text-gray-700">كود</th>
                  <th className="px-4 py-3 text-right text-sm font-medium text-gray-700">اسم الصنف</th>
                  <th className="px-4 py-3 text-right text-sm font-medium text-gray-700">رصيد أول المدة</th>
                  <th className="px-4 py-3 text-right text-sm font-medium text-gray-700">الوارد</th>
                  <th className="px-4 py-3 text-right text-sm font-medium text-gray-700">المحتوى بالكمية</th>
                  <th className="px-4 py-3 text-right text-sm font-medium text-gray-700">الرصيد إجمالي</th>
                  <th className="px-4 py-3 text-right text-sm font-medium text-gray-700">وصف المحتوى</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-100">
                {filteredStock.map((inv, index) => {
                  const item = inv.item as unknown as { code?: string; name_ar?: string; category?: { name_ar: string }; unit?: { name_ar: string; code: string } }
                  const categoryName = item?.category?.name_ar || '-'
                  const unitName = item?.unit?.name_ar || item?.unit?.code || 'كرتونة'
                  return (
                    <tr key={inv.id} className={index % 2 === 0 ? 'bg-white' : 'bg-gray-50'}>
                      <td className="px-4 py-3 text-gray-900">{index + 1}</td>
                      <td className="px-4 py-3 text-gray-600">{categoryName}</td>
                      <td className="px-4 py-3 text-gray-900 font-mono">{item?.code || '-'}</td>
                      <td className="px-4 py-3 text-gray-900">{item?.name_ar || '-'}</td>
                      <td className="px-4 py-3 text-gray-600">{formatNumber(inv.min_quantity || 0)}</td>
                      <td className="px-4 py-3 text-gray-600">-</td>
                      <td className="px-4 py-3 text-gray-600">-</td>
                      <td className="px-4 py-3 text-gray-900 font-medium">{formatNumber(inv.quantity)}</td>
                      <td className="px-4 py-3 text-gray-500 text-sm">{unitName}</td>
                    </tr>
                  )
                })}
              </tbody>
            </table>
          </div>
        ) : (
          /* Branch Table - Red Header with Date & Document Number */
          <div className="overflow-x-auto">
            <table className="w-full">
              <thead className="bg-red-100">
                <tr>
                  <th className="px-4 py-3 text-right text-sm font-medium text-gray-700">م</th>
                  <th className="px-4 py-3 text-right text-sm font-medium text-gray-700">التاريخ</th>
                  <th className="px-4 py-3 text-right text-sm font-medium text-gray-700">رقم المستند</th>
                  <th className="px-4 py-3 text-right text-sm font-medium text-gray-700">كود الصنف</th>
                  <th className="px-4 py-3 text-right text-sm font-medium text-gray-700">اسم الصنف</th>
                  <th className="px-4 py-3 text-right text-sm font-medium text-gray-700">جزئي</th>
                  <th className="px-4 py-3 text-right text-sm font-medium text-gray-700">المحتوى</th>
                  <th className="px-4 py-3 text-right text-sm font-medium text-gray-700">كلي</th>
                  <th className="px-4 py-3 text-right text-sm font-medium text-gray-700">وصف المحتوى</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-100">
                {filteredStock.map((inv, index) => {
                  const item = inv.item as unknown as { code?: string; name_ar?: string; unit?: { name_ar: string; code: string } }
                  const unitName = item?.unit?.name_ar || item?.unit?.code || 'قطعة'
                  const totalQty = inv.quantity || 0
                  const createdAt = (inv as unknown as { created_at?: string }).created_at || new Date().toISOString()
                  
                  return (
                    <tr key={inv.id} className={index % 2 === 0 ? 'bg-white' : 'bg-gray-50'}>
                      <td className="px-4 py-3 text-gray-900">{index + 1}</td>
                      <td className="px-4 py-3 text-gray-600">{formatDate(createdAt)}</td>
                      <td className="px-4 py-3 text-gray-900 font-mono">{getDocNumber(createdAt, index)}</td>
                      <td className="px-4 py-3 text-gray-900 font-mono">{item?.code || '-'}</td>
                      <td className="px-4 py-3 text-gray-900">{item?.name_ar || '-'}</td>
                      <td className="px-4 py-3 text-gray-600">{formatNumber(Math.floor(totalQty))}</td>
                      <td className="px-4 py-3 text-gray-600">1</td>
                      <td className="px-4 py-3 text-gray-900 font-medium">{formatNumber(totalQty)}</td>
                      <td className="px-4 py-3 text-gray-500 text-sm">{unitName}</td>
                    </tr>
                  )
                })}
              </tbody>
            </table>
          </div>
        )}
      </div>
    </div>
  )
}
