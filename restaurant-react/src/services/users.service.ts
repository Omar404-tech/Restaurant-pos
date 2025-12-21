import { supabase, fixEncodingInData } from '../lib/supabase'

export interface UserWithDetails {
  id: string
  employee_code: string
  username: string
  email: string
  full_name: string
  full_name_ar: string
  phone: string | null
  status: 'active' | 'inactive'
  created_at: string
  role: { id: string; name: string; name_ar: string } | null
  branch: { id: string; name_ar: string; code: string } | null
}

export const usersService = {
  async getAll() {
    const { data, error } = await supabase
      .from('users')
      .select('*, role:roles(id, name, name_ar), branch:branches(id, name_ar, code)')
      .order('created_at', { ascending: false })

    return { data: fixEncodingInData(data) as UserWithDetails[], error }
  },

  async getById(id: string) {
    const { data, error } = await supabase
      .from('users')
      .select('*, role:roles(id, name, name_ar), branch:branches(id, name_ar, code)')
      .eq('id', id)
      .single()

    return { data: fixEncodingInData(data) as UserWithDetails, error }
  },

  async getRoles() {
    const { data, error } = await supabase
      .from('roles')
      .select('*')
      .order('name')

    return { data: fixEncodingInData(data), error }
  },

  async updateStatus(id: string, status: 'active' | 'inactive') {
    const { data, error } = await supabase
      .from('users')
      .update({ status, updated_at: new Date().toISOString() })
      .eq('id', id)
      .select()
      .single()

    return { data, error }
  },
}
