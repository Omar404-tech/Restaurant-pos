from rest_framework import serializers
from .models import (Supplier, Supply, SupplyItem, SupplierPayment, SupplierItem,
                     PurchaseRequest, PurchaseRequestItem, PurchaseOrder, PurchaseOrderItem)


class SupplierSerializer(serializers.ModelSerializer):
    """Serializer for Supplier model"""
    created_by_name = serializers.CharField(source='created_by.full_name', read_only=True)
    supplies_count = serializers.SerializerMethodField()
    
    class Meta:
        model = Supplier
        fields = ['id', 'code', 'name', 'name_ar', 'contact_person', 'phone', 'phone2',
                  'email', 'address', 'tax_number', 'payment_method', 'credit_limit',
                  'current_balance', 'status', 'notes', 'supplies_count',
                  'created_by', 'created_by_name', 'created_at', 'updated_at']
        read_only_fields = ['id', 'current_balance', 'created_at', 'updated_at']
    
    def get_supplies_count(self, obj):
        return obj.supplies.count()


class SupplierListSerializer(serializers.ModelSerializer):
    """Lightweight serializer for Supplier lists"""
    class Meta:
        model = Supplier
        fields = ['id', 'code', 'name', 'phone', 'current_balance', 'status']


class SupplierDetailSerializer(serializers.ModelSerializer):
    """Detailed serializer for Supplier"""
    created_by_name = serializers.CharField(source='created_by.full_name', read_only=True)
    supplies_count = serializers.SerializerMethodField()
    payments_count = serializers.SerializerMethodField()
    items_count = serializers.SerializerMethodField()
    
    class Meta:
        model = Supplier
        fields = ['id', 'code', 'name', 'name_ar', 'contact_person', 'phone', 'phone2',
                  'email', 'address', 'tax_number', 'payment_method', 'credit_limit',
                  'current_balance', 'status', 'notes', 'supplies_count', 'payments_count',
                  'items_count', 'created_by', 'created_by_name', 'created_at', 'updated_at']
        read_only_fields = ['id', 'current_balance', 'created_at', 'updated_at']
    
    def get_supplies_count(self, obj):
        return obj.supplies.count()
    
    def get_payments_count(self, obj):
        return obj.payments.count()
    
    def get_items_count(self, obj):
        return obj.supplier_items.count()


class SupplyItemSerializer(serializers.ModelSerializer):
    """Serializer for SupplyItem model"""
    item_name = serializers.CharField(source='item.name', read_only=True)
    item_code = serializers.CharField(source='item.code', read_only=True)
    unit_name = serializers.CharField(source='item.unit.name', read_only=True)
    
    class Meta:
        model = SupplyItem
        fields = ['id', 'supply', 'item', 'item_code', 'item_name', 'unit_name',
                  'quantity', 'received_quantity', 'unit_price', 'tax_percent',
                  'discount_percent', 'total_price', 'batch_number', 'expiry_date', 'notes']
        read_only_fields = ['id']


class SupplySerializer(serializers.ModelSerializer):
    """Serializer for Supply model"""
    supplier_name = serializers.CharField(source='supplier.name', read_only=True)
    branch_name = serializers.CharField(source='branch.name', read_only=True)
    received_by_name = serializers.CharField(source='received_by.full_name', read_only=True)
    approved_by_name = serializers.CharField(source='approved_by.full_name', read_only=True)
    items = SupplyItemSerializer(many=True, read_only=True)
    items_count = serializers.SerializerMethodField()
    
    class Meta:
        model = Supply
        fields = ['id', 'supply_number', 'supplier', 'supplier_name', 'branch', 'branch_name',
                  'invoice_number', 'invoice_date', 'subtotal', 'tax_amount', 'discount_amount',
                  'total_amount', 'payment_method', 'payment_status', 'notes', 'items',
                  'items_count', 'received_by', 'received_by_name', 'received_at',
                  'approved_by', 'approved_by_name', 'approved_at', 'created_at', 'updated_at']
        read_only_fields = ['id', 'supply_number', 'created_at', 'updated_at']
    
    def get_items_count(self, obj):
        return obj.items.count()


