from rest_framework import serializers
from .models import Transfer, TransferItem


class TransferItemSerializer(serializers.ModelSerializer):
    """Serializer for TransferItem model"""
    item_name = serializers.CharField(source='item.name', read_only=True)
    item_code = serializers.CharField(source='item.code', read_only=True)
    unit_name = serializers.CharField(source='item.unit.name', read_only=True)
    
    class Meta:
        model = TransferItem
        fields = ['id', 'transfer', 'item', 'item_code', 'item_name', 'unit_name',
                  'requested_quantity', 'approved_quantity', 'shipped_quantity',
                  'received_quantity', 'notes']
        read_only_fields = ['id']


class TransferSerializer(serializers.ModelSerializer):
    """Serializer for Transfer model"""
    from_branch_name = serializers.CharField(source='from_branch.name', read_only=True)
    from_branch_code = serializers.CharField(source='from_branch.code', read_only=True)
    to_branch_name = serializers.CharField(source='to_branch.name', read_only=True)
    to_branch_code = serializers.CharField(source='to_branch.code', read_only=True)
    requested_by_name = serializers.CharField(source='requested_by.full_name', read_only=True)
    approved_by_name = serializers.CharField(source='approved_by.full_name', read_only=True)
    received_by_name = serializers.CharField(source='received_by.full_name', read_only=True)
    items = TransferItemSerializer(many=True, read_only=True)
    items_count = serializers.SerializerMethodField()
    
    class Meta:
        model = Transfer
        fields = ['id', 'transfer_number', 'from_branch', 'from_branch_code',
                  'from_branch_name', 'to_branch', 'to_branch_code', 'to_branch_name',
                  'status', 'priority', 'notes', 'items', 'items_count',
                  'requested_by', 'requested_by_name', 'requested_at',
                  'approved_by', 'approved_by_name', 'approved_at',
                  'rejected_by', 'rejected_at', 'rejection_reason',
                  'received_by', 'received_by_name', 'received_at',
                  'created_at', 'updated_at']
        read_only_fields = ['id', 'transfer_number', 'created_at', 'updated_at']
    
    def get_items_count(self, obj):
        return obj.items.count()


class TransferListSerializer(serializers.ModelSerializer):
    """Lightweight serializer for Transfer lists"""
    from_branch_code = serializers.CharField(source='from_branch.code', read_only=True)
    to_branch_code = serializers.CharField(source='to_branch.code', read_only=True)
    requested_by_name = serializers.CharField(source='requested_by.full_name', read_only=True)
    items_count = serializers.SerializerMethodField()
    
    class Meta:
        model = Transfer
        fields = ['id', 'transfer_number', 'from_branch_code', 'to_branch_code',
                  'status', 'priority', 'items_count', 'requested_by_name', 'requested_at']
    
    def get_items_count(self, obj):
        return obj.items.count()


class TransferCreateSerializer(serializers.ModelSerializer):
    """Serializer for creating transfers"""
    items = TransferItemSerializer(many=True)
    
    class Meta:
        model = Transfer
        fields = ['from_branch', 'to_branch', 'priority', 'notes', 'items']
    
    def create(self, validated_data):
        items_data = validated_data.pop('items')
        transfer = Transfer.objects.create(**validated_data)
        
        for item_data in items_data:
            item_data['transfer'] = transfer
            TransferItem.objects.create(**item_data)
        
        return transfer


class TransferApproveSerializer(serializers.Serializer):
    """Serializer for approving transfers"""
    items = serializers.ListField(child=serializers.DictField())
    notes = serializers.CharField(required=False, allow_blank=True)
    
    def validate_items(self, value):
        for item in value:
            if 'item_id' not in item or 'approved_quantity' not in item:
                raise serializers.ValidationError(
                    "Each item must have 'item_id' and 'approved_quantity'"
                )
        return value


class TransferReceiveSerializer(serializers.Serializer):
    """Serializer for receiving transfers"""
    items = serializers.ListField(child=serializers.DictField())
    notes = serializers.CharField(required=False, allow_blank=True)
    
    def validate_items(self, value):
        for item in value:
            if 'item_id' not in item or 'received_quantity' not in item:
                raise serializers.ValidationError(
                    "Each item must have 'item_id' and 'received_quantity'"
                )
        return value
