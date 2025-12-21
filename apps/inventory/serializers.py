from rest_framework import serializers
from .models import (Item, Inventory, InventoryBatch, InventoryTransaction,
                     DailyInventoryCount, DailyInventoryCountItem)


class ItemSerializer(serializers.ModelSerializer):
    """Serializer for Item model"""
    category_name = serializers.CharField(source='category.name', read_only=True)
    unit_name = serializers.CharField(source='unit.name', read_only=True)
    created_by_name = serializers.CharField(source='created_by.full_name', read_only=True)
    
    class Meta:
        model = Item
        fields = ['id', 'code', 'name', 'name_ar', 'description', 'category',
                  'category_name', 'unit', 'unit_name', 'barcode', 'purchase_price',
                  'selling_price', 'min_stock_level', 'max_stock_level', 'reorder_level',
                  'is_perishable', 'shelf_life_days', 'status', 'image',
                  'created_by', 'created_by_name', 'created_at', 'updated_at']
        read_only_fields = ['id', 'created_at', 'updated_at']


class ItemListSerializer(serializers.ModelSerializer):
    """Lightweight serializer for Item lists"""
    category_name = serializers.CharField(source='category.name', read_only=True)
    unit_name = serializers.CharField(source='unit.name', read_only=True)
    
    class Meta:
        model = Item
        fields = ['id', 'code', 'name', 'category_name', 'unit_name', 
                  'purchase_price', 'selling_price', 'status']


class ItemDetailSerializer(serializers.ModelSerializer):
    """Detailed serializer for Item"""
    category_name = serializers.CharField(source='category.name', read_only=True)
    unit_name = serializers.CharField(source='unit.name', read_only=True)
    created_by_name = serializers.CharField(source='created_by.full_name', read_only=True)
    suppliers = serializers.SerializerMethodField()
    total_stock = serializers.SerializerMethodField()
    
    class Meta:
        model = Item
        fields = ['id', 'code', 'name', 'name_ar', 'description', 'category',
                  'category_name', 'unit', 'unit_name', 'barcode', 'purchase_price',
                  'selling_price', 'min_stock_level', 'max_stock_level', 'reorder_level',
                  'is_perishable', 'shelf_life_days', 'status', 'image', 'suppliers',
                  'total_stock', 'created_by', 'created_by_name', 'created_at', 'updated_at']
        read_only_fields = ['id', 'created_at', 'updated_at']
    
    def get_suppliers(self, obj):
        return [{'id': si.supplier.id, 'name': si.supplier.name, 
                 'price': si.unit_price, 'is_preferred': si.is_preferred}
                for si in obj.supplier_items.all()]
    
    def get_total_stock(self, obj):
        return sum(inv.quantity for inv in obj.inventory.all())


class InventoryBatchSerializer(serializers.ModelSerializer):
    """Serializer for InventoryBatch model"""
    item_name = serializers.CharField(source='inventory.item.name', read_only=True)
    branch_name = serializers.CharField(source='inventory.branch.name', read_only=True)
    supply_number = serializers.CharField(source='supply.supply_number', read_only=True)
    
    class Meta:
        model = InventoryBatch
        fields = ['id', 'inventory', 'item_name', 'branch_name', 'batch_number',
                  'quantity', 'remaining_quantity', 'purchase_price', 'expiry_date',
                  'received_date', 'supply', 'supply_number', 'created_at', 'updated_at']
        read_only_fields = ['id', 'created_at', 'updated_at']


class InventorySerializer(serializers.ModelSerializer):
    """Serializer for Inventory model"""
    branch_name = serializers.CharField(source='branch.name', read_only=True)
    branch_code = serializers.CharField(source='branch.code', read_only=True)
    item_name = serializers.CharField(source='item.name', read_only=True)
    item_code = serializers.CharField(source='item.code', read_only=True)
    unit_name = serializers.CharField(source='item.unit.name', read_only=True)
    batches = InventoryBatchSerializer(many=True, read_only=True)
    
    class Meta:
        model = Inventory
        fields = ['id', 'branch', 'branch_code', 'branch_name', 'item', 'item_code',
                  'item_name', 'unit_name', 'quantity', 'reserved_quantity', 'min_quantity',
                  'entry_date', 'document_number', 'partial_quantity', 'content_quantity',
                  'total_quantity', 'content_description', 'opening_balance',
                  'incoming_quantity', 'consumption_quantity', 'consumption_description',
                  'period_start_date', 'period_end_date', 'last_restock_date',
                  'last_count_date', 'batches', 'created_at', 'updated_at']
        read_only_fields = ['id', 'total_quantity', 'created_at', 'updated_at']


class InventoryListSerializer(serializers.ModelSerializer):
    """Lightweight serializer for Inventory lists"""
    branch_code = serializers.CharField(source='branch.code', read_only=True)
    item_name = serializers.CharField(source='item.name', read_only=True)
    item_code = serializers.CharField(source='item.code', read_only=True)
    unit_name = serializers.CharField(source='item.unit.name', read_only=True)
    is_low_stock = serializers.SerializerMethodField()
    
    class Meta:
        model = Inventory
        fields = ['id', 'branch_code', 'item_code', 'item_name', 'unit_name',
                  'quantity', 'min_quantity', 'total_quantity', 'is_low_stock']
    
    def get_is_low_stock(self, obj):
        return obj.quantity <= obj.min_quantity


