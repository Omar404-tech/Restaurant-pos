"""
Deep Test Script for Restaurant System
Tests all 4 Phases: Models, Serializers, API Views, Template Views
"""
import os
import sys
import django

# Setup Django
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
django.setup()

from django.test import TestCase, Client
from django.urls import reverse, resolve
from rest_framework.test import APIClient
from rest_framework import status
import json

# Import all models
from apps.core.models import Category, Unit, DamageReason, SystemSetting
from apps.accounts.models import User, Role, Notification, AuditLog
from apps.branches.models import Branch
from apps.suppliers.models import Supplier, Supply, SupplyItem, SupplierPayment
from apps.inventory.models import Item, Inventory, InventoryTransaction, DailyInventoryCount
from apps.transfers.models import Transfer, TransferItem
from apps.damages.models import Damage
from apps.returns.models import SupplierReturn, BranchReturn, BranchReturnItem
from apps.menu.models import MenuCategory, MenuItem, MenuItemIngredient
from apps.orders.models import Order, OrderItem

# Import serializers
from apps.core.serializers import CategorySerializer, UnitSerializer
from apps.accounts.serializers import UserSerializer, RoleSerializer
from apps.branches.serializers import BranchSerializer
from apps.suppliers.serializers import SupplierSerializer, SupplySerializer
from apps.inventory.serializers import ItemSerializer, InventorySerializer
from apps.transfers.serializers import TransferSerializer
from apps.damages.serializers import DamageSerializer
from apps.returns.serializers import SupplierReturnSerializer, BranchReturnSerializer
from apps.menu.serializers import MenuCategorySerializer, MenuItemSerializer
from apps.orders.serializers import OrderSerializer


class Colors:
    GREEN = '\033[92m'
    RED = '\033[91m'
    YELLOW = '\033[93m'
    BLUE = '\033[94m'
    BOLD = '\033[1m'
    END = '\033[0m'


def print_header(text):
    print(f"\n{Colors.BOLD}{Colors.BLUE}{'='*60}{Colors.END}")
    print(f"{Colors.BOLD}{Colors.BLUE}{text.center(60)}{Colors.END}")
    print(f"{Colors.BOLD}{Colors.BLUE}{'='*60}{Colors.END}\n")


def print_success(text):
    print(f"{Colors.GREEN}[OK] {text}{Colors.END}")


def print_error(text):
    print(f"{Colors.RED}[FAIL] {text}{Colors.END}")


def print_info(text):
    print(f"{Colors.YELLOW}>> {text}{Colors.END}")


