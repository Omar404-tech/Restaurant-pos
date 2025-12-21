from rest_framework import generics, status
from rest_framework.views import APIView
from rest_framework.response import Response
from django.utils import timezone
from django.db.models import Sum, Count
from datetime import date

from apps.menu.models import MenuCategory, MenuItem
from apps.orders.models import Order, OrderItem
from .serializers import (
    POSMenuCategorySerializer, POSOrderCreateSerializer,
    POSPaymentSerializer, POSReceiptSerializer
)


class POSMenuView(APIView):
    def get(self, request):
        categories = MenuCategory.objects.filter(
            is_active=True, parent__isnull=True
        ).order_by('sort_order')
        serializer = POSMenuCategorySerializer(categories, many=True)
        return Response(serializer.data)


class POSOrderCreateView(APIView):
    def post(self, request):
        serializer = POSOrderCreateSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        
        data = serializer.validated_data
        branch = request.user.branch
        
        if not branch:
            return Response({'error': 'User has no branch assigned'}, status=400)
        
        import uuid
        order_number = f"ORD-{timezone.now().strftime('%Y%m%d')}-{str(uuid.uuid4())[:8].upper()}"
        
        # Create order
        order = Order.objects.create(
            order_number=order_number,
            branch=branch,
            order_type=data['order_type'],
            table_number=data.get('table_number', ''),
            customer_name=data.get('customer_name', ''),
            customer_phone=data.get('customer_phone', ''),
            customer_address=data.get('customer_address', ''),
            payment_method=data.get('payment_method'),
            discount_amount=data.get('discount_amount', 0),
            notes=data.get('notes', ''),
            cashier=request.user,
            status='new'
        )
        
        # Create order items
        subtotal = 0
        tax_total = 0
        
        for item_data in data['items']:
            menu_item = MenuItem.objects.get(pk=item_data['menu_item_id'])
            qty = item_data['quantity']
            discount = item_data.get('discount_amount', 0)
            total_price = (menu_item.price * qty) - discount
            
            OrderItem.objects.create(
                order=order,
                menu_item=menu_item,
                quantity=qty,
                unit_price=menu_item.price,
                discount_amount=discount,
                total_price=total_price,
                notes=item_data.get('notes', '')
            )
            
            subtotal += total_price
            tax_total += total_price * (menu_item.tax_percent / 100)
        
        order.subtotal = subtotal
        order.tax_amount = tax_total
        order.total_amount = subtotal + tax_total - order.discount_amount
        order.save()
        
        return Response(POSReceiptSerializer(order).data, status=201)


class POSPaymentView(APIView):
    def post(self, request, pk):
        try:
            order = Order.objects.get(pk=pk)
            serializer = POSPaymentSerializer(data=request.data)
            serializer.is_valid(raise_exception=True)
            
            order.payment_method = serializer.validated_data['payment_method']
            order.status = 'paid'
            order.paid_at = timezone.now()
            order.save()
            
            # Send to kitchen
            order.status = 'in_kitchen'
            order.sent_to_kitchen_at = timezone.now()
            order.save()
            
            order.items.update(status='in_kitchen')
            
            return Response(POSReceiptSerializer(order).data)
        except Order.DoesNotExist:
            return Response({'error': 'Order not found'}, status=404)


class POSReceiptView(APIView):
    def get(self, request, pk):
        try:
            order = Order.objects.get(pk=pk)
            return Response(POSReceiptSerializer(order).data)
        except Order.DoesNotExist:
            return Response({'error': 'Order not found'}, status=404)


class KitchenDisplayView(APIView):
    def get(self, request):
        branch = request.user.branch
        orders = Order.objects.filter(
            branch=branch,
            status__in=['in_kitchen', 'preparing'],
            created_at__date=date.today()
        ).order_by('sent_to_kitchen_at')
        
        data = []
        for order in orders:
            waiting_time = 0
            if order.sent_to_kitchen_at:
                delta = timezone.now() - order.sent_to_kitchen_at
                waiting_time = int(delta.total_seconds() / 60)
            
            data.append({
                'id': order.id,
                'order_number': order.order_number,
                'order_type': order.order_type,
                'table_number': order.table_number,
                'status': order.status,
                'waiting_time': waiting_time,
                'items': [{
                    'name': item.menu_item.name,
                    'quantity': item.quantity,
                    'notes': item.notes,
                    'status': item.status
                } for item in order.items.all()]
            })
        
        return Response(data)


class KitchenStartPreparingView(APIView):
    def post(self, request, pk):
        try:
            order = Order.objects.get(pk=pk)
            order.status = 'preparing'
            order.preparation_started_at = timezone.now()
            order.chef = request.user
            order.save()
            
            order.items.update(status='preparing')
            
            return Response({'message': 'Order preparation started'})
        except Order.DoesNotExist:
            return Response({'error': 'Order not found'}, status=404)


class KitchenReadyView(APIView):
    def post(self, request, pk):
        try:
            order = Order.objects.get(pk=pk)
            order.status = 'ready'
            order.ready_at = timezone.now()
            order.save()
            
            order.items.update(status='ready')
            
            return Response({'message': 'Order is ready'})
        except Order.DoesNotExist:
            return Response({'error': 'Order not found'}, status=404)


class POSDailySummaryView(APIView):
    def get(self, request):
        branch = request.user.branch
        today = date.today()
        
        orders = Order.objects.filter(branch=branch, created_at__date=today)
        paid_orders = orders.exclude(status='cancelled')
        
        return Response({
            'date': today,
            'total_orders': paid_orders.count(),
            'total_amount': paid_orders.aggregate(total=Sum('total_amount'))['total'] or 0,
            'cash_orders': paid_orders.filter(payment_method='cash').count(),
            'cash_amount': paid_orders.filter(payment_method='cash').aggregate(total=Sum('total_amount'))['total'] or 0,
            'visa_orders': paid_orders.filter(payment_method='visa').count(),
            'visa_amount': paid_orders.filter(payment_method='visa').aggregate(total=Sum('total_amount'))['total'] or 0,
            'cancelled_orders': orders.filter(status='cancelled').count(),
            'pending_orders': orders.filter(status__in=['new', 'pending_payment']).count(),
            'in_kitchen_orders': orders.filter(status__in=['in_kitchen', 'preparing']).count()
        })
