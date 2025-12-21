# 📋 خطة تنفيذ نظام إدارة المطعم
# Restaurant Management System - Implementation Plan

---

## 🎯 نظرة عامة

| البند | التفاصيل |
|-------|----------|
| **اسم المشروع** | Restaurant Management System |
| **التقنيات** | Django + PostgreSQL + Django Templates |
| **المدة المتوقعة** | 8-10 أسابيع |
| **الأولوية** | Backend First → Frontend |

---

## 📁 هيكل المشروع النهائي

```
restaurant_system/
├── config/                     # إعدادات Django
│   ├── __init__.py
│   ├── settings/
│   │   ├── __init__.py
│   │   ├── base.py            # الإعدادات المشتركة
│   │   ├── development.py     # إعدادات التطوير
│   │   └── production.py      # إعدادات الإنتاج
│   ├── urls.py
│   ├── wsgi.py
│   └── asgi.py
├── apps/
│   ├── __init__.py
│   ├── core/                   # الوظائف المشتركة
│   ├── accounts/               # المستخدمين والصلاحيات
│   ├── branches/               # الفروع
│   ├── suppliers/              # الموردين والتوريدات
│   ├── inventory/              # المخزون
│   ├── transfers/              # التحويلات
│   ├── damages/                # التالف
│   ├── returns/                # المرتجعات
│   ├── menu/                   # المنيو
│   ├── orders/                 # الأوردرات
│   ├── pos/                    # نقاط البيع
│   └── reports/                # التقارير
├── templates/                  # قوالب HTML
├── static/                     # ملفات CSS/JS
├── media/                      # الملفات المرفوعة
├── locale/                     # الترجمات
├── tests/                      # الاختبارات
├── docs/                       # التوثيق
├── scripts/                    # سكريبتات مساعدة
├── requirements/
│   ├── base.txt
│   ├── development.txt
│   └── production.txt
├── manage.py
├── .env.example
├── .gitignore
└── README.md
```

---

## 🚀 المراحل التنفيذية


---

# 🔷 المرحلة 1: إعداد المشروع والـ Database
## المدة: 3-4 أيام

### ✅ الخطوة 1.1: إنشاء مشروع Django
```
المهام:
□ إنشاء virtual environment
□ تثبيت Django و dependencies
□ إنشاء مشروع Django
□ إعداد هيكل المجلدات
□ إعداد ملفات الإعدادات (settings)
□ إعداد .env و .gitignore
```

**الأوامر:**
```bash
python -m venv venv
venv\Scripts\activate  # Windows
pip install django psycopg2-binary python-decouple pillow
django-admin startproject config .
```

**اختبار النجاح:**
```bash
python manage.py runserver
# يجب أن يعمل السيرفر على http://127.0.0.1:8000/
```

---

### ✅ الخطوة 1.2: إعداد PostgreSQL
```
المهام:
□ تثبيت PostgreSQL
□ إنشاء قاعدة البيانات
□ إنشاء المستخدم
□ ربط Django بـ PostgreSQL
```

**الأوامر:**
```sql
-- في PostgreSQL
CREATE DATABASE restaurant_db;
CREATE USER restaurant_user WITH PASSWORD 'your_password';
ALTER ROLE restaurant_user SET client_encoding TO 'utf8';
ALTER ROLE restaurant_user SET default_transaction_isolation TO 'read committed';
ALTER ROLE restaurant_user SET timezone TO 'UTC';
GRANT ALL PRIVILEGES ON DATABASE restaurant_db TO restaurant_user;
```

**settings.py:**
```python
DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.postgresql',
        'NAME': 'restaurant_db',
        'USER': 'restaurant_user',
        'PASSWORD': 'your_password',
        'HOST': 'localhost',
        'PORT': '5432',
    }
}
```

**اختبار النجاح:**
```bash
python manage.py check
# يجب أن يظهر "System check identified no issues"
```

---

### ✅ الخطوة 1.3: إنشاء التطبيقات (Apps)
```
المهام:
□ إنشاء app core
□ إنشاء app accounts
□ إنشاء app branches
□ إنشاء app suppliers
□ إنشاء app inventory
□ إنشاء app transfers
□ إنشاء app damages
□ إنشاء app returns
□ إنشاء app menu
□ إنشاء app orders
□ إنشاء app pos
□ إنشاء app reports
□ تسجيل التطبيقات في settings
```

**الأوامر:**
```bash
mkdir apps
cd apps
python ../manage.py startapp core
python ../manage.py startapp accounts
python ../manage.py startapp branches
python ../manage.py startapp suppliers
python ../manage.py startapp inventory
python ../manage.py startapp transfers
python ../manage.py startapp damages
python ../manage.py startapp returns
python ../manage.py startapp menu
python ../manage.py startapp orders
python ../manage.py startapp pos
python ../manage.py startapp reports
```

**اختبار النجاح:**
```bash
python manage.py check
```

