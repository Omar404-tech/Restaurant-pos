from rest_framework import serializers
from .models import SupplierReturn, BranchReturn, BranchReturnItem, BranchReturnReason


class SupplierReturnSerializer(serializers.ModelSerializer):
    """Serializer for SupplierReturn model"""
    supply_number = serializers.CharField(source='supply.supply_number', read_only=True)
    supplier_name = serializers.CharField(source='supplier.name', read_only=True)
    item_name = serializers.CharField(source='item.name', read_only=True)
    item_code = serializers.CharField(source='item.code', read_only=True)
    unit_name = serializers.CharField(source='item.unit.name', read_only=True)
    registered_by_name = serializers.CharField(source='registered_by.full_name', read_only=True)
    approved_by_name = serializers.CharField(source='approved_by.full_name', read_only=True)
    
    class Meta:
        model = SupplierReturn
        fields = ['id', 'return_number', 'supply', 'supply_number', 'supplier',
                  'supplier_name', 'item', 'item_code', 'item_name', 'unit_name',
                  'quantity', 'unit_price', 'total_amount', 'reason', 'description',
                  'status', 'registered_by', 'registered_by_name', 'registered_at',
                  'approved_by', 'approved_by_name', 'approved_at', 'rejected_by',
                  'rejected_at', 'rejection_reason', 'created_at', 'updated_at']
        read_only_fields = ['id', 'return_number', 'total_amount', 'created_at', 'updated_at']


class SupplierReturnListSerializer(serializers.ModelSerializer):
    """Lightweight serializer for SupplierReturn lists"""
    supplier_name = serializers.CharField(source='supplier.name', read_only=True)
    item_name = serializers.CharField(source='item.name', read_only=True)
    
    class Meta:
        model = SupplierReturn
        fields = ['id', 'return_number', 'supplier_name', 'item_name', 'quantity',
                  'total_amount', 'status', 'registered_at']


class SupplierReturnCreateSerializer(serializers.ModelSerializer):
    """Serializer for creating supplier returns"""
    class Meta:
        model = SupplierReturn
        fields = ['supply', 'supplier', 'item', 'quantity', 'unit_price', 'reason', 'description']


class BranchReturnReasonSerializer(serializers.ModelSerializer):
    """Serializer for BranchReturnReason model"""
    class Meta:
        model = BranchReturnReason
        fields = ['id', 'code', 'name', 'name_ar', 'description', 'is_active', 'sort_order']
        read_only_fields = ['id']


class BranchReturnItemSerializer(serializers.ModelSerializer):
    """Serializer for BranchReturnItem model"""
    item_name = serializers.CharField(source='item.name', read_only=True)
    item_code = serializers.CharField(source='item.code', read_only=True)
    unit_name = serializers.CharField(source='item.unit.name', read_only=True)
    batch_number = serializers.CharField(source='batch.batch_number', read_only=True)
    
    class Meta:
        model = BranchReturnItem
        fields = ['id', 'return_order', 'item', 'item_code', 'item_name', 'unit_name',
                  'batch', 'batch_number', 'requested_quantity', 'approved_quantity',
                  'shipped_quantity', 'received_quantity', 'unit_cost', 'total_value',
                  'item_reason', 'notes']
        read_only_fields = ['id']


class BranchReturnSerializer(serializers.ModelSerializer):
    """Serializer for BranchReturn model"""
    from_branch_name = serializers.CharField(source='from_branch.name', read_only=True)
    from_branch_code = serializers.CharField(source='from_branch.code', read_only=True)
    to_branch_name = serializers.CharField(source='to_branch.name', read_only=True)
    to_branch_code = serializers.CharField(source='to_branch.code', read_only=True)
    requested_by_name = serializers.CharField(source='requested_by.full_name', read_only=True)
    approved_by_name = serializers.CharField(source='approved_by.full_name', read_only=True)
    received_by_name = serializers.CharField(source='received_by.full_name', read_only=True)
    items = BranchReturnItemSerializer(many=True, read_only=True)
    
    class Meta:
        model = BranchReturn
        fields = ['id', 'return_number', 'return_date', 'from_branch', 'from_branch_code',
                  'from_branch_name', 'to_branch', 'to_branch_code', 'to_branch_name',
                  'status', 'return_reason', 'notes', 'total_items', 'total_quantity',
                  'total_value', 'items', 'requested_by', 'requested_by_name', 'requested_at',
                  'approved_by', 'approved_by_name', 'approved_at', 'rejected_by',
                  'rejected_at', 'rejection_reason', 'shipped_at', 'received_by',
                  'received_by_name', 'received_at', 'created_at', 'updated_at']
        read_only_fields = ['id', 'return_number', 'created_at', 'updated_at']


class BranchReturnListSerializer(serializers.ModelSerializer):
    """Lightweight serializer for BranchReturn lists"""
    from_branch_code = serializers.CharField(source='from_branch.code', read_only=True)
    to_branch_code = serializers.CharField(source='to_branch.code', read_only=True)
    requested_by_name = serializers.CharField(source='requested_by.full_name', read_only=True)
    
    class Meta:
        model = BranchReturn
        fields = ['id', 'return_number', 'return_date', 'from_branch_code', 'to_branch_code',
                  'status', 'total_items', 'total_value', 'requested_by_name']


class BranchReturnCreateSerializer(serializers.ModelSerializer):
    """Serializer for creating branch returns"""
    items = BranchReturnItemSerializer(many=True)
    
    class Meta:
        model = BranchReturn
        fields = ['return_date', 'from_branch', 'to_branch', 'return_reason', 'notes', 'items']
    
    def create(self, validated_data):
        items_data = validated_data.pop('items')
        branch_return = BranchReturn.objects.create(**validated_data)
        
        total_items = 0
        total_quantity = 0
        total_value = 0
        
        for item_data in items_data:
            item_data['return_order'] = branch_return
            qty = item_data['requested_quantity']
            cost = item_data.get('unit_cost', 0) or 0
            item_data['total_value'] = qty * cost
            
            BranchReturnItem.objects.create(**item_data)
            total_items += 1
            total_quantity += qty
            total_value += item_data['total_value']
        
        branch_return.total_items = total_items
        branch_return.total_quantity = total_quantity
        branch_return.total_value = total_value
        branch_return.save()
        
        return branch_return


class BranchReturnApproveSerializer(serializers.Serializer):
    """Serializer for approving branch returns"""
    items = serializers.ListField(child=serializers.DictField())
    notes = serializers.CharField(required=False, allow_blank=True)
    
    def validate_items(self, value):
        for item in value:
            if 'item_id' not in item or 'approved_quantity' not in item:
                raise serializers.ValidationError(
                    "Each item must have 'item_id' and 'approved_quantity'"
                )
        return value


class BranchReturnReceiveSerializer(serializers.Serializer):
    """Serializer for receiving branch returns"""
    items = serializers.ListField(child=serializers.DictField())
    notes = serializers.CharField(required=False, allow_blank=True)
    
    def validate_items(self, value):
        for item in value:
            if 'item_id' not in item or 'received_quantity' not in item:
                raise serializers.ValidationError(
                    "Each item must have 'item_id' and 'received_quantity'"
                )
        return value