class SupplyListSerializer(serializers.ModelSerializer):
    """Lightweight serializer for Supply lists"""
    supplier_name = serializers.CharField(source='supplier.name', read_only=True)
    branch_code = serializers.CharField(source='branch.code', read_only=True)
    items_count = serializers.SerializerMethodField()
    
    class Meta:
        model = Supply
        fields = ['id', 'supply_number', 'supplier_name', 'branch_code', 'invoice_number',
                  'total_amount', 'payment_status', 'items_count', 'created_at']
    
    def get_items_count(self, obj):
        return obj.items.count()


class SupplyCreateSerializer(serializers.ModelSerializer):
    """Serializer for creating supplies"""
    items = SupplyItemSerializer(many=True)
    
    class Meta:
        model = Supply
        fields = ['supplier', 'branch', 'invoice_number', 'invoice_date', 'payment_method',
                  'notes', 'items']
    
    def create(self, validated_data):
        items_data = validated_data.pop('items')
        supply = Supply.objects.create(**validated_data)
        
        subtotal = 0
        for item_data in items_data:
            item_data['supply'] = supply
            qty = item_data['quantity']
            price = item_data['unit_price']
            tax = item_data.get('tax_percent', 0)
            discount = item_data.get('discount_percent', 0)
            
            base_total = qty * price
            discount_amount = base_total * (discount / 100)
            tax_amount = (base_total - discount_amount) * (tax / 100)
            item_data['total_price'] = base_total - discount_amount + tax_amount
            
            SupplyItem.objects.create(**item_data)
            subtotal += item_data['total_price']
        
        supply.subtotal = subtotal
        supply.total_amount = subtotal
        supply.save()
        return supply


class SupplierPaymentSerializer(serializers.ModelSerializer):
    """Serializer for SupplierPayment model"""
    supplier_name = serializers.CharField(source='supplier.name', read_only=True)
    supply_number = serializers.CharField(source='supply.supply_number', read_only=True)
    created_by_name = serializers.CharField(source='created_by.full_name', read_only=True)
    
    class Meta:
        model = SupplierPayment
        fields = ['id', 'payment_number', 'supplier', 'supplier_name', 'supply',
                  'supply_number', 'amount', 'payment_method', 'reference_number',
                  'bank_name', 'payment_date', 'notes', 'created_by', 'created_by_name',
                  'created_at', 'updated_at']
        read_only_fields = ['id', 'payment_number', 'created_at', 'updated_at']


class SupplierPaymentListSerializer(serializers.ModelSerializer):
    """Lightweight serializer for SupplierPayment lists"""
    supplier_name = serializers.CharField(source='supplier.name', read_only=True)
    
    class Meta:
        model = SupplierPayment
        fields = ['id', 'payment_number', 'supplier_name', 'amount', 
                  'payment_method', 'payment_date']


class SupplierItemSerializer(serializers.ModelSerializer):
    """Serializer for SupplierItem model"""
    supplier_name = serializers.CharField(source='supplier.name', read_only=True)
    item_name = serializers.CharField(source='item.name', read_only=True)
    item_code = serializers.CharField(source='item.code', read_only=True)
    
    class Meta:
        model = SupplierItem
        fields = ['id', 'supplier', 'supplier_name', 'item', 'item_code', 'item_name',
                  'unit_price', 'is_preferred', 'notes', 'created_at', 'updated_at']
        read_only_fields = ['id', 'created_at', 'updated_at']