---

### ✅ الخطوة 1.4: إنشاء Models - الجزء الأول (Core & Accounts)
```
المهام:
□ إنشاء BaseModel في core
□ إنشاء Lookup Models
□ إنشاء Custom User Model
□ إنشاء Role Model
□ إنشاء Branch Model
□ تشغيل migrations
```

**اختبار النجاح:**
```bash
python manage.py makemigrations
python manage.py migrate
python manage.py createsuperuser
python manage.py runserver
# الدخول على /admin/ والتأكد من ظهور الجداول
```

---

### ✅ الخطوة 1.5: إنشاء Models - الجزء الثاني (Suppliers & Inventory)
```
المهام:
□ إنشاء Category Model
□ إنشاء Unit Model
□ إنشاء Item Model
□ إنشاء Supplier Model
□ إنشاء SupplierItem Model
□ إنشاء Inventory Model
□ إنشاء InventoryBatch Model
□ تشغيل migrations
```

**اختبار النجاح:**
```bash
python manage.py makemigrations
python manage.py migrate
# إضافة بيانات تجريبية من Admin
```

---

### ✅ الخطوة 1.6: إنشاء Models - الجزء الثالث (Operations)
```
المهام:
□ إنشاء Supply Model
□ إنشاء SupplyItem Model
□ إنشاء SupplierPayment Model
□ إنشاء Transfer Model
□ إنشاء TransferItem Model
□ إنشاء DamageReason Model
□ إنشاء Damage Model
□ إنشاء SupplierReturn Model
□ تشغيل migrations
```

**اختبار النجاح:**
```bash
python manage.py makemigrations
python manage.py migrate
python manage.py shell
>>> from apps.suppliers.models import Supplier
>>> Supplier.objects.create(name="Test Supplier", code="SUP001", phone="01234567890")
```

---

### ✅ الخطوة 1.7: إنشاء Models - الجزء الرابع (Orders & POS)
```
المهام:
□ إنشاء MenuCategory Model
□ إنشاء MenuItem Model
□ إنشاء MenuItemIngredient Model
□ إنشاء Order Model
□ إنشاء OrderItem Model
□ إنشاء InventoryTransaction Model
□ إنشاء DailyInventoryCount Model
□ تشغيل migrations
```

**اختبار النجاح:**
```bash
python manage.py makemigrations
python manage.py migrate
python manage.py dbshell
\dt  # عرض كل الجداول
```

---

### ✅ الخطوة 1.8: إنشاء Models - الجزء الخامس (Settings & Logs)
```
المهام:
□ إنشاء Notification Model
□ إنشاء AlertSetting Model
□ إنشاء AuditLog Model
□ إنشاء UserSession Model
□ إنشاء SystemSetting Model
□ إنشاء BranchSetting Model
□ تشغيل migrations
□ إضافة Seed Data
```

**اختبار النجاح:**
```bash
python manage.py makemigrations
python manage.py migrate
python manage.py loaddata initial_data.json
```


---

# 🔷 المرحلة 2: Serializers & Business Logic
## المدة: 4-5 أيام

### ✅ الخطوة 2.1: إنشاء Serializers - Core & Accounts
```
المهام:
□ إنشاء UserSerializer
□ إنشاء RoleSerializer
□ إنشاء BranchSerializer
□ إنشاء LoginSerializer
□ إنشاء ChangePasswordSerializer
□ إنشاء LookupSerializers
```

**الملفات:**
```
apps/accounts/serializers.py
apps/branches/serializers.py
apps/core/serializers.py
```

**اختبار النجاح:**
```python
# في Django shell
from apps.accounts.serializers import UserSerializer
from apps.accounts.models import User
user = User.objects.first()
serializer = UserSerializer(user)
print(serializer.data)
```

---

### ✅ الخطوة 2.2: إنشاء Serializers - Suppliers
```
المهام:
□ إنشاء SupplierSerializer
□ إنشاء SupplierListSerializer
□ إنشاء SupplierDetailSerializer
□ إنشاء SupplySerializer
□ إنشاء SupplyItemSerializer
□ إنشاء SupplyCreateSerializer
□ إنشاء SupplierPaymentSerializer
```

**اختبار النجاح:**
```python
from apps.suppliers.serializers import SupplierSerializer
# اختبار التسلسل والتحقق
```

---

### ✅ الخطوة 2.3: إنشاء Serializers - Inventory
```
المهام:
□ إنشاء CategorySerializer
□ إنشاء UnitSerializer
□ إنشاء ItemSerializer
□ إنشاء ItemListSerializer
□ إنشاء InventorySerializer
□ إنشاء InventoryBatchSerializer
□ إنشاء InventoryTransactionSerializer
```

**اختبار النجاح:**
```python
from apps.inventory.serializers import ItemSerializer
```

---

