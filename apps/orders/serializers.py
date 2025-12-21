from rest_framework import serializers
from .models import Order, OrderItem


class OrderItemSerializer(serializers.ModelSerializer):
    """Serializer for OrderItem model"""
    menu_item_name = serializers.CharField(source='menu_item.name', read_only=True)
    menu_item_code = serializers.CharField(source='menu_item.code', read_only=True)
    
    class Meta:
        model = OrderItem
        fields = ['id', 'order', 'menu_item', 'menu_item_code', 'menu_item_name',
                  'quantity', 'unit_price', 'discount_amount', 'total_price',
                  'status', 'notes']
        read_only_fields = ['id', 'total_price']


class OrderSerializer(serializers.ModelSerializer):
    """Serializer for Order model"""
    branch_name = serializers.CharField(source='branch.name', read_only=True)
    branch_code = serializers.CharField(source='branch.code', read_only=True)
    cashier_name = serializers.CharField(source='cashier.full_name', read_only=True)
    chef_name = serializers.CharField(source='chef.full_name', read_only=True)
    cancelled_by_name = serializers.CharField(source='cancelled_by.full_name', read_only=True)
    items = OrderItemSerializer(many=True, read_only=True)
    items_count = serializers.SerializerMethodField()
    
    class Meta:
        model = Order
        fields = ['id', 'order_number', 'branch', 'branch_code', 'branch_name',
                  'order_type', 'table_number', 'customer_name', 'customer_phone',
                  'customer_address', 'subtotal', 'tax_amount', 'discount_amount',
                  'total_amount', 'payment_method', 'status', 'notes', 'items',
                  'items_count', 'cashier', 'cashier_name', 'chef', 'chef_name',
                  'paid_at', 'sent_to_kitchen_at', 'preparation_started_at',
                  'ready_at', 'delivered_at', 'cancelled_at', 'cancelled_by',
                  'cancelled_by_name', 'cancellation_reason', 'created_at', 'updated_at']
        read_only_fields = ['id', 'order_number', 'created_at', 'updated_at']
    
    def get_items_count(self, obj):
        return obj.items.count()


class OrderListSerializer(serializers.ModelSerializer):
    """Lightweight serializer for Order lists"""
    branch_code = serializers.CharField(source='branch.code', read_only=True)
    cashier_name = serializers.CharField(source='cashier.full_name', read_only=True)
    items_count = serializers.SerializerMethodField()
    
    class Meta:
        model = Order
        fields = ['id', 'order_number', 'branch_code', 'order_type', 'table_number',
                  'total_amount', 'payment_method', 'status', 'items_count',
                  'cashier_name', 'created_at']
    
    def get_items_count(self, obj):
        return obj.items.count()


class OrderCreateSerializer(serializers.ModelSerializer):
    """Serializer for creating orders"""
    items = OrderItemSerializer(many=True)
    
    class Meta:
        model = Order
        fields = ['branch', 'order_type', 'table_number', 'customer_name',
                  'customer_phone', 'customer_address', 'discount_amount',
                  'payment_method', 'notes', 'items']
    
    def create(self, validated_data):
        items_data = validated_data.pop('items')
        order = Order.objects.create(**validated_data)
        
        subtotal = 0
        tax_total = 0
        
        for item_data in items_data:
            item_data['order'] = order
            menu_item = item_data['menu_item']
            qty = item_data['quantity']
            unit_price = item_data.get('unit_price', menu_item.price)
            discount = item_data.get('discount_amount', 0)
            
            item_data['unit_price'] = unit_price
            item_data['total_price'] = (unit_price * qty) - discount
            
            OrderItem.objects.create(**item_data)
            
            subtotal += item_data['total_price']
            tax_total += item_data['total_price'] * (menu_item.tax_percent / 100)
        
        order.subtotal = subtotal
        order.tax_amount = tax_total
        order.total_amount = subtotal + tax_total - (order.discount_amount or 0)
        order.save()
        
        return order


class OrderStatusUpdateSerializer(serializers.Serializer):
    """Serializer for updating order status"""
    status = serializers.ChoiceField(choices=Order.STATUS_CHOICES)
    notes = serializers.CharField(required=False, allow_blank=True)


class OrderCancelSerializer(serializers.Serializer):
    """Serializer for cancelling orders"""
    cancellation_reason = serializers.CharField(required=True)


class KitchenOrderSerializer(serializers.ModelSerializer):
    """Serializer for kitchen display"""
    branch_code = serializers.CharField(source='branch.code', read_only=True)
    items = OrderItemSerializer(many=True, read_only=True)
    waiting_time = serializers.SerializerMethodField()
    
    class Meta:
        model = Order
        fields = ['id', 'order_number', 'branch_code', 'order_type', 'table_number',
                  'status', 'items', 'notes', 'waiting_time', 'sent_to_kitchen_at',
                  'preparation_started_at']
    
    def get_waiting_time(self, obj):
        from django.utils import timezone
        if obj.sent_to_kitchen_at:
            delta = timezone.now() - obj.sent_to_kitchen_at
            return int(delta.total_seconds() / 60)
        return 0


class DailySalesSerializer(serializers.Serializer):
    """Serializer for daily sales summary"""
    date = serializers.DateField()
    total_orders = serializers.IntegerField()
    total_amount = serializers.DecimalField(max_digits=12, decimal_places=2)
    total_tax = serializers.DecimalField(max_digits=12, decimal_places=2)
    total_discount = serializers.DecimalField(max_digits=12, decimal_places=2)
    cash_amount = serializers.DecimalField(max_digits=12, decimal_places=2)
    visa_amount = serializers.DecimalField(max_digits=12, decimal_places=2)
    cancelled_orders = serializers.IntegerField()
