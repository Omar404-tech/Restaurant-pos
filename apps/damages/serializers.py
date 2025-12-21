from rest_framework import serializers
from .models import Damage


class DamageSerializer(serializers.ModelSerializer):
    """Serializer for Damage model"""
    branch_name = serializers.CharField(source='branch.name', read_only=True)
    branch_code = serializers.CharField(source='branch.code', read_only=True)
    item_name = serializers.CharField(source='item.name', read_only=True)
    item_code = serializers.CharField(source='item.code', read_only=True)
    unit_name = serializers.CharField(source='item.unit.name', read_only=True)
    batch_number = serializers.CharField(source='batch.batch_number', read_only=True)
    reason_name = serializers.CharField(source='reason.name', read_only=True)
    registered_by_name = serializers.CharField(source='registered_by.full_name', read_only=True)
    approved_by_name = serializers.CharField(source='approved_by.full_name', read_only=True)
    
    class Meta:
        model = Damage
        fields = ['id', 'damage_number', 'branch', 'branch_code', 'branch_name',
                  'item', 'item_code', 'item_name', 'unit_name', 'batch', 'batch_number',
                  'quantity', 'unit_cost', 'total_cost', 'reason', 'reason_name',
                  'description', 'status', 'registered_by', 'registered_by_name',
                  'registered_at', 'approved_by', 'approved_by_name', 'approved_at',
                  'rejected_by', 'rejected_at', 'rejection_reason',
                  'created_at', 'updated_at']
        read_only_fields = ['id', 'damage_number', 'total_cost', 'created_at', 'updated_at']


class DamageListSerializer(serializers.ModelSerializer):
    """Lightweight serializer for Damage lists"""
    branch_code = serializers.CharField(source='branch.code', read_only=True)
    item_name = serializers.CharField(source='item.name', read_only=True)
    reason_name = serializers.CharField(source='reason.name', read_only=True)
    
    class Meta:
        model = Damage
        fields = ['id', 'damage_number', 'branch_code', 'item_name', 'quantity',
                  'total_cost', 'reason_name', 'status', 'registered_at']


class DamageCreateSerializer(serializers.ModelSerializer):
    """Serializer for creating damages"""
    class Meta:
        model = Damage
        fields = ['branch', 'item', 'batch', 'quantity', 'unit_cost', 'reason', 'description']


class DamageApproveSerializer(serializers.Serializer):
    """Serializer for approving damages"""
    notes = serializers.CharField(required=False, allow_blank=True)


class DamageRejectSerializer(serializers.Serializer):
    """Serializer for rejecting damages"""
    rejection_reason = serializers.CharField(required=True)