### ✅ الخطوة 2.4: إنشاء Serializers - Operations
```
المهام:
□ إنشاء TransferSerializer
□ إنشاء TransferItemSerializer
□ إنشاء TransferCreateSerializer
□ إنشاء TransferApproveSerializer
□ إنشاء DamageSerializer
□ إنشاء DamageCreateSerializer
□ إنشاء SupplierReturnSerializer
□ إنشاء SupplierReturnCreateSerializer
```

**اختبار النجاح:**
```python
from apps.transfers.serializers import TransferSerializer
```

---

### ✅ الخطوة 2.5: إنشاء Serializers - Orders & POS
```
المهام:
□ إنشاء MenuCategorySerializer
□ إنشاء MenuItemSerializer
□ إنشاء OrderSerializer
□ إنشاء OrderItemSerializer
□ إنشاء OrderCreateSerializer
□ إنشاء OrderStatusUpdateSerializer
□ إنشاء DailyCountSerializer
```

**اختبار النجاح:**
```python
from apps.orders.serializers import OrderSerializer
```

---

### ✅ الخطوة 2.6: إنشاء Business Logic Services
```
المهام:
□ إنشاء InventoryService (إدارة المخزون)
□ إنشاء SupplyService (التوريدات)
□ إنشاء TransferService (التحويلات)
□ إنشاء DamageService (التالف)
□ إنشاء ReturnService (المرتجعات)
□ إنشاء OrderService (الأوردرات)
□ إنشاء NotificationService (الإشعارات)
□ إنشاء ReportService (التقارير)
```

**الملفات:**
```
apps/inventory/services.py
apps/suppliers/services.py
apps/transfers/services.py
apps/damages/services.py
apps/returns/services.py
apps/orders/services.py
apps/core/services.py
apps/reports/services.py
```

**اختبار النجاح:**
```python
from apps.inventory.services import InventoryService
# اختبار الوظائف
```


---

# 🔷 المرحلة 3: URLs & Views (API)
## المدة: 5-6 أيام

### ✅ الخطوة 3.1: إعداد URLs الرئيسية
```
المهام:
□ إعداد config/urls.py
□ إنشاء urls.py لكل app
□ إعداد API versioning
□ إعداد static و media URLs
```

**config/urls.py:**
```python
urlpatterns = [
    path('admin/', admin.site.urls),
    path('', include('apps.core.urls')),
    path('accounts/', include('apps.accounts.urls')),
    path('branches/', include('apps.branches.urls')),
    path('suppliers/', include('apps.suppliers.urls')),
    path('inventory/', include('apps.inventory.urls')),
    path('transfers/', include('apps.transfers.urls')),
    path('damages/', include('apps.damages.urls')),
    path('returns/', include('apps.returns.urls')),
    path('menu/', include('apps.menu.urls')),
    path('orders/', include('apps.orders.urls')),
    path('pos/', include('apps.pos.urls')),
    path('reports/', include('apps.reports.urls')),
]
```

**اختبار النجاح:**
```bash
python manage.py show_urls  # إذا كان django-extensions مثبت
python manage.py runserver
```

---

### ✅ الخطوة 3.2: Views - Accounts & Auth
```
المهام:
□ إنشاء LoginView
□ إنشاء LogoutView
□ إنشاء ProfileView
□ إنشاء ChangePasswordView
□ إنشاء UserListView
□ إنشاء UserCreateView
□ إنشاء UserUpdateView
□ إنشاء RoleListView
```

**URLs:**
```
/accounts/login/
/accounts/logout/
/accounts/profile/
/accounts/change-password/
/accounts/users/
/accounts/users/create/
/accounts/users/<id>/edit/
/accounts/roles/
```

**اختبار النجاح:**
```bash
# اختبار تسجيل الدخول
curl -X POST http://localhost:8000/accounts/login/ \
  -d "username=admin&password=admin123"
```

---

### ✅ الخطوة 3.3: Views - Branches
```
المهام:
□ إنشاء BranchListView
□ إنشاء BranchCreateView
□ إنشاء BranchUpdateView
□ إنشاء BranchDetailView
□ إنشاء BranchSettingsView
```

**URLs:**
```
/branches/
/branches/create/
/branches/<id>/
/branches/<id>/edit/
/branches/<id>/settings/
```

**اختبار النجاح:**
```bash
python manage.py runserver
# زيارة /branches/ والتأكد من عرض القائمة
```

---

### ✅ الخطوة 3.4: Views - Suppliers
```
المهام:
□ إنشاء SupplierListView
□ إنشاء SupplierCreateView
□ إنشاء SupplierUpdateView
□ إنشاء SupplierDetailView
□ إنشاء SupplyListView
□ إنشاء SupplyCreateView
□ إنشاء SupplyDetailView
□ إنشاء SupplierPaymentListView
□ إنشاء SupplierPaymentCreateView
□ إنشاء SupplierBalanceView
```

