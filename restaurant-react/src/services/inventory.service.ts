import { supabase, fixEncodingInData } from '../lib/supabase'
import { Item, Inventory, Category, ItemStatus } from '../types/database.types'

export interface CreateItemData {
  code: string
  name: string
  name_ar: string
  description?: string
  unit: string // This is unit_id (UUID)
  category_id?: string
  min_stock_level: number
  max_stock_level?: number
  reorder_point?: number
  purchase_price?: number
  selling_price?: number
  status?: ItemStatus
  is_menu_item?: boolean
  image_url?: string
}

export interface Unit {
  id: string
  code: string
  name_ar: string
  name?: string
}

export interface InventoryWithDetails extends Omit<Inventory, 'branch' | 'item'> {
  item: Item
  branch: { id: string; name_ar: string; code: string }
}

export const inventoryService = {
  // Items CRUD
  async getAllItems() {
    const { data, error } = await supabase
      .from('items')
      .select('*, category:categories(name_ar), unit:units(id, name_ar, code)')
      .order('name_ar')

    return { data: fixEncodingInData(data) as Item[], error }
  },

  // Search item by barcode or code
  async getItemByBarcode(barcode: string) {
    // First try barcode
    let { data, error } = await supabase
      .from('items')
      .select('*, category:categories(name_ar), unit:units(id, name_ar, code)')
      .eq('barcode', barcode)
      .single()

    // If not found, try code
    if (!data) {
      const result = await supabase
        .from('items')
        .select('*, category:categories(name_ar), unit:units(id, name_ar, code)')
        .eq('code', barcode)
        .single()
      data = result.data
      error = result.error
    }

    return { data: fixEncodingInData(data) as Item, error }
  },

  async getItemById(id: string) {
    const { data, error } = await supabase
      .from('items')
      .select('*, category:categories(name_ar)')
      .eq('id', id)
      .single()

    return { data: fixEncodingInData(data) as Item, error }
  },

  async createItem(itemData: CreateItemData) {
    // Map 'unit' to 'unit_id' for database
    const dbData = {
      ...itemData,
      unit_id: itemData.unit,
    }
    // Remove 'unit' as it's not a column
    delete (dbData as Record<string, unknown>).unit
    
    const { data, error } = await supabase
      .from('items')
      .insert(dbData)
      .select()
      .single()

    return { data: data as Item, error }
  },

  async updateItem(id: string, itemData: Partial<CreateItemData>) {
    const { data, error } = await supabase
      .from('items')
      .update({ ...itemData, updated_at: new Date().toISOString() })
      .eq('id', id)
      .select()
      .single()

    return { data: data as Item, error }
  },

  async deleteItem(id: string) {
    const { error } = await supabase
      .from('items')
      .delete()
      .eq('id', id)

    return { error }
  },

  // Categories
  async getCategories() {
    const { data, error } = await supabase
      .from('categories')
      .select('*')
      .eq('is_active', true)
      .order('sort_order')

    return { data: fixEncodingInData(data) as Category[], error }
  },

  // Inventory/Stock
  async getStock(branchId?: string) {
    let query = supabase
      .from('inventory')
      .select('*, item:items(id, code, name_ar, min_stock_level, category_id, purchase_price, selling_price, unit:units(id, name_ar, code), category:categories(id, name_ar)), branch:branches(id, name_ar, code)')
      .order('quantity', { ascending: true })

    if (branchId) {
      query = query.eq('branch_id', branchId)
    }

    const { data, error } = await query
    return { data: fixEncodingInData(data) as InventoryWithDetails[], error }
  },

  async getStockByBranch(branchId: string) {
    const { data, error } = await supabase
      .from('inventory')
      .select('*, item:items(id, code, name_ar, min_stock_level, category_id, purchase_price, selling_price, unit:units(id, name_ar, code), category:categories(id, name_ar))')
      .eq('branch_id', branchId)
      .order('created_at', { ascending: false })

    return { data: fixEncodingInData(data) as InventoryWithDetails[], error }
  },

  async getLowStock(threshold?: number) {
    const { data, error } = await supabase
      .from('inventory')
      .select('*, item:items(id, code, name_ar, unit, min_stock_level), branch:branches(id, name_ar, code)')
      .lt('quantity', threshold || 10)
      .order('quantity', { ascending: true })

    return { data: fixEncodingInData(data) as InventoryWithDetails[], error }
  },

  async updateStock(branchId: string, itemId: string, quantity: number) {
    // Check if inventory record exists
    const { data: existing } = await supabase
      .from('inventory')
      .select('id, quantity')
      .eq('branch_id', branchId)
      .eq('item_id', itemId)
      .single()

    if (existing) {
      // Update existing
      const { data, error } = await supabase
        .from('inventory')
        .update({ quantity, updated_at: new Date().toISOString() })
        .eq('id', existing.id)
        .select()
        .single()

      return { data: data as Inventory, error }
    } else {
      // Create new
      const { data, error } = await supabase
        .from('inventory')
        .insert({ branch_id: branchId, item_id: itemId, quantity, min_quantity: 0 })
        .select()
        .single()

      return { data: data as Inventory, error }
    }
  },

  async adjustStock(branchId: string, itemId: string, adjustment: number, reason?: string) {
    // Get current quantity
    const { data: current } = await supabase
      .from('inventory')
      .select('id, quantity')
      .eq('branch_id', branchId)
      .eq('item_id', itemId)
      .single()

    const currentQty = current?.quantity || 0
    const newQty = currentQty + adjustment

    // Update inventory
    const result = await this.updateStock(branchId, itemId, newQty)

    // Log transaction
    if (!result.error) {
      await supabase.from('inventory_transactions').insert({
        branch_id: branchId,
        item_id: itemId,
        transaction_type: adjustment > 0 ? 'in' : 'out',
        quantity: Math.abs(adjustment),
        previous_quantity: currentQty,
        new_quantity: newQty,
        reason,
      })
    }

    return result
  },

  // Check if item code exists
  async itemCodeExists(code: string, excludeId?: string) {
    let query = supabase
      .from('items')
      .select('id')
      .eq('code', code)

    if (excludeId) {
      query = query.neq('id', excludeId)
    }

    const { data, error } = await query
    return { exists: data && data.length > 0, error }
  },

  // Get all units
  async getUnits() {
    const { data, error } = await supabase
      .from('units')
      .select('id, code, name_ar, name')
      .order('name_ar')

    return { data: fixEncodingInData(data) as Unit[], error }
  },

  // Delete all inventory for a branch (for import replace)
  async clearBranchInventory(branchId: string) {
    const { error } = await supabase
      .from('inventory')
      .delete()
      .eq('branch_id', branchId)

    return { error }
  },

  // Delete all items (for full import replace)
  async clearAllItems() {
    // First delete all inventory
    await supabase.from('inventory').delete().neq('id', '00000000-0000-0000-0000-000000000000')
    // Then delete all items
    const { error } = await supabase
      .from('items')
      .delete()
      .neq('id', '00000000-0000-0000-0000-000000000000')

    return { error }
  },
}