class DeepTest:
    def __init__(self):
        self.client = Client()
        self.api_client = APIClient()
        self.results = {'passed': 0, 'failed': 0, 'errors': []}
        self.user = None
        self.branch = None
        
    def setup(self):
        """Setup test data"""
        print_header("SETUP TEST DATA")
        
        try:
            # Get or create admin user
            self.user = User.objects.filter(username='admin').first()
            if not self.user:
                self.user = User.objects.create_superuser(
                    username='admin',
                    email='admin@test.com',
                    password='admin123',
                    full_name='Admin User'
                )
            print_success(f"Admin user ready: {self.user.username}")
            
            # Get or create branch
            self.branch = Branch.objects.first()
            if not self.branch:
                self.branch = Branch.objects.create(
                    code='MAIN',
                    name='Main Branch',
                    branch_type='main'
                )
            print_success(f"Branch ready: {self.branch.name}")
            
            # Assign branch to user
            if not self.user.branch:
                self.user.branch = self.branch
                self.user.save()
            
            return True
        except Exception as e:
            print_error(f"Setup failed: {e}")
            return False

    # ==================== PHASE 1: MODELS ====================
    def test_models(self):
        print_header("PHASE 1: MODELS TEST")
        
        models_to_test = [
            ('Core - Category', Category, {'name': 'Test Category', 'code': 'TC001'}),
            ('Core - Unit', Unit, {'name': 'Kilogram', 'code': 'KG', 'symbol': 'kg'}),
            ('Core - DamageReason', DamageReason, {'name': 'Expired', 'code': 'EXP'}),
            ('Accounts - Role', Role, {'name': 'Test Role'}),
            ('Branches - Branch', Branch, {'name': 'Test Branch', 'code': 'TB001'}),
            ('Suppliers - Supplier', Supplier, {'name': 'Test Supplier', 'code': 'TS001'}),
            ('Inventory - Item', Item, {'name': 'Test Item', 'code': 'TI001'}),
            ('Menu - MenuCategory', MenuCategory, {'name': 'Test Menu Cat', 'code': 'TMC01'}),
            ('Menu - MenuItem', MenuItem, {'name': 'Test Menu Item', 'code': 'TMI01', 'price': 100}),
        ]
        
        for name, model, data in models_to_test:
            try:
                # Check if exists, if not create
                filter_key = 'code' if 'code' in data else 'name'
                obj = model.objects.filter(**{filter_key: data.get(filter_key)}).first()
                if not obj:
                    obj = model.objects.create(**data)
                print_success(f"{name}: Created/Found - {obj}")
                self.results['passed'] += 1
            except Exception as e:
                print_error(f"{name}: {e}")
                self.results['failed'] += 1
                self.results['errors'].append(f"{name}: {e}")
        
        # Test relationships
        print_info("Testing Model Relationships...")
        
        try:
            # Test Inventory relationship
            item = Item.objects.first()
            if item and self.branch:
                inv, created = Inventory.objects.get_or_create(
                    item=item,
                    branch=self.branch,
                    defaults={'quantity': 100, 'min_quantity': 10}
                )
                print_success(f"Inventory relationship: {inv.item.name} @ {inv.branch.name}")
                self.results['passed'] += 1
        except Exception as e:
            print_error(f"Inventory relationship: {e}")
            self.results['failed'] += 1
        
        try:
            import uuid
            # Test Order relationship
            menu_item = MenuItem.objects.first()
            if menu_item and self.branch:
                order_num = f'ORD-REL-{str(uuid.uuid4())[:8].upper()}'
                order = Order.objects.create(
                    order_number=order_num,
                    branch=self.branch,
                    order_type='dine_in',
                    cashier=self.user
                )
                order_item = OrderItem.objects.create(
                    order=order,
                    menu_item=menu_item,
                    quantity=2,
                    unit_price=menu_item.price
                )
                print_success(f"Order relationship: {order.order_number} with {order_item.menu_item.name}")
                self.results['passed'] += 1
        except Exception as e:
            print_error(f"Order relationship: {e}")
            self.results['failed'] += 1

    # ==================== PHASE 2: SERIALIZERS ====================
    def test_serializers(self):
        print_header("PHASE 2: SERIALIZERS TEST")
        
        serializers_to_test = [
            ('CategorySerializer', CategorySerializer, Category),
            ('UnitSerializer', UnitSerializer, Unit),
            ('RoleSerializer', RoleSerializer, Role),
            ('BranchSerializer', BranchSerializer, Branch),
            ('SupplierSerializer', SupplierSerializer, Supplier),
            ('ItemSerializer', ItemSerializer, Item),
            ('MenuCategorySerializer', MenuCategorySerializer, MenuCategory),
            ('MenuItemSerializer', MenuItemSerializer, MenuItem),
        ]
        
        for name, serializer_class, model in serializers_to_test:
            try:
                obj = model.objects.first()
                if obj:
                    serializer = serializer_class(obj)
                    data = serializer.data
                    assert 'id' in data or 'code' in data or 'name' in data
                    print_success(f"{name}: Serialized {model.__name__} successfully")
                    self.results['passed'] += 1
                else:
                    print_info(f"{name}: No {model.__name__} data to test")
            except Exception as e:
                print_error(f"{name}: {e}")
                self.results['failed'] += 1
                self.results['errors'].append(f"{name}: {e}")
        
        # Test nested serializers
        print_info("Testing Nested Serializers...")
        
        try:
            order = Order.objects.first()
            if order:
                serializer = OrderSerializer(order)
                data = serializer.data
                print_success(f"OrderSerializer with nested items: {len(data.get('items', []))} items")
                self.results['passed'] += 1
        except Exception as e:
            print_error(f"OrderSerializer nested: {e}")
            self.results['failed'] += 1

    # ==================== PHASE 3: API VIEWS ====================
    def test_api_views(self):
        print_header("PHASE 3: API VIEWS TEST")
        
        # Login first
        self.api_client.force_authenticate(user=self.user)
        
        api_endpoints = [
            ('GET', '/api/categories/', 'Categories List'),
            ('GET', '/api/units/', 'Units List'),
            ('GET', '/api/accounts/users/', 'Users List'),
            ('GET', '/api/accounts/roles/', 'Roles List'),
            ('GET', '/api/branches/', 'Branches List'),
            ('GET', '/api/suppliers/', 'Suppliers List'),
            ('GET', '/api/inventory/items/', 'Items List'),
            ('GET', '/api/inventory/stock/', 'Inventory List'),
            ('GET', '/api/transfers/', 'Transfers List'),
            ('GET', '/api/damages/', 'Damages List'),
            ('GET', '/api/returns/supplier/', 'Supplier Returns List'),
            ('GET', '/api/returns/branch/', 'Branch Returns List'),
            ('GET', '/api/menu/categories/', 'Menu Categories List'),
            ('GET', '/api/menu/items/', 'Menu Items List'),
            ('GET', '/api/orders/', 'Orders List'),
        ]
        
        for method, url, name in api_endpoints:
            try:
                if method == 'GET':
                    response = self.api_client.get(url)
                
                if response.status_code in [200, 201]:
                    print_success(f"{name} ({url}): {response.status_code}")
                    self.results['passed'] += 1
                else:
                    print_error(f"{name} ({url}): {response.status_code}")
                    self.results['failed'] += 1
            except Exception as e:
                print_error(f"{name}: {e}")
                self.results['failed'] += 1
                self.results['errors'].append(f"{name}: {e}")
        
        # Test CRUD operations
        print_info("Testing API CRUD Operations...")
        
        try:
            import uuid
            # Create Category
            response = self.api_client.post('/api/categories/', {
                'name': 'API Test Category',
                'name_ar': 'فئة اختبار',
                'code': f'ATC{str(uuid.uuid4())[:4].upper()}'
            })
            if response.status_code in [200, 201]:
                print_success(f"POST /api/categories/: Created category")
                self.results['passed'] += 1
            else:
                print_error(f"POST /api/categories/: {response.status_code} - {response.data}")
                self.results['failed'] += 1
        except Exception as e:
            print_error(f"POST /api/categories/: {e}")
            self.results['failed'] += 1

    # ==================== PHASE 4: TEMPLATE VIEWS ====================
    def test_template_views(self):
        print_header("PHASE 4: TEMPLATE VIEWS TEST")
        
        # Login
        self.client.login(username='admin', password='admin123')
        
        template_urls = [
            ('/', 'Dashboard'),
            ('/accounts/profile/', 'Profile'),
            ('/accounts/users/', 'Users List'),
            ('/accounts/roles/', 'Roles List'),
            ('/branches/', 'Branches List'),
            ('/suppliers/', 'Suppliers List'),
            ('/suppliers/supplies/', 'Supplies List'),
            ('/suppliers/payments/', 'Payments List'),
            ('/inventory/items/', 'Items List'),
            ('/inventory/stock/', 'Stock List'),
            ('/inventory/low-stock/', 'Low Stock'),
            ('/inventory/daily-count/', 'Daily Count'),
            ('/transfers/', 'Transfers List'),
            ('/damages/', 'Damages List'),
            ('/returns/supplier/', 'Supplier Returns'),
            ('/returns/branch/', 'Branch Returns'),
            ('/menu/', 'Menu Items'),
            ('/menu/categories/', 'Menu Categories'),
            ('/orders/', 'Orders List'),
            ('/pos/cashier/', 'POS Cashier'),
            ('/pos/kitchen/', 'Kitchen Display'),
            ('/reports/', 'Reports Index'),
            ('/reports/sales/', 'Sales Report'),
            ('/reports/inventory/', 'Inventory Report'),
            ('/reports/suppliers/', 'Suppliers Report'),
        ]
        
        for url, name in template_urls:
            try:
                response = self.client.get(url)
                if response.status_code == 200:
                    print_success(f"{name} ({url}): {response.status_code}")
                    self.results['passed'] += 1
                elif response.status_code == 302:
                    print_info(f"{name} ({url}): Redirect (302)")
                    self.results['passed'] += 1
                else:
                    print_error(f"{name} ({url}): {response.status_code}")
                    self.results['failed'] += 1
            except Exception as e:
                print_error(f"{name}: {e}")
                self.results['failed'] += 1
                self.results['errors'].append(f"{name}: {e}")
        
        # Test form submissions
        print_info("Testing Form Submissions...")
        
        try:
            import uuid
            # Test branch creation
            response = self.client.post('/branches/create/', {
                'code': f'TB{str(uuid.uuid4())[:4].upper()}',
                'name': 'Test Branch Form',
                'branch_type': 'branch'
            })
            if response.status_code in [200, 302]:
                print_success("Branch creation form: Success")
                self.results['passed'] += 1
            else:
                print_error(f"Branch creation form: {response.status_code}")
                self.results['failed'] += 1
        except Exception as e:
            print_error(f"Branch creation form: {e}")
            self.results['failed'] += 1

    # ==================== FLOW TESTS ====================
    def test_business_flows(self):
        print_header("BUSINESS FLOW TESTS")
        
        self.api_client.force_authenticate(user=self.user)
        import uuid
        
        # Flow 1: Supply Flow
        print_info("Testing Supply Flow...")
        try:
            supplier = Supplier.objects.first()
            item = Item.objects.first()
            
            if supplier and item and self.branch:
                supply_num = f'SUP-TEST-{str(uuid.uuid4())[:8].upper()}'
                supply = Supply.objects.create(
                    supply_number=supply_num,
                    supplier=supplier,
                    branch=self.branch,
                    received_by=self.user
                )
                supply_item = SupplyItem.objects.create(
                    supply=supply,
                    item=item,
                    quantity=50,
                    unit_price=10,
                    total_price=500
                )
                print_success(f"Supply Flow: Created supply {supply.supply_number} with {supply_item.quantity} items")
                self.results['passed'] += 1
        except Exception as e:
            print_error(f"Supply Flow: {e}")
            self.results['failed'] += 1
        
        # Flow 2: Transfer Flow
        print_info("Testing Transfer Flow...")
        try:
            branches = Branch.objects.all()[:2]
            if len(branches) >= 2:
                transfer_num = f'TRF-TEST-{str(uuid.uuid4())[:8].upper()}'
                transfer = Transfer.objects.create(
                    transfer_number=transfer_num,
                    from_branch=branches[0],
                    to_branch=branches[1],
                    requested_by=self.user
                )
                print_success(f"Transfer Flow: Created transfer {transfer.transfer_number}")
                self.results['passed'] += 1
        except Exception as e:
            print_error(f"Transfer Flow: {e}")
            self.results['failed'] += 1
        
        # Flow 3: Order Flow
        print_info("Testing Order Flow...")
        try:
            menu_item = MenuItem.objects.first()
            if menu_item and self.branch:
                order_num = f'ORD-TEST-{str(uuid.uuid4())[:8].upper()}'
                order = Order.objects.create(
                    order_number=order_num,
                    branch=self.branch,
                    order_type='dine_in',
                    cashier=self.user,
                    status='pending'
                )
                OrderItem.objects.create(
                    order=order,
                    menu_item=menu_item,
                    quantity=1,
                    unit_price=menu_item.price
                )
                # Update status
                order.status = 'preparing'
                order.save()
                print_success(f"Order Flow: Created order {order.order_number}, status: {order.status}")
                self.results['passed'] += 1
        except Exception as e:
            print_error(f"Order Flow: {e}")
            self.results['failed'] += 1
        
        # Flow 4: Damage Flow
        print_info("Testing Damage Flow...")
        try:
            item = Item.objects.first()
            reason = DamageReason.objects.first()
            if item and self.branch:
                damage_num = f'DMG-TEST-{str(uuid.uuid4())[:8].upper()}'
                damage = Damage.objects.create(
                    damage_number=damage_num,
                    branch=self.branch,
                    item=item,
                    quantity=5,
                    unit_cost=10,
                    total_cost=50,
                    reason=reason,
                    registered_by=self.user
                )
                print_success(f"Damage Flow: Created damage {damage.damage_number}")
                self.results['passed'] += 1
        except Exception as e:
            print_error(f"Damage Flow: {e}")
            self.results['failed'] += 1

    def print_summary(self):
        print_header("TEST SUMMARY")
        
        total = self.results['passed'] + self.results['failed']
        pass_rate = (self.results['passed'] / total * 100) if total > 0 else 0
        
        print(f"{Colors.GREEN}Passed: {self.results['passed']}{Colors.END}")
        print(f"{Colors.RED}Failed: {self.results['failed']}{Colors.END}")
        print(f"{Colors.BOLD}Total: {total}{Colors.END}")
        print(f"{Colors.BOLD}Pass Rate: {pass_rate:.1f}%{Colors.END}")
        
        if self.results['errors']:
            print(f"\n{Colors.RED}Errors:{Colors.END}")
            for error in self.results['errors'][:10]:
                print(f"  - {error}")
        
        return self.results['failed'] == 0

    def run_all_tests(self):
        print_header("RESTAURANT SYSTEM DEEP TEST")
        print("Testing all 4 Phases: Models, Serializers, API Views, Templates\n")
        
        if not self.setup():
            print_error("Setup failed, aborting tests")
            return False
        
        self.test_models()
        self.test_serializers()
        self.test_api_views()
        self.test_template_views()
        self.test_business_flows()
        
        return self.print_summary()


if __name__ == '__main__':
    tester = DeepTest()
    success = tester.run_all_tests()
    sys.exit(0 if success else 1)
