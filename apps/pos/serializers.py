from rest_framework import serializers
from apps.orders.models import Order, OrderItem
from apps.menu.models import MenuItem, MenuCategory


class POSMenuCategorySerializer(serializers.ModelSerializer):
    """Serializer for POS menu categories"""
    items = serializers.SerializerMethodField()
    
    class Meta:
        model = MenuCategory
        fields = ['id', 'code', 'name', 'name_ar', 'image', 'items']
    
    def get_items(self, obj):
        items = obj.items.filter(is_active=True, is_available=True).order_by('sort_order')
        return POSMenuItemSerializer(items, many=True).data


class POSMenuItemSerializer(serializers.ModelSerializer):
    """Serializer for POS menu items"""
    class Meta:
        model = MenuItem
        fields = ['id', 'code', 'name', 'name_ar', 'price', 'tax_percent', 
                  'preparation_time', 'image']


class POSOrderItemSerializer(serializers.Serializer):
    """Serializer for POS order items"""
    menu_item_id = serializers.UUIDField()
    quantity = serializers.IntegerField(min_value=1)
    notes = serializers.CharField(required=False, allow_blank=True)
    discount_amount = serializers.DecimalField(max_digits=12, decimal_places=2, 
                                                required=False, default=0)


class POSOrderCreateSerializer(serializers.Serializer):
    """Serializer for creating POS orders"""
    order_type = serializers.ChoiceField(choices=Order.ORDER_TYPE_CHOICES)
    table_number = serializers.CharField(required=False, allow_blank=True)
    customer_name = serializers.CharField(required=False, allow_blank=True)
    customer_phone = serializers.CharField(required=False, allow_blank=True)
    customer_address = serializers.CharField(required=False, allow_blank=True)
    payment_method = serializers.ChoiceField(choices=Order.PAYMENT_METHOD_CHOICES, 
                                              required=False, allow_null=True)
    discount_amount = serializers.DecimalField(max_digits=12, decimal_places=2, 
                                                required=False, default=0)
    notes = serializers.CharField(required=False, allow_blank=True)
    items = POSOrderItemSerializer(many=True)


class POSPaymentSerializer(serializers.Serializer):
    """Serializer for POS payment"""
    order_id = serializers.UUIDField()
    payment_method = serializers.ChoiceField(choices=Order.PAYMENT_METHOD_CHOICES)
    amount_received = serializers.DecimalField(max_digits=12, decimal_places=2)


class POSReceiptSerializer(serializers.ModelSerializer):
    """Serializer for POS receipt"""
    branch_name = serializers.CharField(source='branch.name', read_only=True)
    branch_address = serializers.CharField(source='branch.address', read_only=True)
    branch_phone = serializers.CharField(source='branch.phone', read_only=True)
    cashier_name = serializers.CharField(source='cashier.full_name', read_only=True)
    items = serializers.SerializerMethodField()
    
    class Meta:
        model = Order
        fields = ['id', 'order_number', 'branch_name', 'branch_address', 'branch_phone',
                  'order_type', 'table_number', 'customer_name', 'subtotal', 'tax_amount',
                  'discount_amount', 'total_amount', 'payment_method', 'cashier_name',
                  'items', 'created_at', 'paid_at']
    
    def get_items(self, obj):
        return [{
            'name': item.menu_item.name,
            'quantity': item.quantity,
            'unit_price': item.unit_price,
            'total_price': item.total_price
        } for item in obj.items.all()]
