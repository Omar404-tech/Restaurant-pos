import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { supabase } from '../../lib/supabase';
import { suppliersService } from '../../services/suppliers.service';
import { formatDate, formatCurrency } from '../../lib/utils';
import { Supplier } from '../../types/database.types';
import { ArrowRight, FileText, Printer, TrendingUp, TrendingDown, DollarSign } from 'lucide-react';

interface Transaction {
  id: string;
  date: string;
  type: 'supply' | 'payment' | 'return';
  reference: string;
  description: string;
  debit: number;  // مدين (توريدات)
  credit: number; // دائن (مدفوعات/مرتجعات)
  balance: number;
}

interface StatementData {
  supplier: Supplier | null;
  openingBalance: number;
  transactions: Transaction[];
  totalDebit: number;
  totalCredit: number;
  closingBalance: number;
}

export default function SupplierStatement() {
  const [suppliers, setSuppliers] = useState<Supplier[]>([]);
  const [selectedSupplier, setSelectedSupplier] = useState<string>('');
  const [startDate, setStartDate] = useState(() => {
    const d = new Date();
    d.setMonth(d.getMonth() - 1);
    return d.toISOString().split('T')[0];
  });
  const [endDate, setEndDate] = useState(() => new Date().toISOString().split('T')[0]);
  const [data, setData] = useState<StatementData | null>(null);
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    fetchSuppliers();
  }, []);

  const fetchSuppliers = async () => {
    const { data } = await suppliersService.getAll();
    setSuppliers(data || []);
  };

  const fetchStatement = async () => {
    if (!selectedSupplier) return;
    
    setLoading(true);
    
    // Get supplier info
    const { data: supplier } = await suppliersService.getById(selectedSupplier);
    
    // Get supplies before start date for opening balance
    const { data: prevSupplies } = await supabase
      .from('supplies')
      .select('total_amount')
      .eq('supplier_id', selectedSupplier)
      .lt('created_at', startDate);
    
    const { data: prevPayments } = await supabase
      .from('supplier_payments')
      .select('amount')
      .eq('supplier_id', selectedSupplier)
      .lt('payment_date', startDate);

    const { data: prevReturns } = await supabase
      .from('supplier_returns')
      .select('total_amount')
      .eq('supplier_id', selectedSupplier)
      .lt('created_at', startDate);

    const prevSuppliesTotal = prevSupplies?.reduce((sum, s) => sum + (Number(s.total_amount) || 0), 0) || 0;
    const prevPaymentsTotal = prevPayments?.reduce((sum, p) => sum + (Number(p.amount) || 0), 0) || 0;
    const prevReturnsTotal = prevReturns?.reduce((sum, r) => sum + (Number(r.total_amount) || 0), 0) || 0;
    const openingBalance = prevSuppliesTotal - prevPaymentsTotal - prevReturnsTotal;

    // Get supplies in period
    const { data: supplies } = await supabase
      .from('supplies')
      .select('id, supply_number, created_at, total_amount, invoice_number')
      .eq('supplier_id', selectedSupplier)
      .gte('created_at', startDate)
      .lte('created_at', endDate + 'T23:59:59')
      .order('created_at');

    // Get payments in period
    const { data: payments } = await supabase
      .from('supplier_payments')
      .select('id, payment_number, payment_date, amount, payment_method')
      .eq('supplier_id', selectedSupplier)
      .gte('payment_date', startDate)
      .lte('payment_date', endDate)
      .order('payment_date');

    // Get returns in period
    const { data: returns } = await supabase
      .from('supplier_returns')
      .select('id, return_number, created_at, total_amount')
      .eq('supplier_id', selectedSupplier)
      .gte('created_at', startDate)
      .lte('created_at', endDate + 'T23:59:59')
      .order('created_at');

    // Combine and sort transactions
    const transactions: Transaction[] = [];
    let runningBalance = openingBalance;

    // Add supplies
    supplies?.forEach(s => {
      runningBalance += Number(s.total_amount) || 0;
      transactions.push({
        id: s.id,
        date: s.created_at,
        type: 'supply',
        reference: s.supply_number,
        description: s.invoice_number ? `فاتورة: ${s.invoice_number}` : 'توريد',
        debit: Number(s.total_amount) || 0,
        credit: 0,
        balance: runningBalance,
      });
    });

    // Add payments
    payments?.forEach(p => {
      runningBalance -= Number(p.amount) || 0;
      transactions.push({
        id: p.id,
        date: p.payment_date,
        type: 'payment',
        reference: p.payment_number,
        description: `دفعة - ${p.payment_method || 'نقدي'}`,
        debit: 0,
        credit: Number(p.amount) || 0,
        balance: runningBalance,
      });
    });

    // Add returns
    returns?.forEach(r => {
      runningBalance -= Number(r.total_amount) || 0;
      transactions.push({
        id: r.id,
        date: r.created_at,
        type: 'return',
        reference: r.return_number,
        description: 'مرتجع للمورد',
        debit: 0,
        credit: Number(r.total_amount) || 0,
        balance: runningBalance,
      });
    });

    // Sort by date
    transactions.sort((a, b) => new Date(a.date).getTime() - new Date(b.date).getTime());

    // Recalculate running balance after sorting
    let balance = openingBalance;
    transactions.forEach(t => {
      balance += t.debit - t.credit;
      t.balance = balance;
    });

    const totalDebit = transactions.reduce((sum, t) => sum + t.debit, 0);
    const totalCredit = transactions.reduce((sum, t) => sum + t.credit, 0);

    setData({
      supplier,
      openingBalance,
      transactions,
      totalDebit,
      totalCredit,
      closingBalance: openingBalance + totalDebit - totalCredit,
    });
    
    setLoading(false);
  };

  const handlePrint = () => {
    window.print();
  };

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-4">
          <Link to="/reports" className="p-2 hover:bg-gray-100 rounded-lg">
            <ArrowRight className="w-5 h-5" />
          </Link>
          <div>
            <h1 className="text-2xl font-bold text-gray-900 flex items-center gap-2">
              <FileText className="w-6 h-6 text-green-600" />
              كشف حساب مورد
            </h1>
            <p className="text-gray-600">عرض تفاصيل حساب المورد</p>
          </div>
        </div>
        {data && (
          <button
            type="button"
            onClick={handlePrint}
            className="flex items-center gap-2 px-4 py-2 bg-gray-600 text-white rounded-lg hover:bg-gray-700 print:hidden"
          >
            <Printer className="w-4 h-4" />
            طباعة
          </button>
        )}
      </div>

      {/* Filters */}
      <div className="bg-white rounded-lg shadow-sm border border-gray-100 p-4 print:hidden">
        <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">المورد</label>
            <select
              value={selectedSupplier}
              onChange={(e) => setSelectedSupplier(e.target.value)}
              className="w-full px-4 py-2 border border-gray-300 rounded-lg"
              aria-label="المورد"
            >
              <option value="">اختر المورد...</option>
              {suppliers.map(s => (
                <option key={s.id} value={s.id}>{s.name_ar}</option>
              ))}
            </select>
          </div>
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">من تاريخ</label>
            <input
              type="date"
              value={startDate}
              onChange={(e) => setStartDate(e.target.value)}
              className="w-full px-4 py-2 border border-gray-300 rounded-lg"
              aria-label="من تاريخ"
            />
          </div>
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">إلى تاريخ</label>
            <input
              type="date"
              value={endDate}
              onChange={(e) => setEndDate(e.target.value)}
              className="w-full px-4 py-2 border border-gray-300 rounded-lg"
              aria-label="إلى تاريخ"
            />
          </div>
          <div className="flex items-end">
            <button
              type="button"
              onClick={fetchStatement}
              disabled={!selectedSupplier || loading}
              className="w-full px-4 py-2 bg-green-600 text-white rounded-lg hover:bg-green-700 disabled:opacity-50"
            >
              {loading ? 'جاري التحميل...' : 'عرض الكشف'}
            </button>
          </div>
        </div>
      </div>

      {/* Statement */}
      {data && (
        <>
          {/* Supplier Info */}
          <div className="bg-white rounded-lg shadow-sm border border-gray-100 p-6">
            <div className="flex justify-between items-start mb-4">
              <div>
                <h2 className="text-xl font-bold text-gray-900">{data.supplier?.name_ar}</h2>
                <p className="text-gray-600">كود: {data.supplier?.code}</p>
                {data.supplier?.phone && <p className="text-gray-600">هاتف: {data.supplier?.phone}</p>}
              </div>
              <div className="text-left">
                <p className="text-sm text-gray-500">الفترة</p>
                <p className="font-medium">{formatDate(startDate)} - {formatDate(endDate)}</p>
              </div>
            </div>

            {/* Summary Cards */}
            <div className="grid grid-cols-2 md:grid-cols-4 gap-4 mt-6">
              <div className="bg-gray-50 rounded-lg p-4">
                <div className="flex items-center gap-2 text-gray-600 mb-1">
                  <DollarSign className="w-4 h-4" />
                  <span className="text-sm">رصيد أول المدة</span>
                </div>
                <p className={`text-xl font-bold ${data.openingBalance > 0 ? 'text-red-600' : 'text-green-600'}`}>
                  {formatCurrency(data.openingBalance)}
                </p>
              </div>
              <div className="bg-red-50 rounded-lg p-4">
                <div className="flex items-center gap-2 text-red-600 mb-1">
                  <TrendingUp className="w-4 h-4" />
                  <span className="text-sm">إجمالي المشتريات</span>
                </div>
                <p className="text-xl font-bold text-red-600">{formatCurrency(data.totalDebit)}</p>
              </div>
              <div className="bg-green-50 rounded-lg p-4">
                <div className="flex items-center gap-2 text-green-600 mb-1">
                  <TrendingDown className="w-4 h-4" />
                  <span className="text-sm">إجمالي المدفوعات</span>
                </div>
                <p className="text-xl font-bold text-green-600">{formatCurrency(data.totalCredit)}</p>
              </div>
              <div className={`rounded-lg p-4 ${data.closingBalance > 0 ? 'bg-red-100' : 'bg-green-100'}`}>
                <div className="flex items-center gap-2 mb-1">
                  <DollarSign className="w-4 h-4" />
                  <span className="text-sm">المبلغ المستحق</span>
                </div>
                <p className={`text-xl font-bold ${data.closingBalance > 0 ? 'text-red-600' : 'text-green-600'}`}>
                  {formatCurrency(data.closingBalance)}
                </p>
              </div>
            </div>
          </div>

          {/* Transactions Table */}
          <div className="bg-white rounded-lg shadow-sm border border-gray-100 overflow-hidden">
            <div className="overflow-x-auto">
              <table className="w-full">
                <thead className="bg-green-600 text-white">
                  <tr>
                    <th className="px-4 py-3 text-right text-sm font-medium">التاريخ</th>
                    <th className="px-4 py-3 text-right text-sm font-medium">المرجع</th>
                    <th className="px-4 py-3 text-right text-sm font-medium">البيان</th>
                    <th className="px-4 py-3 text-right text-sm font-medium">مدين (له)</th>
                    <th className="px-4 py-3 text-right text-sm font-medium">دائن (منه)</th>
                    <th className="px-4 py-3 text-right text-sm font-medium">الرصيد</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-gray-100">
                  {/* Opening Balance Row */}
                  <tr className="bg-gray-100 font-medium">
                    <td className="px-4 py-3">{formatDate(startDate)}</td>
                    <td className="px-4 py-3">-</td>
                    <td className="px-4 py-3">رصيد أول المدة</td>
                    <td className="px-4 py-3">-</td>
                    <td className="px-4 py-3">-</td>
                    <td className={`px-4 py-3 ${data.openingBalance > 0 ? 'text-red-600' : 'text-green-600'}`}>
                      {formatCurrency(data.openingBalance)}
                    </td>
                  </tr>
                  {/* Transactions */}
                  {data.transactions.map((t, i) => (
                    <tr key={t.id} className={i % 2 === 0 ? 'bg-white' : 'bg-gray-50'}>
                      <td className="px-4 py-3">{formatDate(t.date)}</td>
                      <td className="px-4 py-3 font-mono text-sm">{t.reference}</td>
                      <td className="px-4 py-3">
                        <span className={`inline-flex items-center gap-1 ${
                          t.type === 'supply' ? 'text-blue-600' : 
                          t.type === 'payment' ? 'text-green-600' : 'text-orange-600'
                        }`}>
                          {t.description}
                        </span>
                      </td>
                      <td className="px-4 py-3 text-red-600">{t.debit > 0 ? formatCurrency(t.debit) : '-'}</td>
                      <td className="px-4 py-3 text-green-600">{t.credit > 0 ? formatCurrency(t.credit) : '-'}</td>
                      <td className={`px-4 py-3 font-medium ${t.balance > 0 ? 'text-red-600' : 'text-green-600'}`}>
                        {formatCurrency(t.balance)}
                      </td>
                    </tr>
                  ))}
                  {/* Closing Balance Row */}
                  <tr className="bg-gray-200 font-bold">
                    <td className="px-4 py-3" colSpan={3}>رصيد آخر المدة</td>
                    <td className="px-4 py-3 text-red-600">{formatCurrency(data.totalDebit)}</td>
                    <td className="px-4 py-3 text-green-600">{formatCurrency(data.totalCredit)}</td>
                    <td className={`px-4 py-3 ${data.closingBalance > 0 ? 'text-red-600' : 'text-green-600'}`}>
                      {formatCurrency(data.closingBalance)}
                    </td>
                  </tr>
                </tbody>
              </table>
            </div>
            {data.transactions.length === 0 && (
              <div className="text-center py-12 text-gray-500">لا توجد حركات في هذه الفترة</div>
            )}
          </div>
        </>
      )}

      {!data && !loading && (
        <div className="bg-white rounded-lg shadow-sm border border-gray-100 p-12 text-center">
          <FileText className="w-16 h-16 text-gray-300 mx-auto mb-4" />
          <p className="text-gray-500">اختر المورد والفترة ثم اضغط "عرض الكشف"</p>
        </div>
      )}
    </div>
  );
}
