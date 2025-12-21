from rest_framework.views import APIView
from rest_framework.response import Response
from django_filters.rest_framework import DjangoFilterBackend
from django.utils import timezone
from django.db.models import Sum, Count, F
from datetime import date, timedelta

from apps.inventory.models import Inventory, InventoryTransaction, Item
from apps.orders.models import Order, OrderItem
from apps.suppliers.models import Supplier, Supply, SupplierPayment
from apps.damages.models import Damage
from apps.transfers.models import Transfer
from apps.accounts.models import Notification
from .serializers import (
    DateRangeSerializer, InventoryReportSerializer, SalesReportSerializer,
    SupplierReportSerializer, DamageReportSerializer, TransferReportSerializer,
    DashboardSummarySerializer, TopSellingItemSerializer
)


class DashboardView(APIView):
    def get(self, request):
        branch = request.user.branch
        today = date.today()
        
        # Today's sales
        orders_today = Order.objects.filter(created_at__date=today)
        if branch:
            orders_today = orders_today.filter(branch=branch)
        
        paid_orders = orders_today.exclude(status='cancelled')
        
        # Pending items
        pending_transfers = Transfer.objects.filter(status='pending').count()
        pending_damages = Damage.objects.filter(status='pending').count()
        
        # Low stock
        low_stock_query = Inventory.objects.filter(quantity__lte=F('min_quantity'))
        if branch:
            low_stock_query = low_stock_query.filter(branch=branch)
        
        # Expiring items (next 30 days)
        from apps.inventory.models import InventoryBatch
        expiry_date = today + timedelta(days=30)
        expiring_query = InventoryBatch.objects.filter(
            expiry_date__lte=expiry_date, remaining_quantity__gt=0
        )
        
        # Purchase requests
        from apps.suppliers.models import PurchaseRequest
        pending_pr = PurchaseRequest.objects.filter(status='pending').count()
        
        # Notifications
        unread = Notification.objects.filter(user=request.user, is_read=False).count()
        
        data = {
            'total_sales_today': paid_orders.aggregate(total=Sum('total_amount'))['total'] or 0,
            'total_orders_today': paid_orders.count(),
            'pending_transfers': pending_transfers,
            'pending_damages': pending_damages,
            'low_stock_items': low_stock_query.count(),
            'expiring_items': expiring_query.count(),
            'pending_purchase_requests': pending_pr,
            'unread_notifications': unread
        }
        
        return Response(DashboardSummarySerializer(data).data)


class InventoryReportView(APIView):
    def get(self, request):
        branch_id = request.query_params.get('branch')
        category_id = request.query_params.get('category')
        
        queryset = Inventory.objects.select_related('branch', 'item', 'item__category', 'item__unit')
        
        if branch_id:
            queryset = queryset.filter(branch_id=branch_id)
        if category_id:
            queryset = queryset.filter(item__category_id=category_id)
        
        data = [{
            'branch_code': inv.branch.code,
            'branch_name': inv.branch.name,
            'item_code': inv.item.code,
            'item_name': inv.item.name,
            'category_name': inv.item.category.name if inv.item.category else '',
            'unit_name': inv.item.unit.name if inv.item.unit else '',
            'current_quantity': inv.quantity,
            'min_quantity': inv.min_quantity,
            'purchase_price': inv.item.purchase_price,
            'total_value': inv.quantity * inv.item.purchase_price,
            'is_low_stock': inv.quantity <= inv.min_quantity
        } for inv in queryset]
        
        return Response(InventoryReportSerializer(data, many=True).data)


class SalesReportView(APIView):
    def get(self, request):
        start_date = request.query_params.get('start_date', date.today() - timedelta(days=30))
        end_date = request.query_params.get('end_date', date.today())
        branch_id = request.query_params.get('branch')
        
        queryset = Order.objects.filter(
            created_at__date__gte=start_date,
            created_at__date__lte=end_date
        ).exclude(status='cancelled')
        
        if branch_id:
            queryset = queryset.filter(branch_id=branch_id)
        
        # Group by date and branch
        from django.db.models.functions import TruncDate
        
        summary = queryset.annotate(
            order_date=TruncDate('created_at')
        ).values('order_date', 'branch__code', 'branch__name').annotate(
            total_orders=Count('id'),
            total_items=Sum('items__quantity'),
            subtotal=Sum('subtotal'),
            tax_amount=Sum('tax_amount'),
            discount_amount=Sum('discount_amount'),
            total_amount=Sum('total_amount')
        ).order_by('-order_date')
        
        data = [{
            'date': row['order_date'],
            'branch_code': row['branch__code'],
            'branch_name': row['branch__name'],
            'total_orders': row['total_orders'],
            'total_items': row['total_items'] or 0,
            'subtotal': row['subtotal'] or 0,
            'tax_amount': row['tax_amount'] or 0,
            'discount_amount': row['discount_amount'] or 0,
            'total_amount': row['total_amount'] or 0,
            'cash_amount': 0,
            'visa_amount': 0,
            'cancelled_orders': 0
        } for row in summary]
        
        return Response(SalesReportSerializer(data, many=True).data)


