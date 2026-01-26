/**
 * إضافة كاشير إضافي للفرع 1
 * Add Additional Cashier to Branch 1
 * 
 * Usage:
 * 1. Make sure you have @supabase/supabase-js installed
 * 2. Set SUPABASE_SERVICE_ROLE_KEY in your .env file
 * 3. Run: node add_cashier.js
 */

import { createClient } from '@supabase/supabase-js'
import * as dotenv from 'dotenv'

dotenv.config()

const supabaseUrl = process.env.VITE_SUPABASE_URL || process.env.SUPABASE_URL
const supabaseServiceKey = process.env.SUPABASE_SERVICE_ROLE_KEY

if (!supabaseUrl || !supabaseServiceKey) {
  console.error('❌ Error: Missing Supabase credentials')
  console.error('Please set VITE_SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY in your .env file')
  process.exit(1)
}

const supabase = createClient(supabaseUrl, supabaseServiceKey, {
  auth: {
    autoRefreshToken: false,
    persistSession: false
  }
})

async function addCashier() {
  console.log('🔄 Adding new cashier to Branch 1...\n')

  // Branch 1 ID
  const branch1Id = '393fdf52-1982-481b-a254-11ba0edc1d8b'

  // New cashier details
  const newCashier = {
    email: 'cashier1c@restaurant.com',
    password: '1234',
    email_confirm: true,
    user_metadata: {
      full_name: 'أحمد محمود',
      full_name_ar: 'أحمد محمود',
      role: 'cashier',
      branch_id: branch1Id,
      employee_code: 'CASH1C'
    }
  }

  try {
    // Create the user
    const { data, error } = await supabase.auth.admin.createUser(newCashier)

    if (error) {
      console.error('❌ Error creating user:', error.message)
      return
    }

    console.log('✅ Cashier created successfully!')
    console.log('\n📋 User Details:')
    console.log('   ID:', data.user.id)
    console.log('   Email:', data.user.email)
    console.log('   Name:', data.user.user_metadata.full_name)
    console.log('   Role:', data.user.user_metadata.role)
    console.log('   Branch ID:', data.user.user_metadata.branch_id)
    console.log('   Employee Code:', data.user.user_metadata.employee_code)
    console.log('\n🔑 Login Credentials:')
    console.log('   Email: cashier1c@restaurant.com')
    console.log('   Password: 1234')

    // Verify by listing all cashiers for Branch 1
    console.log('\n📊 All cashiers for Branch 1:')
    const { data: users, error: listError } = await supabase.auth.admin.listUsers()
    
    if (!listError && users) {
      const branch1Cashiers = users.users.filter(u => 
        u.user_metadata?.role === 'cashier' && 
        u.user_metadata?.branch_id === branch1Id
      )
      
      branch1Cashiers.forEach((user, index) => {
        console.log(`   ${index + 1}. ${user.user_metadata.full_name} (${user.email})`)
      })
    }

  } catch (err) {
    console.error('❌ Unexpected error:', err)
  }
}

// Run the script
addCashier()