class InventoryTransactionSerializer(serializers.ModelSerializer):
    """Serializer for InventoryTransaction model"""
    branch_name = serializers.CharField(source='branch.name', read_only=True)
    branch_code = serializers.CharField(source='branch.code', read_only=True)
    item_name = serializers.CharField(source='item.name', read_only=True)
    item_code = serializers.CharField(source='item.code', read_only=True)
    batch_number = serializers.CharField(source='batch.batch_number', read_only=True)
    created_by_name = serializers.CharField(source='created_by.full_name', read_only=True)
    
    class Meta:
        model = InventoryTransaction
        fields = ['id', 'branch', 'branch_code', 'branch_name', 'item', 'item_code',
                  'item_name', 'batch', 'batch_number', 'operation_type', 'quantity',
                  'quantity_before', 'quantity_after', 'unit_cost', 'reference_type',
                  'reference_id', 'notes', 'created_by', 'created_by_name', 'created_at']
        read_only_fields = ['id', 'created_at']


class InventoryTransactionListSerializer(serializers.ModelSerializer):
    """Lightweight serializer for InventoryTransaction lists"""
    branch_code = serializers.CharField(source='branch.code', read_only=True)
    item_name = serializers.CharField(source='item.name', read_only=True)
    
    class Meta:
        model = InventoryTransaction
        fields = ['id', 'branch_code', 'item_name', 'operation_type', 'quantity',
                  'quantity_before', 'quantity_after', 'created_at']


class DailyInventoryCountItemSerializer(serializers.ModelSerializer):
    """Serializer for DailyInventoryCountItem model"""
    item_name = serializers.CharField(source='item.name', read_only=True)
    item_code = serializers.CharField(source='item.code', read_only=True)
    unit_name = serializers.CharField(source='item.unit.name', read_only=True)
    
    class Meta:
        model = DailyInventoryCountItem
        fields = ['id', 'count', 'item', 'item_code', 'item_name', 'unit_name',
                  'system_quantity', 'actual_quantity', 'variance', 'variance_reason']
        read_only_fields = ['id', 'variance']


class DailyInventoryCountSerializer(serializers.ModelSerializer):
    """Serializer for DailyInventoryCount model"""
    branch_name = serializers.CharField(source='branch.name', read_only=True)
    branch_code = serializers.CharField(source='branch.code', read_only=True)
    counted_by_name = serializers.CharField(source='counted_by.full_name', read_only=True)
    approved_by_name = serializers.CharField(source='approved_by.full_name', read_only=True)
    items = DailyInventoryCountItemSerializer(many=True, read_only=True)
    items_count = serializers.SerializerMethodField()
    total_variance = serializers.SerializerMethodField()
    
    class Meta:
        model = DailyInventoryCount
        fields = ['id', 'branch', 'branch_code', 'branch_name', 'count_date',
                  'count_type', 'status', 'notes', 'items', 'items_count',
                  'total_variance', 'counted_by', 'counted_by_name', 'submitted_at',
                  'approved_by', 'approved_by_name', 'approved_at', 'created_at', 'updated_at']
        read_only_fields = ['id', 'created_at', 'updated_at']
    
    def get_items_count(self, obj):
        return obj.items.count()
    
    def get_total_variance(self, obj):
        return sum(item.variance for item in obj.items.all())


class DailyInventoryCountListSerializer(serializers.ModelSerializer):
    """Lightweight serializer for DailyInventoryCount lists"""
    branch_code = serializers.CharField(source='branch.code', read_only=True)
    counted_by_name = serializers.CharField(source='counted_by.full_name', read_only=True)
    items_count = serializers.SerializerMethodField()
    
    class Meta:
        model = DailyInventoryCount
        fields = ['id', 'branch_code', 'count_date', 'count_type', 'status',
                  'items_count', 'counted_by_name']
    
    def get_items_count(self, obj):
        return obj.items.count()


class LowStockSerializer(serializers.Serializer):
    """Serializer for low stock items"""
    branch_code = serializers.CharField()
    branch_name = serializers.CharField()
    item_code = serializers.CharField()
    item_name = serializers.CharField()
    current_quantity = serializers.DecimalField(max_digits=12, decimal_places=3)
    min_quantity = serializers.DecimalField(max_digits=12, decimal_places=3)
    reorder_level = serializers.DecimalField(max_digits=12, decimal_places=3)


class ExpiringItemsSerializer(serializers.Serializer):
    """Serializer for expiring items"""
    branch_code = serializers.CharField()
    branch_name = serializers.CharField()
    item_code = serializers.CharField()
    item_name = serializers.CharField()
    batch_number = serializers.CharField()
    quantity = serializers.DecimalField(max_digits=12, decimal_places=3)
    expiry_date = serializers.DateField()
    days_until_expiry = serializers.IntegerField()