**URLs:**
```
/suppliers/
/suppliers/create/
/suppliers/<id>/
/suppliers/<id>/edit/
/suppliers/<id>/supplies/
/suppliers/<id>/payments/
/suppliers/<id>/balance/
/supplies/
/supplies/create/
/supplies/<id>/
/payments/
/payments/create/
```

**اختبار النجاح:**
```bash
# إنشاء مورد جديد
# إنشاء توريد
# التأكد من تحديث الرصيد
```

---

### ✅ الخطوة 3.5: Views - Inventory
```
المهام:
□ إنشاء CategoryListView
□ إنشاء CategoryCreateView
□ إنشاء UnitListView
□ إنشاء ItemListView
□ إنشاء ItemCreateView
□ إنشاء ItemUpdateView
□ إنشاء ItemDetailView
□ إنشاء InventoryListView
□ إنشاء InventoryDetailView
□ إنشاء InventoryAdjustView
□ إنشاء LowStockView
□ إنشاء ExpiringItemsView
```

**URLs:**
```
/inventory/categories/
/inventory/units/
/inventory/items/
/inventory/items/create/
/inventory/items/<id>/
/inventory/stock/
/inventory/stock/<branch_id>/
/inventory/low-stock/
/inventory/expiring/
/inventory/adjust/
```

**اختبار النجاح:**
```bash
# إضافة صنف
# التأكد من ظهوره في المخزون
# اختبار تنبيه نقص المخزون
```

---

### ✅ الخطوة 3.6: Views - Transfers
```
المهام:
□ إنشاء TransferListView
□ إنشاء TransferCreateView
□ إنشاء TransferDetailView
□ إنشاء TransferApproveView
□ إنشاء TransferRejectView
□ إنشاء TransferReceiveView
□ إنشاء PendingTransfersView
```

**URLs:**
```
/transfers/
/transfers/create/
/transfers/<id>/
/transfers/<id>/approve/
/transfers/<id>/reject/
/transfers/<id>/receive/
/transfers/pending/
```

**اختبار النجاح:**
```bash
# إنشاء طلب تحويل
# الموافقة عليه
# استلامه
# التأكد من تحديث المخزون
```

---

### ✅ الخطوة 3.7: Views - Damages
```
المهام:
□ إنشاء DamageReasonListView
□ إنشاء DamageListView
□ إنشاء DamageCreateView
□ إنشاء DamageDetailView
□ إنشاء DamageApproveView
□ إنشاء DamageRejectView
□ إنشاء PendingDamagesView
```

**URLs:**
```
/damages/
/damages/create/
/damages/<id>/
/damages/<id>/approve/
/damages/<id>/reject/
/damages/pending/
/damages/reasons/
```

**اختبار النجاح:**
```bash
# تسجيل تالف
# الموافقة عليه
# التأكد من خصم المخزون
```

---

### ✅ الخطوة 3.8: Views - Returns
```
المهام:
□ إنشاء SupplierReturnListView
□ إنشاء SupplierReturnCreateView
□ إنشاء SupplierReturnDetailView
□ إنشاء SupplierReturnApproveView
□ إنشاء SupplierReturnRejectView
□ إنشاء SupplierReturnReceiveView
□ إنشاء PendingReturnsView
```

**URLs:**
```
/returns/
/returns/create/
/returns/<id>/
/returns/<id>/approve/
/returns/<id>/reject/
/returns/<id>/received/
/returns/pending/
```

**اختبار النجاح:**
```bash
# إنشاء مرتجع
# الموافقة عليه
# التأكد من تحديث رصيد المورد
```


---

### ✅ الخطوة 3.9: Views - Menu
```
المهام:
□ إنشاء MenuCategoryListView
□ إنشاء MenuCategoryCreateView
□ إنشاء MenuItemListView
□ إنشاء MenuItemCreateView
□ إنشاء MenuItemUpdateView
□ إنشاء MenuItemDetailView
□ إنشاء MenuItemIngredientsView
□ إنشاء MenuItemAvailabilityView
```

**URLs:**
```
/menu/categories/
/menu/categories/create/
/menu/items/
/menu/items/create/
/menu/items/<id>/
/menu/items/<id>/edit/
/menu/items/<id>/ingredients/
/menu/items/<id>/availability/
```

**اختبار النجاح:**
```bash
# إضافة فئة منيو
# إضافة صنف منيو مع المكونات
# التأكد من حساب التكلفة
```

---

### ✅ الخطوة 3.10: Views - Orders
```
المهام:
□ إنشاء OrderListView
□ إنشاء OrderCreateView
□ إنشاء OrderDetailView
□ إنشاء OrderStatusUpdateView
□ إنشاء OrderCancelView
□ إنشاء KitchenOrdersView
□ إنشاء TodayOrdersView
```

**URLs:**
```
/orders/
/orders/create/
/orders/<id>/
/orders/<id>/status/
/orders/<id>/cancel/
/orders/kitchen/
/orders/today/
```

