import { useEffect, useState } from 'react'
import { usersService, UserWithDetails } from '../../services/users.service'
import { Users, Mail, Phone, Building2, Shield, CheckCircle, XCircle } from 'lucide-react'

export default function UserList() {
  const [users, setUsers] = useState<UserWithDetails[]>([])
  const [loading, setLoading] = useState(true)
  const [filter, setFilter] = useState<'all' | 'active' | 'inactive'>('all')

  useEffect(() => {
    fetchUsers()
  }, [])

  const fetchUsers = async () => {
    const { data } = await usersService.getAll()
    setUsers(data || [])
    setLoading(false)
  }

  const filteredUsers = users.filter(u => 
    filter === 'all' || u.status === filter
  )

  const getRoleBadgeColor = (roleName: string) => {
    const colors: Record<string, string> = {
      admin: 'bg-red-100 text-red-700',
      warehouse_manager: 'bg-blue-100 text-blue-700',
      branch_supervisor: 'bg-green-100 text-green-700',
      cashier: 'bg-yellow-100 text-yellow-700',
      chef: 'bg-orange-100 text-orange-700',
      purchase_manager: 'bg-purple-100 text-purple-700',
    }
    return colors[roleName] || 'bg-gray-100 text-gray-700'
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
          <h1 className="text-2xl font-bold text-gray-900">المستخدمين</h1>
          <p className="text-gray-600">إدارة مستخدمي النظام</p>
        </div>
      </div>

      {/* Filters */}
      <div className="flex gap-2">
        {(['all', 'active', 'inactive'] as const).map((status) => (
          <button
            key={status}
            type="button"
            onClick={() => setFilter(status)}
            className={`px-4 py-2 rounded-lg text-sm font-medium transition-colors ${
              filter === status
                ? 'bg-blue-600 text-white'
                : 'bg-gray-100 text-gray-700 hover:bg-gray-200'
            }`}
          >
            {status === 'all' ? 'الكل' : status === 'active' ? 'نشط' : 'غير نشط'}
          </button>
        ))}
      </div>

      {/* Users Grid */}
      <div className="grid md:grid-cols-2 lg:grid-cols-3 gap-4">
        {filteredUsers.map((user) => (
          <div key={user.id} className="bg-white rounded-lg shadow-sm border border-gray-100 p-4">
            <div className="flex items-start gap-4">
              <div className="w-12 h-12 bg-blue-100 rounded-full flex items-center justify-center flex-shrink-0">
                <Users className="w-6 h-6 text-blue-600" />
              </div>
              <div className="flex-1 min-w-0">
                <div className="flex items-center gap-2 mb-1">
                  <h3 className="font-medium text-gray-900 truncate">{user.full_name_ar || user.full_name}</h3>
                  {user.status === 'active' ? (
                    <CheckCircle className="w-4 h-4 text-green-500 flex-shrink-0" />
                  ) : (
                    <XCircle className="w-4 h-4 text-red-500 flex-shrink-0" />
                  )}
                </div>
                <p className="text-sm text-gray-500 mb-2">{user.employee_code}</p>
                
                <div className="space-y-1 text-sm">
                  <div className="flex items-center gap-2 text-gray-600">
                    <Mail className="w-4 h-4" />
                    <span className="truncate">{user.email}</span>
                  </div>
                  {user.phone && (
                    <div className="flex items-center gap-2 text-gray-600">
                      <Phone className="w-4 h-4" />
                      <span>{user.phone}</span>
                    </div>
                  )}
                  {user.branch && (
                    <div className="flex items-center gap-2 text-gray-600">
                      <Building2 className="w-4 h-4" />
                      <span>{user.branch.name_ar}</span>
                    </div>
                  )}
                </div>

                <div className="mt-3 flex items-center gap-2">
                  <Shield className="w-4 h-4 text-gray-400" />
                  <span className={`px-2 py-0.5 rounded-full text-xs font-medium ${getRoleBadgeColor(user.role?.name || '')}`}>
                    {user.role?.name_ar || user.role?.name}
                  </span>
                </div>
              </div>
            </div>
          </div>
        ))}
      </div>

      {filteredUsers.length === 0 && (
        <div className="text-center py-12 bg-white rounded-lg shadow-sm">
          <Users className="w-12 h-12 text-gray-400 mx-auto mb-4" />
          <h3 className="text-lg font-medium text-gray-900 mb-2">لا يوجد مستخدمين</h3>
          <p className="text-gray-600">لم يتم العثور على مستخدمين</p>
        </div>
      )}
    </div>
  )
}
