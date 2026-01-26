"""
اختبار شامل لجميع التقارير
يتحقق من صحة القيم والحسابات في كل تقرير
"""

import os
import sys
from datetime import datetime, timedelta
from decimal import Decimal

# إضافة المسار الرئيسي للمشروع
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')

import django
django.setup()

from django.db.models import Sum, Count, Avg, F, Q
from apps.orders.models import Order, OrderItem
from apps.inventory.models import Inventory, Item, Category
from apps.transfers.models import Transfer, TransferItem
from apps.damages.models import Damage
from apps.suppliers.models import Supply, SupplyItem, Payment
from apps.branches.models import Branch
from apps.accounts.models import User


class ReportsTestSuite:
    """مجموعة اختبارات شاملة للتقارير"""
    
    def __init__(self):
        self.errors = []
        self.warnings = []
        self.passed = []
        
    def log_error(self, test_name, message):
        """تسجيل خطأ"""
        self.errors.append(f"❌ {test_name}: {message}")
        
    def log_warning(self, test_name, message):
        """تسجيل تحذير"""
        self.warnings.append(f"⚠️  {test_name}: {message}")
        
    def log_pass(self, test_name, message=""):
        """تسجيل نجاح"""
        self.passed.append(f"✅ {test_name}" + (f": {message}" if message else ""))
    
    def test_sales_report(self):
        """اختبار تقرير المبيعات"""
        print("\n📊 اختبار تقرير المبيعات...")
        
        # الحصول على الطلبات في آخر 30 يوم
        end_date = datetime.now()
        start_date = end_date - timedelta(days=30)
        
        orders = Order.objects.filter(
            created_at__gte=start_date,
            created_at__lte=end_date
        )
        
        # 1. التحقق من إجمالي الطلبات
        total_orders = orders.count()
        if total_orders == 0:
            self.log_warning("sales_total_orders", "لا توجد طلبات في آخر 30 يوم")
        else:
            self.log_pass("sales_total_orders", f"عدد الطلبات: {total_orders}")
        
        # 2. التحقق من إجمالي الإيرادات
        total_revenue = orders.aggregate(total=Sum('total_amount'))['total'] or Decimal('0')
        if total_revenue == 0 and total_orders > 0:
            self.log_error("sales_total_revenue", "إجمالي الإيرادات = 0 رغم وجود طلبات")
        else:
            self.log_pass("sales_total_revenue", f"إجمالي الإيرادات: {total_revenue:.2f} ج.م")
        
        # 3. التحقق من متوسط قيمة الطلب
        if total_orders > 0:
            avg_order = total_revenue / total_orders
            if avg_order < 10:
                self.log_warning("sales_avg_order", f"متوسط قيمة الطلب منخفض جداً: {avg_order:.2f} ج.م")
            else:
                self.log_pass("sales_avg_order", f"متوسط قيمة الطلب: {avg_order:.2f} ج.م")
        
        # 4. التحقق من الطلبات حسب الحالة
        status_counts = orders.values('status').annotate(count=Count('id'))
        for status in status_counts:
            self.log_pass(f"sales_status_{status['status']}", f"عدد: {status['count']}")
        
        # 5. التحقق من طرق الدفع
        payment_methods = orders.values('payment_method').annotate(
            count=Count('id'),
            total=Sum('total_amount')
        )
        
        payment_total = Decimal('0')
        for method in payment_methods:
            method_total = method['total'] or Decimal('0')
            payment_total += method_total
            self.log_pass(
                f"sales_payment_{method['payment_method']}", 
                f"عدد: {method['count']}, المبلغ: {method_total:.2f} ج.م"
            )
        
        # التحقق من تطابق مجموع طرق الدفع مع إجمالي الإيرادات
        if abs(payment_total - total_revenue) > Decimal('0.01'):
            self.log_error(
                "sales_payment_total_mismatch",
                f"مجموع طرق الدفع ({payment_total:.2f}) لا يطابق إجمالي الإيرادات ({total_revenue:.2f})"
            )
        else:
            self.log_pass("sales_payment_total_match", "مجموع طرق الدفع يطابق إجمالي الإيرادات")
        
        # 6. التحقق من أكثر الأصناف مبيعاً
        top_items = OrderItem.objects.filter(
            order__in=orders
        ).values(
            'item_id', 'item__name_ar'
        ).annotate(
            quantity=Sum('quantity'),
            revenue=Sum('total_price')
        ).order_by('-revenue')[:10]
        
        if top_items:
            self.log_pass("sales_top_items", f"تم العثور على {len(top_items)} أصناف")
            for idx, item in enumerate(top_items[:3], 1):
                self.log_pass(
                    f"sales_top_item_{idx}",
                    f"{item['item__name_ar']}: {item['quantity']} وحدة، {item['revenue']:.2f} ج.م"
                )
        else:
            self.log_warning("sales_top_items", "لا توجد أصناف مباعة")
        
        # 7. التحقق من المبيعات اليومية
        daily_sales = orders.extra(
            select={'day': 'DATE(created_at)'}
        ).values('day').annotate(
            orders=Count('id'),
            revenue=Sum('total_amount')
        ).order_by('day')
        
        if daily_sales:
            self.log_pass("sales_daily", f"تم العثور على {len(daily_sales)} يوم")
        else:
            self.log_warning("sales_daily", "لا توجد مبيعات يومية")
    
    def test_inventory_report(self):
        """اختبار تقرير المخزون"""
        print("\n📦 اختبار تقرير المخزون...")
        
        inventory = Inventory.objects.select_related('item', 'item__category')
        
        # 1. إجمالي الأصناف
        total_items = inventory.count()
        if total_items == 0:
            self.log_error("inventory_total", "لا توجد أصناف في المخزون")
            return
        else:
            self.log_pass("inventory_total", f"عدد الأصناف: {total_items}")
        
        # 2. الأصناف منخفضة المخزون
        low_stock = inventory.filter(
            quantity__lt=F('item__min_stock_level')
        ).count()
        
        if low_stock > 0:
            self.log_warning("inventory_low_stock", f"عدد الأصناف المنخفضة: {low_stock}")
        else:
            self.log_pass("inventory_low_stock", "لا توجد أصناف منخفضة المخزون")
        
        # 3. الأصناف النافذة
        out_of_stock = inventory.filter(quantity__lte=0).count()
        
        if out_of_stock > 0:
            self.log_error("inventory_out_of_stock", f"عدد الأصناف النافذة: {out_of_stock}")
        else:
            self.log_pass("inventory_out_of_stock", "لا توجد أصناف نافذة")
        
        # 4. قيمة المخزون
        total_value = Decimal('0')
        for inv in inventory:
            if inv.item and inv.item.purchase_price:
                total_value += inv.quantity * inv.item.purchase_price
        
        if total_value == 0:
            self.log_warning("inventory_value", "قيمة المخزون = 0")
        else:
            self.log_pass("inventory_value", f"قيمة المخزون: {total_value:.2f} ج.م")
        
        # 5. الأصناف حسب التصنيف
        categories = inventory.values(
            'item__category__name_ar'
        ).annotate(
            count=Count('id')
        )
        
        if categories:
            self.log_pass("inventory_categories", f"عدد التصنيفات: {len(categories)}")
            for cat in categories:
                cat_name = cat['item__category__name_ar'] or 'غير مصنف'
                self.log_pass(f"inventory_cat_{cat_name}", f"عدد الأصناف: {cat['count']}")
        else:
            self.log_warning("inventory_categories", "لا توجد تصنيفات")
        
        # 6. التحقق من الكميات السالبة
        negative_qty = inventory.filter(quantity__lt=0)
        if negative_qty.exists():
            self.log_error(
                "inventory_negative_qty",
                f"يوجد {negative_qty.count()} صنف بكمية سالبة"
            )
            for inv in negative_qty[:5]:
                self.log_error(
                    f"inventory_negative_{inv.item.name_ar}",
                    f"الكمية: {inv.quantity}"
                )
        else:
            self.log_pass("inventory_negative_qty", "لا توجد كميات سالبة")
    
    def test_suppliers_report(self):
        """اختبار تقرير الموردين"""
        print("\n🚚 اختبار تقرير الموردين...")
        
        # الحصول على البيانات في آخر 30 يوم
        end_date = datetime.now().date()
        start_date = end_date - timedelta(days=30)
        
        # 1. التوريدات
        supplies = Supply.objects.filter(
            supply_date__gte=start_date,
            supply_date__lte=end_date
        )
        
        total_supplies = supplies.count()
        total_supplies_value = supplies.aggregate(total=Sum('total_amount'))['total'] or Decimal('0')
        
        if total_supplies == 0:
            self.log_warning("suppliers_supplies", "لا توجد توريدات في آخر 30 يوم")
        else:
            self.log_pass("suppliers_supplies", f"عدد التوريدات: {total_supplies}")
            self.log_pass("suppliers_supplies_value", f"قيمة التوريدات: {total_supplies_value:.2f} ج.م")
        
        # 2. المدفوعات
        payments = Payment.objects.filter(
            payment_date__gte=start_date,
            payment_date__lte=end_date
        )
        
        total_payments = payments.count()
        total_payments_value = payments.aggregate(total=Sum('amount'))['total'] or Decimal('0')
        
        if total_payments == 0:
            self.log_warning("suppliers_payments", "لا توجد مدفوعات في آخر 30 يوم")
        else:
            self.log_pass("suppliers_payments", f"عدد المدفوعات: {total_payments}")
            self.log_pass("suppliers_payments_value", f"قيمة المدفوعات: {total_payments_value:.2f} ج.م")
        
        # 3. الرصيد المستحق
        balance = total_supplies_value - total_payments_value
        
        if balance > 0:
            self.log_warning("suppliers_balance", f"الرصيد المستحق: {balance:.2f} ج.م")
        elif balance < 0:
            self.log_warning("suppliers_balance", f"دفعات زائدة: {abs(balance):.2f} ج.م")
        else:
            self.log_pass("suppliers_balance", "الرصيد متوازن")
        
        # 4. التوريدات حسب المورد
        supplier_stats = supplies.values(
            'supplier__name_ar'
        ).annotate(
            count=Count('id'),
            total=Sum('total_amount')
        ).order_by('-total')
        
        if supplier_stats:
            self.log_pass("suppliers_by_supplier", f"عدد الموردين: {len(supplier_stats)}")
            for supplier in supplier_stats[:3]:
                self.log_pass(
                    f"suppliers_{supplier['supplier__name_ar']}",
                    f"عدد: {supplier['count']}, المبلغ: {supplier['total']:.2f} ج.م"
                )
        
        # 5. التحقق من التوريدات بدون أصناف
        supplies_without_items = supplies.filter(
            supply_items__isnull=True
        ).distinct()
        
        if supplies_without_items.exists():
            self.log_error(
                "suppliers_no_items",
                f"يوجد {supplies_without_items.count()} توريد بدون أصناف"
            )
        else:
            self.log_pass("suppliers_no_items", "جميع التوريدات تحتوي على أصناف")
    
    def test_damages_report(self):
        """اختبار تقرير التالف"""
        print("\n⚠️  اختبار تقرير التالف...")
        
        # الحصول على البيانات في آخر 30 يوم
        end_date = datetime.now()
        start_date = end_date - timedelta(days=30)
        
        damages = Damage.objects.filter(
            created_at__gte=start_date,
            created_at__lte=end_date
        )
        
        # 1. إجمالي التالف
        total_damages = damages.count()
        
        if total_damages == 0:
            self.log_warning("damages_total", "لا توجد سجلات تالف في آخر 30 يوم")
            return
        else:
            self.log_pass("damages_total", f"عدد السجلات: {total_damages}")
        
        # 2. التالف حسب الحالة
        pending = damages.filter(status='pending').count()
        approved = damages.filter(status='approved').count()
        rejected = damages.filter(status='rejected').count()
        
        self.log_pass("damages_pending", f"معلق: {pending}")
        self.log_pass("damages_approved", f"موافق عليه: {approved}")
        self.log_pass("damages_rejected", f"مرفوض: {rejected}")
        
        # 3. إجمالي الخسائر
        total_value = damages.aggregate(total=Sum('estimated_value'))['total'] or Decimal('0')
        
        if total_value == 0:
            self.log_warning("damages_value", "إجمالي الخسائر = 0")
        else:
            self.log_pass("damages_value", f"إجمالي الخسائر: {total_value:.2f} ج.م")
        
        # 4. التالف حسب السبب
        by_reason = damages.values(
            'reason__name_ar'
        ).annotate(
            count=Count('id'),
            value=Sum('estimated_value')
        ).order_by('-value')
        
        if by_reason:
            self.log_pass("damages_by_reason", f"عدد الأسباب: {len(by_reason)}")
            for reason in by_reason:
                reason_name = reason['reason__name_ar'] or 'غير محدد'
                self.log_pass(
                    f"damages_reason_{reason_name}",
                    f"عدد: {reason['count']}, القيمة: {reason['value']:.2f} ج.م"
                )
        
        # 5. التحقق من القيم السالبة
        negative_values = damages.filter(estimated_value__lt=0)
        if negative_values.exists():
            self.log_error(
                "damages_negative_value",
                f"يوجد {negative_values.count()} سجل بقيمة سالبة"
            )
        else:
            self.log_pass("damages_negative_value", "لا توجد قيم سالبة")
    
    def test_transfers_report(self):
        """اختبار تقرير التحويلات"""
        print("\n🔄 اختبار تقرير التحويلات...")
        
        # الحصول على البيانات في آخر 30 يوم
        end_date = datetime.now()
        start_date = end_date - timedelta(days=30)
        
        transfers = Transfer.objects.filter(
            created_at__gte=start_date,
            created_at__lte=end_date
        )
        
        # 1. إجمالي التحويلات
        total_transfers = transfers.count()
        
        if total_transfers == 0:
            self.log_warning("transfers_total", "لا توجد تحويلات في آخر 30 يوم")
            return
        else:
            self.log_pass("transfers_total", f"عدد التحويلات: {total_transfers}")
        
        # 2. التحويلات حسب الحالة
        pending = transfers.filter(status='pending').count()
        approved = transfers.filter(status='approved').count()
        received = transfers.filter(status='received').count()
        rejected = transfers.filter(status='rejected').count()
        
        self.log_pass("transfers_pending", f"معلق: {pending}")
        self.log_pass("transfers_approved", f"موافق عليه: {approved}")
        self.log_pass("transfers_received", f"مستلم: {received}")
        self.log_pass("transfers_rejected", f"مرفوض: {rejected}")
        
        # 3. التحقق من التحويلات بدون أصناف
        transfers_without_items = transfers.filter(
            transfer_items__isnull=True
        ).distinct()
        
        if transfers_without_items.exists():
            self.log_error(
                "transfers_no_items",
                f"يوجد {transfers_without_items.count()} تحويل بدون أصناف"
            )
        else:
            self.log_pass("transfers_no_items", "جميع التحويلات تحتوي على أصناف")
        
        # 4. التحقق من التحويلات من نفس الفرع إلى نفس الفرع
        same_branch = transfers.filter(from_branch=F('to_branch'))
        
        if same_branch.exists():
            self.log_error(
                "transfers_same_branch",
                f"يوجد {same_branch.count()} تحويل من نفس الفرع إلى نفس الفرع"
            )
        else:
            self.log_pass("transfers_same_branch", "لا توجد تحويلات من نفس الفرع")
    
    def test_performance_report(self):
        """اختبار تقرير الأداء"""
        print("\n📈 اختبار تقرير الأداء...")
        
        # الحصول على البيانات في آخر 30 يوم
        end_date = datetime.now()
        start_date = end_date - timedelta(days=30)
        
        # 1. أداء الفروع
        branches = Branch.objects.filter(is_active=True)
        
        for branch in branches:
            branch_orders = Order.objects.filter(
                branch=branch,
                created_at__gte=start_date,
                created_at__lte=end_date
            )
            
            orders_count = branch_orders.count()
            revenue = branch_orders.aggregate(total=Sum('total_amount'))['total'] or Decimal('0')
            
            self.log_pass(
                f"performance_branch_{branch.name_ar}",
                f"طلبات: {orders_count}, إيرادات: {revenue:.2f} ج.م"
            )
        
        # 2. مقارنة الفروع
        if branches.count() > 1:
            branch_stats = []
            for branch in branches:
                revenue = Order.objects.filter(
                    branch=branch,
                    created_at__gte=start_date,
                    created_at__lte=end_date
                ).aggregate(total=Sum('total_amount'))['total'] or Decimal('0')
                branch_stats.append((branch.name_ar, revenue))
            
            branch_stats.sort(key=lambda x: x[1], reverse=True)
            best_branch = branch_stats[0]
            worst_branch = branch_stats[-1]
            
            self.log_pass(
                "performance_best_branch",
                f"أفضل فرع: {best_branch[0]} ({best_branch[1]:.2f} ج.م)"
            )
            
            if worst_branch[1] == 0:
                self.log_warning(
                    "performance_worst_branch",
                    f"أسوأ فرع: {worst_branch[0]} (لا توجد مبيعات)"
                )
    
    def run_all_tests(self):
        """تشغيل جميع الاختبارات"""
        print("=" * 80)
        print("🧪 بدء اختبار شامل لجميع التقارير")
        print("=" * 80)
        
        self.test_sales_report()
        self.test_inventory_report()
        self.test_suppliers_report()
        self.test_damages_report()
        self.test_transfers_report()
        self.test_performance_report()
        
        # طباعة النتائج
        print("\n" + "=" * 80)
        print("📊 ملخص النتائج")
        print("=" * 80)
        
        print(f"\n✅ اختبارات ناجحة: {len(self.passed)}")
        for p in self.passed:
            print(f"  {p}")
        
        if self.warnings:
            print(f"\n⚠️  تحذيرات: {len(self.warnings)}")
            for w in self.warnings:
                print(f"  {w}")
        
        if self.errors:
            print(f"\n❌ أخطاء: {len(self.errors)}")
            for e in self.errors:
                print(f"  {e}")
        
        print("\n" + "=" * 80)
        print(f"النتيجة النهائية: {len(self.passed)} نجاح، {len(self.warnings)} تحذير، {len(self.errors)} خطأ")
        print("=" * 80)
        
        return len(self.errors) == 0


if __name__ == '__main__':
    suite = ReportsTestSuite()
    success = suite.run_all_tests()
    sys.exit(0 if success else 1)
