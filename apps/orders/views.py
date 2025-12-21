from rest_framework import generics, status
from rest_framework.views import APIView
from rest_framework.response import Response
from django_filters.rest_framework import DjangoFilterBackend
from rest_framework.filters import SearchFilter, OrderingFilter
from django.utils import timezone
from django.db.models import Sum, Count
from datetime import date

from .models import Order, OrderItem
from .serializers import (
    OrderSerializer, OrderListSerializer, OrderCreateSerializer,
    OrderItemSerializer, OrderStatusUpdateSerializer, OrderCancelSerializer,
    KitchenOrderSerializer, DailySalesSerializer
)
from apps.inventory.models import Inventory, InventoryTransaction


# Order Views
class OrderListCreateView(generics.ListCreateAPIView):
    queryset = Order.objects.all()
    filter_backends = [DjangoFilterBackend, SearchFilter, OrderingFilter]
    search_fields = ['order_number', 'customer_name', 'customer_phone']
    ordering_fields = ['created_at', 'total_amount']
    filterset_fields = ['branch', 'status', 'order_type', 'payment_method']
    
    def get_serializer_class(self):
        if self.request.method == 'GET':
            return OrderListSerializer
        return OrderCreateSerializer
    
    def perform_create(self, serializer):
        import uuid
        order_number = f"ORD-{timezone.now().strftime('%Y%m%d')}-{str(uuid.uuid4())[:8].upper()}"
        serializer.save(order_number=order_number, cashier=self.request.user)


class OrderDetailView(generics.RetrieveUpdateAPIView):
    queryset = Order.objects.all()
    serializer_class = OrderSerializer


class TodayOrdersView(generics.ListAPIView):
    serializer_class = OrderListSerializer
    filter_backends = [DjangoFilterBackend]
    filterset_fields = ['branch', 'status', 'order_type']
    
    def get_queryset(self):
        return Order.objects.filter(created_at__date=date.today())


class KitchenOrdersView(generics.ListAPIView):
    serializer_class = KitchenOrderSerializer
    filter_backends = [DjangoFilterBackend]
    filterset_fields = ['branch']
    
    def get_queryset(self):
        return Order.objects.filter(
            status__in=['in_kitchen', 'preparing'],
            created_at__date=date.today()
        ).order_by('sent_to_kitchen_at')


class OrderStatusUpdateView(APIView):
    def post(self, request, pk):
        try:
            order = Order.objects.get(pk=pk)
            serializer = OrderStatusUpdateSerializer(data=request.data)
            serializer.is_valid(raise_exception=True)
            
            new_status = serializer.validated_data['status']
            order.status = new_status
            
            # Update timestamps based on status
            if new_status == 'in_kitchen':
                order.sent_to_kitchen_at = timezone.now()
            elif new_status == 'preparing':
                order.preparation_started_at = timezone.now()
                order.chef = request.user
            elif new_status == 'ready':
                order.ready_at = timezone.now()
            elif new_status == 'delivered':
                order.delivered_at = timezone.now()
                # Deduct ingredients from inventory
                self._deduct_inventory(order, request.user)
            
            order.save()
            return Response(OrderSerializer(order).data)
        except Order.DoesNotExist:
            return Response({'error': 'Order not found'}, status=404)
    
    def _deduct_inventory(self, order, user):
        for order_item in order.items.all():
            for ing in order_item.menu_item.ingredients.all():
                qty = ing.quantity * order_item.quantity
                try:
                    inv = Inventory.objects.get(branch=order.branch, item=ing.item)
                    old_qty = inv.quantity
                    inv.quantity -= qty
                    inv.save()
                    
                    InventoryTransaction.objects.create(
                        branch=order.branch,
                        item=ing.item,
                        operation_type='consumption',
                        quantity=-qty,
                        quantity_before=old_qty,
                        quantity_after=inv.quantity,
                        reference_type='order',
                        reference_id=order.id,
                        created_by=user
                    )
                except Inventory.DoesNotExist:
                    pass


class OrderCancelView(APIView):
    def post(self, request, pk):
        try:
            order = Order.objects.get(pk=pk)
            if order.status in ['delivered', 'cancelled']:
                return Response({'error': 'Cannot cancel this order'}, status=400)
            
            serializer = OrderCancelSerializer(data=request.data)
            serializer.is_valid(raise_exception=True)
            
            order.status = 'cancelled'
            order.cancelled_at = timezone.now()
            order.cancelled_by = request.user
            order.cancellation_reason = serializer.validated_data['cancellation_reason']
            order.save()
            
            # Update order items status
            order.items.update(status='cancelled')
            
            return Response(OrderSerializer(order).data)
        except Order.DoesNotExist:
            return Response({'error': 'Order not found'}, status=404)


class OrderPayView(APIView):
    def post(self, request, pk):
        try:
            order = Order.objects.get(pk=pk)
            payment_method = request.data.get('payment_method')
            
            order.payment_method = payment_method
            order.status = 'paid'
            order.paid_at = timezone.now()
            order.save()
            
            return Response(OrderSerializer(order).data)
        except Order.DoesNotExist:
            return Response({'error': 'Order not found'}, status=404)


# Order Item Views
class OrderItemListView(generics.ListAPIView):
    serializer_class = OrderItemSerializer
    
    def get_queryset(self):
        order_id = self.kwargs.get('order_id')
        return OrderItem.objects.filter(order_id=order_id)


class OrderItemDetailView(generics.RetrieveUpdateAPIView):
    queryset = OrderItem.objects.all()
    serializer_class = OrderItemSerializer


class OrderItemStatusUpdateView(APIView):
    def post(self, request, pk):
        try:
            item = OrderItem.objects.get(pk=pk)
            new_status = request.data.get('status')
            if new_status:
                item.status = new_status
                item.save()
            return Response(OrderItemSerializer(item).data)
        except OrderItem.DoesNotExist:
            return Response({'error': 'Order item not found'}, status=404)


# Daily Sales View
class DailySalesView(APIView):
    def get(self, request):
        target_date = request.query_params.get('date', date.today())
        branch_id = request.query_params.get('branch')
        
        queryset = Order.objects.filter(created_at__date=target_date)
        if branch_id:
            queryset = queryset.filter(branch_id=branch_id)
        
        paid_orders = queryset.exclude(status='cancelled')
        
        data = {
            'date': target_date,
            'total_orders': paid_orders.count(),
            'total_amount': paid_orders.aggregate(total=Sum('total_amount'))['total'] or 0,
            'total_tax': paid_orders.aggregate(total=Sum('tax_amount'))['total'] or 0,
            'total_discount': paid_orders.aggregate(total=Sum('discount_amount'))['total'] or 0,
            'cash_amount': paid_orders.filter(payment_method='cash').aggregate(total=Sum('total_amount'))['total'] or 0,
            'visa_amount': paid_orders.filter(payment_method='visa').aggregate(total=Sum('total_amount'))['total'] or 0,
            'cancelled_orders': queryset.filter(status='cancelled').count()
        }
        
        return Response(DailySalesSerializer(data).data)