class PurchaseRequestItemSerializer(serializers.ModelSerializer):
    """Serializer for PurchaseRequestItem model"""
    item_name = serializers.CharField(source='item.name', read_only=True)
    item_code = serializers.CharField(source='item.code', read_only=True)
    supplier_name = serializers.CharField(source='supplier.name', read_only=True)
    
    class Meta:
        model = PurchaseRequestItem
        fields = ['id', 'request', 'item', 'item_code', 'item_name', 'supplier',
                  'supplier_name', 'requested_quantity', 'approved_quantity',
                  'received_quantity', 'estimated_unit_price', 'notes']
        read_only_fields = ['id']


class PurchaseRequestSerializer(serializers.ModelSerializer):
    """Serializer for PurchaseRequest model"""
    branch_name = serializers.CharField(source='branch.name', read_only=True)
    requested_by_name = serializers.CharField(source='requested_by.full_name', read_only=True)
    approved_by_name = serializers.CharField(source='approved_by.full_name', read_only=True)
    items = PurchaseRequestItemSerializer(many=True, read_only=True)
    
    class Meta:
        model = PurchaseRequest
        fields = ['id', 'request_number', 'request_date', 'branch', 'branch_name',
                  'status', 'priority', 'total_items', 'total_quantity', 'notes',
                  'items', 'requested_by', 'requested_by_name', 'requested_at',
                  'approved_by', 'approved_by_name', 'approved_at', 'rejected_by',
                  'rejected_at', 'rejection_reason', 'created_at', 'updated_at']
        read_only_fields = ['id', 'request_number', 'created_at', 'updated_at']


class PurchaseRequestListSerializer(serializers.ModelSerializer):
    """Lightweight serializer for PurchaseRequest lists"""
    branch_code = serializers.CharField(source='branch.code', read_only=True)
    requested_by_name = serializers.CharField(source='requested_by.full_name', read_only=True)
    
    class Meta:
        model = PurchaseRequest
        fields = ['id', 'request_number', 'request_date', 'branch_code', 'status',
                  'priority', 'total_items', 'requested_by_name']


class PurchaseOrderItemSerializer(serializers.ModelSerializer):
    """Serializer for PurchaseOrderItem model"""
    item_name = serializers.CharField(source='item.name', read_only=True)
    item_code = serializers.CharField(source='item.code', read_only=True)
    
    class Meta:
        model = PurchaseOrderItem
        fields = ['id', 'order', 'item', 'item_code', 'item_name', 'request_item',
                  'quantity', 'received_quantity', 'unit_price', 'tax_percent',
                  'total_price', 'notes']
        read_only_fields = ['id']


class PurchaseOrderSerializer(serializers.ModelSerializer):
    """Serializer for PurchaseOrder model"""
    supplier_name = serializers.CharField(source='supplier.name', read_only=True)
    branch_name = serializers.CharField(source='branch.name', read_only=True)
    created_by_name = serializers.CharField(source='created_by.full_name', read_only=True)
    approved_by_name = serializers.CharField(source='approved_by.full_name', read_only=True)
    items = PurchaseOrderItemSerializer(many=True, read_only=True)
    
    class Meta:
        model = PurchaseOrder
        fields = ['id', 'order_number', 'request', 'supplier', 'supplier_name',
                  'branch', 'branch_name', 'order_date', 'expected_delivery', 'status',
                  'subtotal', 'tax_amount', 'total_amount', 'notes', 'items',
                  'created_by', 'created_by_name', 'approved_by', 'approved_by_name',
                  'approved_at', 'created_at', 'updated_at']
        read_only_fields = ['id', 'order_number', 'created_at', 'updated_at']


class PurchaseOrderListSerializer(serializers.ModelSerializer):
    """Lightweight serializer for PurchaseOrder lists"""
    supplier_name = serializers.CharField(source='supplier.name', read_only=True)
    branch_code = serializers.CharField(source='branch.code', read_only=True)
    
    class Meta:
        model = PurchaseOrder
        fields = ['id', 'order_number', 'supplier_name', 'branch_code', 'order_date',
                  'status', 'total_amount']