**اختبار النجاح:**
```bash
# إنشاء أوردر
# تحديث حالته
# التأكد من خصم المخزون
```

---

### ✅ الخطوة 3.11: Views - POS
```
المهام:
□ إنشاء CashierPOSView
□ إنشاء KitchenPOSView
□ إنشاء QuickOrderView
□ إنشاء PaymentProcessView
□ إنشاء ReceiptPrintView
□ إنشاء DailySummaryView
```

**URLs:**
```
/pos/cashier/
/pos/kitchen/
/pos/quick-order/
/pos/payment/
/pos/receipt/<order_id>/
/pos/daily-summary/
```

**اختبار النجاح:**
```bash
# فتح شاشة الكاشير
# إنشاء أوردر سريع
# طباعة الإيصال
```

---

### ✅ الخطوة 3.12: Views - Reports
```
المهام:
□ إنشاء DashboardView
□ إنشاء InventoryReportView
□ إنشاء SalesReportView
□ إنشاء SupplierReportView
□ إنشاء DamageReportView
□ إنشاء TransferReportView
□ إنشاء DailyCountReportView
□ إنشاء ProfitLossReportView
```

**URLs:**
```
/reports/dashboard/
/reports/inventory/
/reports/sales/
/reports/suppliers/
/reports/damages/
/reports/transfers/
/reports/daily-count/
/reports/profit-loss/
```

**اختبار النجاح:**
```bash
# عرض لوحة التحكم
# تصدير تقرير المخزون
```

---

### ✅ الخطوة 3.13: Views - Daily Count (الجرد اليومي)
```
المهام:
□ إنشاء DailyCountListView
□ إنشاء DailyCountCreateView
□ إنشاء DailyCountDetailView
□ إنشاء DailyCountSubmitView
□ إنشاء DailyCountApproveView
□ إنشاء ConsumptionReportView
```

**URLs:**
```
/inventory/daily-count/
/inventory/daily-count/create/
/inventory/daily-count/<id>/
/inventory/daily-count/<id>/submit/
/inventory/daily-count/<id>/approve/
/inventory/consumption/
```

**اختبار النجاح:**
```bash
# إنشاء جرد أول اليوم
# إنشاء جرد آخر اليوم
# حساب الاستهلاك
```


---

# 🔷 المرحلة 4: Django Backend (Views & Templates)
## المدة: 5-6 أيام

### ✅ الخطوة 4.1: إعداد Base Templates
```
المهام:
□ إنشاء base.html
□ إنشاء navbar.html
□ إنشاء sidebar.html
□ إنشاء footer.html
□ إنشاء messages.html
□ إنشاء pagination.html
□ إعداد static files (CSS, JS)
□ تثبيت Bootstrap 5 RTL
□ تثبيت Font Awesome
```

**هيكل Templates:**
```
templates/
├── base.html
├── includes/
│   ├── navbar.html
│   ├── sidebar.html
│   ├── footer.html
│   ├── messages.html
│   └── pagination.html
├── accounts/
├── branches/
├── suppliers/
├── inventory/
├── transfers/
├── damages/
├── returns/
├── menu/
├── orders/
├── pos/
└── reports/
```

**اختبار النجاح:**
```bash
python manage.py runserver
# زيارة الصفحة الرئيسية والتأكد من التصميم
```

---

### ✅ الخطوة 4.2: Templates - Accounts
```
المهام:
□ إنشاء login.html
□ إنشاء profile.html
□ إنشاء change_password.html
□ إنشاء user_list.html
□ إنشاء user_form.html
□ إنشاء role_list.html
```

**اختبار النجاح:**
```bash
# تسجيل الدخول
# تعديل الملف الشخصي
# تغيير كلمة المرور
```

---

### ✅ الخطوة 4.3: Templates - Suppliers
```
المهام:
□ إنشاء supplier_list.html
□ إنشاء supplier_form.html
□ إنشاء supplier_detail.html
□ إنشاء supply_list.html
□ إنشاء supply_form.html
□ إنشاء supply_detail.html
□ إنشاء payment_list.html
□ إنشاء payment_form.html
□ إنشاء balance_report.html
```

**اختبار النجاح:**
```bash
# إضافة مورد
# إنشاء توريد
# تسجيل سداد
# عرض تقرير المديونيات
```

---

### ✅ الخطوة 4.4: Templates - Inventory
```
المهام:
□ إنشاء category_list.html
□ إنشاء item_list.html
□ إنشاء item_form.html
□ إنشاء item_detail.html
□ إنشاء inventory_list.html
□ إنشاء inventory_detail.html
□ إنشاء low_stock.html
□ إنشاء expiring_items.html
□ إنشاء adjustment_form.html
```

**اختبار النجاح:**
```bash
# إضافة صنف
# عرض المخزون
# عرض الأصناف الناقصة
```

---

