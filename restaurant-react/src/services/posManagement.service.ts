import { supabase, fixEncodingInData } from '../lib/supabase'

export interface BranchMenuPrice {
  id: string
  branch_id: string
  menu_item_id: string
  price: number
  is_available: boolean
  created_at: string
  updated_at: string
  menu_item?: {
    id: string
    code: string
    name: string
    name_ar: string
    price: number
    is_available: boolean
    category?: {
      id: string
      name: string
      name_ar: string
    }
  }
  branch?: {
    id: string
    code: string
    name: string
    name_ar: string
  }
}

export interface BranchPriceUpdate {
  branch_id: string
  menu_item_id: string
  price: number
  is_available: boolean
}

export const posManagementService = {
  // Get all branch menu prices for a specific branch
  async getBranchPrices(branchId: string) {
    const { data, error } = await supabase
      .from('branch_menu_prices')
      .select(`
        *,
        menu_item:menu_items(id, code, name, name_ar, price, is_available, category:menu_categories(id, name, name_ar))
      `)
      .eq('branch_id', branchId)
      .order('created_at')

    return { data: fixEncodingInData(data) as BranchMenuPrice[], error }
  },

  // Get all branches with their price counts
  async getBranchesWithPriceCounts() {
    const { data: branches, error: branchError } = await supabase
      .from('branches')
      .select('id, code, name, name_ar, is_main_warehouse, status')
      .eq('is_main_warehouse', false)
      .eq('status', 'active')
      .order('name')

    if (branchError) return { data: null, error: branchError }

    // Get price counts for each branch
    const { data: priceCounts, error: countError } = await supabase
      .from('branch_menu_prices')
      .select('branch_id')

    if (countError) return { data: branches, error: null }

    const counts = priceCounts?.reduce((acc, item) => {
      acc[item.branch_id] = (acc[item.branch_id] || 0) + 1
      return acc
    }, {} as Record<string, number>)

    const branchesWithCounts = branches?.map(branch => ({
      ...branch,
      priceCount: counts?.[branch.id] || 0
    }))

    return { data: fixEncodingInData(branchesWithCounts), error: null }
  },

  // Update a single branch menu price
  async updateBranchPrice(id: string, updates: { price?: number; is_available?: boolean }) {
    const { data, error } = await supabase
      .from('branch_menu_prices')
      .update({
        ...updates,
        updated_at: new Date().toISOString()
      })
      .eq('id', id)
      .select()
      .single()

    return { data, error }
  },

  // Bulk update prices for a branch
  async bulkUpdatePrices(branchId: string, updates: { menu_item_id: string; price: number; is_available: boolean }[]) {
    const results = []
    
    for (const update of updates) {
      const { data, error } = await supabase
        .from('branch_menu_prices')
        .upsert({
          branch_id: branchId,
          menu_item_id: update.menu_item_id,
          price: update.price,
          is_available: update.is_available,
          updated_at: new Date().toISOString()
        }, {
          onConflict: 'branch_id,menu_item_id'
        })
        .select()
        .single()

      results.push({ data, error })
    }

    const hasError = results.some(r => r.error)
    return { success: !hasError, results }
  },

  // Copy prices from one branch to another
  async copyPricesFromBranch(sourceBranchId: string, targetBranchId: string) {
    // Get source prices
    const { data: sourcePrices, error: fetchError } = await supabase
      .from('branch_menu_prices')
      .select('menu_item_id, price, is_available')
      .eq('branch_id', sourceBranchId)

    if (fetchError || !sourcePrices) return { success: false, error: fetchError }

    // Update target prices
    const updates = sourcePrices.map(sp => ({
      menu_item_id: sp.menu_item_id,
      price: sp.price,
      is_available: sp.is_available
    }))

    return await this.bulkUpdatePrices(targetBranchId, updates)
  },

  // Apply percentage change to all prices in a branch
  async applyPercentageChange(branchId: string, percentage: number) {
    const { data: currentPrices, error: fetchError } = await supabase
      .from('branch_menu_prices')
      .select('id, price')
      .eq('branch_id', branchId)

    if (fetchError || !currentPrices) return { success: false, error: fetchError }

    const multiplier = 1 + (percentage / 100)
    
    for (const price of currentPrices) {
      const newPrice = Math.round(price.price * multiplier * 100) / 100
      await supabase
        .from('branch_menu_prices')
        .update({ price: newPrice, updated_at: new Date().toISOString() })
        .eq('id', price.id)
    }

    return { success: true, error: null }
  },

  // Reset branch prices to default (from menu_items)
  async resetToDefaultPrices(branchId: string) {
    const { data: menuItems, error: fetchError } = await supabase
      .from('menu_items')
      .select('id, price, is_available')

    if (fetchError || !menuItems) return { success: false, error: fetchError }

    const updates = menuItems.map(item => ({
      menu_item_id: item.id,
      price: item.price,
      is_available: item.is_available
    }))

    return await this.bulkUpdatePrices(branchId, updates)
  },

  // Get menu items for POS with branch-specific prices
  async getMenuItemsForBranch(branchId: string) {
    const { data, error } = await supabase
      .from('branch_menu_prices')
      .select(`
        price,
        is_available,
        menu_item:menu_items(
          id, code, name, name_ar, image_url, 
          category:menu_categories(id, name, name_ar)
        )
      `)
      .eq('branch_id', branchId)
      .eq('is_available', true)

    if (error) return { data: null, error }

    // Transform data to match MenuItem format
    const menuItems = data?.map(item => ({
      ...item.menu_item,
      price: item.price,
      is_available: item.is_available
    }))

    return { data: fixEncodingInData(menuItems), error: null }
  }
}
