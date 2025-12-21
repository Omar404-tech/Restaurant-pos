from rest_framework import serializers
from .models import Unit, Category, SystemSetting, DamageReason


class UnitSerializer(serializers.ModelSerializer):
    """Serializer for Unit model"""
    class Meta:
        model = Unit
        fields = ['id', 'code', 'name', 'name_ar', 'is_active', 'created_at', 'updated_at']
        read_only_fields = ['id', 'created_at', 'updated_at']


class UnitListSerializer(serializers.ModelSerializer):
    """Lightweight serializer for Unit lists"""
    class Meta:
        model = Unit
        fields = ['id', 'code', 'name', 'name_ar']


class CategorySerializer(serializers.ModelSerializer):
    """Serializer for Category model"""
    parent_name = serializers.CharField(source='parent.name', read_only=True)
    children_count = serializers.SerializerMethodField()
    
    class Meta:
        model = Category
        fields = ['id', 'code', 'name', 'name_ar', 'parent', 'parent_name', 
                  'children_count', 'is_active', 'created_at', 'updated_at']
        read_only_fields = ['id', 'created_at', 'updated_at']
    
    def get_children_count(self, obj):
        return obj.children.count()


class CategoryListSerializer(serializers.ModelSerializer):
    """Lightweight serializer for Category lists"""
    class Meta:
        model = Category
        fields = ['id', 'code', 'name', 'name_ar', 'parent']


class CategoryTreeSerializer(serializers.ModelSerializer):
    """Serializer for Category with nested children"""
    children = serializers.SerializerMethodField()
    
    class Meta:
        model = Category
        fields = ['id', 'code', 'name', 'name_ar', 'is_active', 'children']
    
    def get_children(self, obj):
        children = obj.children.filter(is_active=True)
        return CategoryTreeSerializer(children, many=True).data


class SystemSettingSerializer(serializers.ModelSerializer):
    """Serializer for SystemSetting model"""
    updated_by_name = serializers.CharField(source='updated_by.full_name', read_only=True)
    
    class Meta:
        model = SystemSetting
        fields = ['id', 'key', 'value', 'value_type', 'description', 
                  'updated_by', 'updated_by_name', 'created_at', 'updated_at']
        read_only_fields = ['id', 'created_at', 'updated_at']


class DamageReasonSerializer(serializers.ModelSerializer):
    """Serializer for DamageReason model"""
    class Meta:
        model = DamageReason
        fields = ['id', 'code', 'name', 'name_ar', 'description', 'is_active', 
                  'created_at', 'updated_at']
        read_only_fields = ['id', 'created_at', 'updated_at']


class DamageReasonListSerializer(serializers.ModelSerializer):
    """Lightweight serializer for DamageReason lists"""
    class Meta:
        model = DamageReason
        fields = ['id', 'code', 'name', 'name_ar']