### ✅ الخطوة 4.5: Templates - Operations (Transfers, Damages, Returns)
```
المهام:
□ إنشاء transfer_list.html
□ إنشاء transfer_form.html
□ إنشاء transfer_detail.html
□ إنشاء transfer_approve.html
□ إنشاء damage_list.html
□ إنشاء damage_form.html
□ إنشاء damage_detail.html
□ إنشاء return_list.html
□ إنشاء return_form.html
□ إنشاء return_detail.html
□ إنشاء pending_approvals.html
```

**اختبار النجاح:**
```bash
# إنشاء تحويل والموافقة عليه
# تسجيل تالف والموافقة عليه
# إنشاء مرتجع والموافقة عليه
```

---

### ✅ الخطوة 4.6: Templates - Menu & Orders
```
المهام:
□ إنشاء menu_category_list.html
□ إنشاء menu_item_list.html
□ إنشاء menu_item_form.html
□ إنشاء menu_item_detail.html
□ إنشاء order_list.html
□ إنشاء order_detail.html
□ إنشاء kitchen_orders.html
```

**اختبار النجاح:**
```bash
# إضافة صنف منيو
# عرض الأوردرات
```

---

### ✅ الخطوة 4.7: Templates - POS
```
المهام:
□ إنشاء cashier_pos.html (شاشة الكاشير)
□ إنشاء kitchen_pos.html (شاشة المطبخ)
□ إنشاء receipt.html (الإيصال)
□ إنشاء daily_summary.html
□ إضافة JavaScript للتفاعل
□ إضافة AJAX للأوردرات
```

**اختبار النجاح:**
```bash
# فتح شاشة الكاشير
# إنشاء أوردر
# عرضه في شاشة المطبخ
# طباعة الإيصال
```

---

### ✅ الخطوة 4.8: Templates - Reports & Dashboard
```
المهام:
□ إنشاء dashboard.html
□ إنشاء inventory_report.html
□ إنشاء sales_report.html
□ إنشاء supplier_report.html
□ إنشاء damage_report.html
□ إضافة Charts (Chart.js)
□ إضافة Export (PDF, Excel)
```

**اختبار النجاح:**
```bash
# عرض لوحة التحكم
# عرض التقارير
# تصدير تقرير
```

---

### ✅ الخطوة 4.9: Templates - Daily Count (الجرد اليومي)
```
المهام:
□ إنشاء daily_count_list.html
□ إنشاء daily_count_form.html
□ إنشاء daily_count_detail.html
□ إنشاء consumption_report.html
```

**اختبار النجاح:**
```bash
# إنشاء جرد
# حساب الاستهلاك
```


---

# 🔷 المرحلة 5: Frontend Enhancement
## المدة: 4-5 أيام

### ✅ الخطوة 5.1: إعداد Static Files
```
المهام:
□ تنظيم ملفات CSS
□ تنظيم ملفات JavaScript
□ إعداد Bootstrap 5 RTL
□ إعداد Font Awesome
□ إعداد Custom Theme
□ إعداد Dark Mode (اختياري)
```

**هيكل Static:**
```
static/
├── css/
│   ├── bootstrap.rtl.min.css
│   ├── style.css
│   ├── dashboard.css
│   ├── pos.css
│   └── print.css
├── js/
│   ├── bootstrap.bundle.min.js
│   ├── jquery.min.js
│   ├── chart.min.js
│   ├── main.js
│   ├── pos.js
│   ├── inventory.js
│   └── reports.js
├── fonts/
│   └── cairo/
├── images/
│   ├── logo.png
│   └── icons/
└── vendor/
    ├── select2/
    ├── datatables/
    └── sweetalert2/
```

**اختبار النجاح:**
```bash
python manage.py collectstatic
# التأكد من تحميل الملفات
```

---

### ✅ الخطوة 5.2: JavaScript - Core Functions
```
المهام:
□ إنشاء main.js (وظائف عامة)
□ إنشاء ajax.js (طلبات AJAX)
□ إنشاء notifications.js (الإشعارات)
□ إنشاء forms.js (التحقق من النماذج)
□ إنشاء tables.js (DataTables)
□ إنشاء modals.js (النوافذ المنبثقة)
```

**اختبار النجاح:**
```bash
# اختبار الإشعارات
# اختبار التحقق من النماذج
# اختبار الجداول
```

---

### ✅ الخطوة 5.3: JavaScript - POS System
```
المهام:
□ إنشاء pos.js
□ إضافة وظيفة إضافة صنف للأوردر
□ إضافة وظيفة حذف صنف
□ إضافة وظيفة تعديل الكمية
□ إضافة وظيفة حساب الإجمالي
□ إضافة وظيفة الدفع
□ إضافة وظيفة طباعة الإيصال
□ إضافة Keyboard Shortcuts
□ إضافة Barcode Scanner Support
```

**اختبار النجاح:**
```bash
# اختبار شاشة الكاشير كاملة
# اختبار الاختصارات
```

