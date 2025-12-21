from rest_framework import serializers
from .models import Branch, BranchSetting, AlertSetting


class BranchSerializer(serializers.ModelSerializer):
    """Serializer for Branch model"""
    users_count = serializers.SerializerMethodField()
    
    class Meta:
        model = Branch
        fields = ['id', 'code', 'name', 'name_ar', 'address', 'phone', 'email',
                  'branch_type', 'status', 'is_main_warehouse', 'users_count',
                  'created_at', 'updated_at']
        read_only_fields = ['id', 'created_at', 'updated_at']
    
    def get_users_count(self, obj):
        return obj.users.count()


class BranchListSerializer(serializers.ModelSerializer):
    """Lightweight serializer for Branch lists"""
    class Meta:
        model = Branch
        fields = ['id', 'code', 'name', 'branch_type', 'is_main_warehouse', 'status']


class BranchDetailSerializer(serializers.ModelSerializer):
    """Detailed serializer for Branch"""
    users_count = serializers.SerializerMethodField()
    inventory_count = serializers.SerializerMethodField()
    settings = serializers.SerializerMethodField()
    
    class Meta:
        model = Branch
        fields = ['id', 'code', 'name', 'name_ar', 'address', 'phone', 'email',
                  'branch_type', 'status', 'is_main_warehouse', 'users_count',
                  'inventory_count', 'settings', 'created_at', 'updated_at']
        read_only_fields = ['id', 'created_at', 'updated_at']
    
    def get_users_count(self, obj):
        return obj.users.count()
    
    def get_inventory_count(self, obj):
        return obj.inventory.count()
    
    def get_settings(self, obj):
        return {s.key: s.value for s in obj.settings.all()}


class BranchSettingSerializer(serializers.ModelSerializer):
    """Serializer for BranchSetting model"""
    updated_by_name = serializers.CharField(source='updated_by.full_name', read_only=True)
    
    class Meta:
        model = BranchSetting
        fields = ['id', 'branch', 'key', 'value', 'updated_by', 'updated_by_name', 'updated_at']
        read_only_fields = ['id', 'updated_at']


class AlertSettingSerializer(serializers.ModelSerializer):
    """Serializer for AlertSetting model"""
    branch_name = serializers.CharField(source='branch.name', read_only=True)
    
    class Meta:
        model = AlertSetting
        fields = ['id', 'branch', 'branch_name', 'alert_type', 'threshold',
                  'is_enabled', 'notify_roles', 'created_at']
        read_only_fields = ['id', 'created_at']