class SupplierReportView(APIView):
    def get(self, request):
        suppliers = Supplier.objects.all()
        
        data = []
        for supplier in suppliers:
            supplies_total = supplier.supplies.aggregate(total=Sum('total_amount'))['total'] or 0
            payments_total = supplier.payments.aggregate(total=Sum('amount'))['total'] or 0
            
            data.append({
                'supplier_code': supplier.code,
                'supplier_name': supplier.name,
                'total_supplies': supplier.supplies.count(),
                'total_supply_amount': supplies_total,
                'total_payments': supplier.payments.count(),
                'total_payment_amount': payments_total,
                'current_balance': supplier.current_balance
            })
        
        return Response(SupplierReportSerializer(data, many=True).data)


class DamageReportView(APIView):
    def get(self, request):
        start_date = request.query_params.get('start_date', date.today() - timedelta(days=30))
        end_date = request.query_params.get('end_date', date.today())
        branch_id = request.query_params.get('branch')
        
        queryset = Damage.objects.filter(
            created_at__date__gte=start_date,
            created_at__date__lte=end_date,
            status='approved'
        )
        
        if branch_id:
            queryset = queryset.filter(branch_id=branch_id)
        
        summary = queryset.values(
            'branch__code', 'branch__name', 'item__code', 'item__name', 'reason__name'
        ).annotate(
            total_quantity=Sum('quantity'),
            total_cost=Sum('total_cost'),
            count=Count('id')
        )
        
        data = [{
            'branch_code': row['branch__code'],
            'branch_name': row['branch__name'],
            'item_code': row['item__code'],
            'item_name': row['item__name'],
            'reason_name': row['reason__name'],
            'total_quantity': row['total_quantity'],
            'total_cost': row['total_cost'],
            'count': row['count']
        } for row in summary]
        
        return Response(DamageReportSerializer(data, many=True).data)


class TransferReportView(APIView):
    def get(self, request):
        start_date = request.query_params.get('start_date', date.today() - timedelta(days=30))
        end_date = request.query_params.get('end_date', date.today())
        
        queryset = Transfer.objects.filter(
            created_at__date__gte=start_date,
            created_at__date__lte=end_date
        )
        
        summary = queryset.values(
            'from_branch__code', 'from_branch__name', 'to_branch__code', 'to_branch__name'
        ).annotate(
            total_transfers=Count('id'),
            total_items=Count('items'),
            pending_count=Count('id', filter=F('status') == 'pending'),
            approved_count=Count('id', filter=F('status') == 'approved'),
            received_count=Count('id', filter=F('status') == 'received')
        )
        
        data = [{
            'from_branch_code': row['from_branch__code'],
            'from_branch_name': row['from_branch__name'],
            'to_branch_code': row['to_branch__code'],
            'to_branch_name': row['to_branch__name'],
            'total_transfers': row['total_transfers'],
            'total_items': row['total_items'],
            'pending_count': row.get('pending_count', 0),
            'approved_count': row.get('approved_count', 0),
            'received_count': row.get('received_count', 0)
        } for row in summary]
        
        return Response(TransferReportSerializer(data, many=True).data)


class TopSellingItemsView(APIView):
    def get(self, request):
        start_date = request.query_params.get('start_date', date.today() - timedelta(days=30))
        end_date = request.query_params.get('end_date', date.today())
        branch_id = request.query_params.get('branch')
        limit = int(request.query_params.get('limit', 10))
        
        queryset = OrderItem.objects.filter(
            order__created_at__date__gte=start_date,
            order__created_at__date__lte=end_date
        ).exclude(order__status='cancelled')
        
        if branch_id:
            queryset = queryset.filter(order__branch_id=branch_id)
        
        top_items = queryset.values(
            'menu_item__code', 'menu_item__name', 'menu_item__category__name'
        ).annotate(
            total_quantity=Sum('quantity'),
            total_amount=Sum('total_price')
        ).order_by('-total_quantity')[:limit]
        
        data = [{
            'item_code': row['menu_item__code'],
            'item_name': row['menu_item__name'],
            'category_name': row['menu_item__category__name'] or '',
            'total_quantity': row['total_quantity'],
            'total_amount': row['total_amount']
        } for row in top_items]
        
        return Response(TopSellingItemSerializer(data, many=True).data)