---

### ✅ الخطوة 5.4: JavaScript - Kitchen Display
```
المهام:
□ إنشاء kitchen.js
□ إضافة Real-time Updates (Polling/WebSocket)
□ إضافة وظيفة تحديث حالة الأوردر
□ إضافة Sound Notifications
□ إضافة Auto-refresh
```

**اختبار النجاح:**
```bash
# فتح شاشة المطبخ
# إنشاء أوردر من الكاشير
# التأكد من ظهوره في المطبخ
```

---

### ✅ الخطوة 5.5: JavaScript - Inventory Management
```
المهام:
□ إنشاء inventory.js
□ إضافة Dynamic Item Selection
□ إضافة Quantity Validation
□ إضافة Auto-complete للأصناف
□ إضافة Batch Selection
□ إضافة Stock Alerts
```

**اختبار النجاح:**
```bash
# اختبار إضافة توريد
# اختبار إنشاء تحويل
# اختبار تسجيل تالف
```

---

### ✅ الخطوة 5.6: JavaScript - Reports & Charts
```
المهام:
□ إنشاء reports.js
□ إضافة Chart.js للرسوم البيانية
□ إضافة Date Range Picker
□ إضافة Export Functions (PDF, Excel)
□ إضافة Print Functions
□ إضافة Filter & Search
```

**اختبار النجاح:**
```bash
# عرض لوحة التحكم
# تصدير تقرير PDF
# تصدير تقرير Excel
```

---

### ✅ الخطوة 5.7: Responsive Design
```
المهام:
□ اختبار على الموبايل
□ اختبار على التابلت
□ اختبار على الديسكتوب
□ تعديل CSS للشاشات الصغيرة
□ تعديل POS للتابلت
□ إخفاء/إظهار العناصر حسب الشاشة
```

**اختبار النجاح:**
```bash
# اختبار على أحجام شاشات مختلفة
# التأكد من عمل POS على التابلت
```

---

### ✅ الخطوة 5.8: Print Templates
```
المهام:
□ إنشاء receipt_print.html (إيصال الأوردر)
□ إنشاء kitchen_ticket.html (تذكرة المطبخ)
□ إنشاء report_print.html (طباعة التقارير)
□ إنشاء barcode_print.html (طباعة الباركود)
□ إعداد print.css
□ اختبار الطباعة
```

**اختبار النجاح:**
```bash
# طباعة إيصال
# طباعة تقرير
```


---

# 🔷 المرحلة 6: Testing & Quality Assurance
## المدة: 3-4 أيام

### ✅ الخطوة 6.1: Unit Tests - Models
```
المهام:
□ اختبار User Model
□ اختبار Supplier Model
□ اختبار Item Model
□ اختبار Inventory Model
□ اختبار Order Model
□ اختبار جميع العلاقات
□ اختبار Constraints
```

**الملفات:**
```
tests/
├── test_models/
│   ├── test_accounts.py
│   ├── test_suppliers.py
│   ├── test_inventory.py
│   └── test_orders.py
```

**اختبار النجاح:**
```bash
python manage.py test tests.test_models
```

---

### ✅ الخطوة 6.2: Unit Tests - Services
```
المهام:
□ اختبار InventoryService
□ اختبار SupplyService
□ اختبار TransferService
□ اختبار DamageService
□ اختبار OrderService
□ اختبار Business Logic
```

**اختبار النجاح:**
```bash
python manage.py test tests.test_services
```

---

### ✅ الخطوة 6.3: Integration Tests
```
المهام:
□ اختبار سيناريو التوريد الكامل
□ اختبار سيناريو التحويل الكامل
□ اختبار سيناريو التالف الكامل
□ اختبار سيناريو المرتجع الكامل
□ اختبار سيناريو الأوردر الكامل
□ اختبار سيناريو الجرد اليومي
```

**اختبار النجاح:**
```bash
python manage.py test tests.test_integration
```

---

### ✅ الخطوة 6.4: View Tests
```
المهام:
□ اختبار Authentication
□ اختبار Authorization
□ اختبار CRUD Operations
□ اختبار Form Validation
□ اختبار Error Handling
```

**اختبار النجاح:**
```bash
python manage.py test tests.test_views
```

---

### ✅ الخطوة 6.5: Manual Testing
```
المهام:
□ اختبار جميع الشاشات
□ اختبار جميع النماذج
□ اختبار الصلاحيات
□ اختبار POS
□ اختبار التقارير
□ اختبار الطباعة
□ توثيق الأخطاء
□ إصلاح الأخطاء
```

**Checklist:**
```
[ ] تسجيل الدخول/الخروج
[ ] إدارة المستخدمين
[ ] إدارة الفروع
[ ] إدارة الموردين
[ ] إدارة التوريدات
[ ] إدارة المديونيات
[ ] إدارة الأصناف
[ ] إدارة المخزون
[ ] إدارة التحويلات
[ ] إدارة التالف
[ ] إدارة المرتجعات
[ ] إدارة المنيو
[ ] نظام POS
[ ] شاشة المطبخ
[ ] الجرد اليومي
[ ] التقارير
[ ] الإشعارات
```

