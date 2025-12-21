import { supabase, fixEncodingInData } from '../lib/supabase'
import { Item, RecipeIngredient, ProductionLog } from '../types/database.types'

export interface RecipeWithIngredients extends Item {
  ingredients: RecipeIngredient[]
}

export interface CreateRecipeData {
  code: string
  name: string
  name_ar: string
  description?: string
  unit_id: string
  category_id: string // Should be Recipe category
  min_stock_level?: number
  purchase_price?: number
  selling_price?: number
  ingredients: {
    ingredient_item_id: string
    quantity: number
    unit_id?: string
    notes?: string
  }[]
}

export interface ProduceRecipeData {
  recipe_item_id: string
  branch_id: string
  quantity: number
  notes?: string
  produced_by: string
}

export const recipeService = {
  // Get all recipes (items with is_recipe = true)
  async getAllRecipes() {
    const { data, error } = await supabase
      .from('items')
      .select('*, category:categories(name_ar), unit:units(id, name_ar, code)')
      .eq('is_recipe', true)
      .order('name_ar')

    return { data: fixEncodingInData(data) as Item[], error }
  },

  // Get recipe with ingredients
  async getRecipeWithIngredients(recipeItemId: string) {
    const [recipeRes, ingredientsRes] = await Promise.all([
      supabase
        .from('items')
        .select('*, category:categories(name_ar), unit:units(id, name_ar, code)')
        .eq('id', recipeItemId)
        .single(),
      supabase
        .from('recipe_ingredients')
        .select(`
          id,
          recipe_item_id,
          ingredient_item_id,
          quantity,
          unit_id,
          notes,
          created_at,
          updated_at,
          ingredient:items!ingredient_item_id(id, code, name_ar, unit_id),
          unit:units(id, name_ar, code)
        `)
        .eq('recipe_item_id', recipeItemId)
    ])

    if (recipeRes.error) return { data: null, error: recipeRes.error }

    const recipe = fixEncodingInData(recipeRes.data) as RecipeWithIngredients
    // Transform the data to match expected format (Supabase returns arrays for single relations)
    const ingredients = (ingredientsRes.data || []).map((ing: Record<string, unknown>) => ({
      ...ing,
      ingredient: Array.isArray(ing.ingredient) ? ing.ingredient[0] : ing.ingredient,
      unit: Array.isArray(ing.unit) ? ing.unit[0] : ing.unit
    }))
    recipe.ingredients = fixEncodingInData(ingredients) as RecipeIngredient[]

    return { data: recipe, error: null }
  },

  // Get recipe ingredients
  async getRecipeIngredients(recipeItemId: string) {
    const { data, error } = await supabase
      .from('recipe_ingredients')
      .select(`
        id,
        recipe_item_id,
        ingredient_item_id,
        quantity,
        unit_id,
        notes,
        created_at,
        updated_at,
        ingredient:items!ingredient_item_id(id, code, name_ar, unit_id),
        unit:units(id, name_ar, code)
      `)
      .eq('recipe_item_id', recipeItemId)

    // Transform the data to match expected format
    const ingredients = (data || []).map((ing: Record<string, unknown>) => ({
      ...ing,
      ingredient: Array.isArray(ing.ingredient) ? ing.ingredient[0] : ing.ingredient,
      unit: Array.isArray(ing.unit) ? ing.unit[0] : ing.unit
    }))

    return { data: fixEncodingInData(ingredients) as RecipeIngredient[], error }
  },

  // Create recipe (item + ingredients)
  async createRecipe(recipeData: CreateRecipeData) {
    // 1. Create the item
    const { data: item, error: itemError } = await supabase
      .from('items')
      .insert({
        code: recipeData.code,
        name: recipeData.name,
        name_ar: recipeData.name_ar,
        description: recipeData.description,
        unit_id: recipeData.unit_id,
        category_id: recipeData.category_id,
        min_stock_level: recipeData.min_stock_level || 0,
        purchase_price: recipeData.purchase_price || 0,
        selling_price: recipeData.selling_price || 0,
        is_recipe: true,
        status: 'active'
      })
      .select()
      .single()

    if (itemError) return { data: null, error: itemError }

    // 2. Create ingredients
    if (recipeData.ingredients.length > 0) {
      const ingredientsToInsert = recipeData.ingredients.map(ing => ({
        recipe_item_id: item.id,
        ingredient_item_id: ing.ingredient_item_id,
        quantity: ing.quantity,
        unit_id: ing.unit_id,
        notes: ing.notes
      }))

      const { error: ingError } = await supabase
        .from('recipe_ingredients')
        .insert(ingredientsToInsert)

      if (ingError) {
        // Rollback: delete the item
        await supabase.from('items').delete().eq('id', item.id)
        return { data: null, error: ingError }
      }
    }

    return { data: item as Item, error: null }
  },

  // Update recipe ingredients
  async updateRecipeIngredients(recipeItemId: string, ingredients: CreateRecipeData['ingredients']) {
    // Delete existing ingredients
    await supabase
      .from('recipe_ingredients')
      .delete()
      .eq('recipe_item_id', recipeItemId)

    // Insert new ingredients
    if (ingredients.length > 0) {
      const ingredientsToInsert = ingredients.map(ing => ({
        recipe_item_id: recipeItemId,
        ingredient_item_id: ing.ingredient_item_id,
        quantity: ing.quantity,
        unit_id: ing.unit_id,
        notes: ing.notes
      }))

      const { error } = await supabase
        .from('recipe_ingredients')
        .insert(ingredientsToInsert)

      return { error }
    }

    return { error: null }
  },

  // Produce recipe (add to inventory + deduct ingredients)
  async produceRecipe(data: ProduceRecipeData) {
    // 1. Get recipe ingredients
    const { data: ingredients, error: ingError } = await this.getRecipeIngredients(data.recipe_item_id)
    if (ingError || !ingredients?.length) {
      return { error: ingError || new Error('لا توجد مكونات لهذا الريسبي') }
    }

    // 2. Check ingredient availability in branch
    const insufficientItems: string[] = []
    for (const ing of ingredients) {
      const { data: inv } = await supabase
        .from('inventory')
        .select('quantity')
        .eq('branch_id', data.branch_id)
        .eq('item_id', ing.ingredient_item_id)
        .single()

      const available = inv?.quantity || 0
      const required = ing.quantity * data.quantity
      
      if (available < required) {
        const ingName = (ing.ingredient as Item)?.name_ar || ing.ingredient_item_id
        insufficientItems.push(`${ingName}: متوفر ${available} - مطلوب ${required}`)
      }
    }

    if (insufficientItems.length > 0) {
      return { error: new Error(`المكونات غير كافية:\n${insufficientItems.join('\n')}`) }
    }

    // 3. Deduct ingredients from branch inventory
    for (const ing of ingredients) {
      const requiredQty = ing.quantity * data.quantity
      
      const { data: inv } = await supabase
        .from('inventory')
        .select('id, quantity')
        .eq('branch_id', data.branch_id)
        .eq('item_id', ing.ingredient_item_id)
        .single()

      if (inv) {
        await supabase
          .from('inventory')
          .update({ 
            quantity: inv.quantity - requiredQty,
            updated_at: new Date().toISOString()
          })
          .eq('id', inv.id)
      }
    }

    // 4. Add recipe to branch inventory
    const { data: recipeInv } = await supabase
      .from('inventory')
      .select('id, quantity')
      .eq('branch_id', data.branch_id)
      .eq('item_id', data.recipe_item_id)
      .single()

    if (recipeInv) {
      await supabase
        .from('inventory')
        .update({ 
          quantity: recipeInv.quantity + data.quantity,
          updated_at: new Date().toISOString()
        })
        .eq('id', recipeInv.id)
    } else {
      await supabase
        .from('inventory')
        .insert({
          branch_id: data.branch_id,
          item_id: data.recipe_item_id,
          quantity: data.quantity,
          min_quantity: 0
        })
    }

    // 5. Log production
    const productionNumber = `PRD-${Date.now()}`
    const { error: logError } = await supabase
      .from('production_logs')
      .insert({
        production_number: productionNumber,
        recipe_item_id: data.recipe_item_id,
        branch_id: data.branch_id,
        quantity: data.quantity,
        notes: data.notes,
        produced_by: data.produced_by,
        produced_at: new Date().toISOString()
      })

    return { error: logError }
  },

  // Get production logs
  async getProductionLogs(branchId?: string, limit = 50) {
    let query = supabase
      .from('production_logs')
      .select('*, recipe:items(id, code, name_ar), branch:branches(id, name_ar)')
      .order('produced_at', { ascending: false })
      .limit(limit)

    if (branchId) {
      query = query.eq('branch_id', branchId)
    }

    const { data, error } = await query
    return { data: fixEncodingInData(data) as ProductionLog[], error }
  },

  // Get Recipe category ID
  async getRecipeCategoryId() {
    const { data } = await supabase
      .from('categories')
      .select('id')
      .eq('code', 'CAT-RECIPE')
      .single()
    
    return data?.id || null
  },

  // Check ingredient availability for a recipe in a branch
  async checkIngredientAvailability(recipeItemId: string, branchId: string, quantity: number) {
    const { data: ingredients } = await this.getRecipeIngredients(recipeItemId)
    if (!ingredients?.length) return { available: false, details: [] }

    const details: { name: string; required: number; available: number; sufficient: boolean }[] = []
    let allAvailable = true

    for (const ing of ingredients) {
      const { data: inv } = await supabase
        .from('inventory')
        .select('quantity')
        .eq('branch_id', branchId)
        .eq('item_id', ing.ingredient_item_id)
        .single()

      const available = inv?.quantity || 0
      const required = ing.quantity * quantity
      const sufficient = available >= required
      
      if (!sufficient) allAvailable = false

      details.push({
        name: (ing.ingredient as Item)?.name_ar || '',
        required,
        available,
        sufficient
      })
    }

    return { available: allAvailable, details }
  }
}