---

# 🔷 المرحلة 7: Deployment & Production
## المدة: 2-3 أيام

### ✅ الخطوة 7.1: إعداد Production Settings
```
المهام:
□ إعداد DEBUG = False
□ إعداد ALLOWED_HOSTS
□ إعداد SECRET_KEY
□ إعداد Database Production
□ إعداد Static Files
□ إعداد Media Files
□ إعداد Email
□ إعداد Logging
□ إعداد Security Settings
```

---

### ✅ الخطوة 7.2: إعداد السيرفر
```
المهام:
□ إعداد Linux Server
□ تثبيت Python
□ تثبيت PostgreSQL
□ تثبيت Nginx
□ تثبيت Gunicorn
□ إعداد Virtual Environment
□ إعداد Supervisor
□ إعداد SSL Certificate
```

---

### ✅ الخطوة 7.3: Deployment
```
المهام:
□ رفع الكود للسيرفر
□ تثبيت Dependencies
□ تشغيل Migrations
□ جمع Static Files
□ إنشاء Superuser
□ تشغيل الخدمات
□ اختبار الموقع
```

---

### ✅ الخطوة 7.4: Backup & Monitoring
```
المهام:
□ إعداد Database Backup
□ إعداد Media Backup
□ إعداد Monitoring (Sentry)
□ إعداد Uptime Monitoring
□ توثيق إجراءات الطوارئ
```


---

# 📊 ملخص الخطة

## الجدول الزمني

| المرحلة | المدة | الأسبوع |
|---------|-------|---------|
| المرحلة 1: Database & Models | 3-4 أيام | الأسبوع 1 |
| المرحلة 2: Serializers & Services | 4-5 أيام | الأسبوع 2 |
| المرحلة 3: URLs & Views | 5-6 أيام | الأسبوع 3-4 |
| المرحلة 4: Django Templates | 5-6 أيام | الأسبوع 4-5 |
| المرحلة 5: Frontend Enhancement | 4-5 أيام | الأسبوع 6 |
| المرحلة 6: Testing | 3-4 أيام | الأسبوع 7 |
| المرحلة 7: Deployment | 2-3 أيام | الأسبوع 8 |

**المجموع: 8-10 أسابيع**

---

## الأولويات

### 🔴 أولوية عالية (يجب إنهاؤها أولاً)
1. إعداد المشروع والـ Database
2. Models الأساسية (Users, Branches, Suppliers, Items, Inventory)
3. نظام التوريدات
4. نظام المخزون
5. نظام POS الأساسي

### 🟡 أولوية متوسطة
6. نظام التحويلات
7. نظام التالف
8. نظام المرتجعات
9. الجرد اليومي
10. التقارير الأساسية

### 🟢 أولوية منخفضة (يمكن تأجيلها)
11. التقارير المتقدمة
12. الإشعارات
13. Dark Mode
14. تحسينات الأداء

---

## Dependencies (المتطلبات)

### Python Packages
```
Django>=4.2
psycopg2-binary
python-decouple
Pillow
django-crispy-forms
crispy-bootstrap5
django-filter
django-widget-tweaks
django-extensions
whitenoise
gunicorn
```

### Frontend Libraries
```
Bootstrap 5.3 RTL
jQuery 3.7
Chart.js 4.x
DataTables 1.13
Select2 4.1
SweetAlert2
Font Awesome 6
```

---

## ملفات مهمة للإنشاء

```
□ requirements/base.txt
□ requirements/development.txt
□ requirements/production.txt
□ .env.example
□ .gitignore
□ README.md
□ docker-compose.yml (اختياري)
□ Dockerfile (اختياري)
```

---

## نصائح مهمة

1. **ابدأ بالـ Models** - تأكد من صحة العلاقات قبل المتابعة
2. **اختبر كل خطوة** - لا تنتقل للخطوة التالية قبل التأكد من نجاح الحالية
3. **استخدم Git** - احفظ التغييرات بانتظام
4. **وثق الكود** - اكتب تعليقات واضحة
5. **اتبع DRY** - لا تكرر الكود
6. **الأمان أولاً** - تحقق من المدخلات دائماً

---

## الخطوة التالية

ابدأ بـ **الخطوة 1.1: إنشاء مشروع Django**

```bash
# الأوامر للبدء
mkdir restaurant_system
cd restaurant_system
python -m venv venv
venv\Scripts\activate
pip install django psycopg2-binary python-decouple
django-admin startproject config .
```

---

> 📝 **ملاحظة:** هذه الخطة قابلة للتعديل حسب الاحتياجات. يمكن إضافة أو حذف خطوات حسب المتطلبات.
