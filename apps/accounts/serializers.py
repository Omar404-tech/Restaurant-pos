from rest_framework import serializers
from django.contrib.auth import authenticate
from django.contrib.auth.password_validation import validate_password
from .models import User, Role, UserSession, AuditLog, Notification


class RoleSerializer(serializers.ModelSerializer):
    """Serializer for Role model"""
    users_count = serializers.SerializerMethodField()
    
    class Meta:
        model = Role
        fields = ['id', 'name', 'name_ar', 'description', 'permissions', 
                  'is_active', 'users_count', 'created_at']
        read_only_fields = ['id', 'created_at']
    
    def get_users_count(self, obj):
        return obj.users.count()


class RoleListSerializer(serializers.ModelSerializer):
    """Lightweight serializer for Role lists"""
    class Meta:
        model = Role
        fields = ['id', 'name', 'name_ar']


class UserSerializer(serializers.ModelSerializer):
    """Serializer for User model"""
    role_name = serializers.CharField(source='role.name', read_only=True)
    branch_name = serializers.CharField(source='branch.name', read_only=True)
    branch_code = serializers.CharField(source='branch.code', read_only=True)
    
    class Meta:
        model = User
        fields = ['id', 'username', 'employee_code', 'full_name', 'full_name_ar',
                  'email', 'phone', 'role', 'role_name', 'branch', 'branch_name',
                  'branch_code', 'status', 'is_active', 'created_at', 'updated_at']
        read_only_fields = ['id', 'created_at', 'updated_at']


class UserListSerializer(serializers.ModelSerializer):
    """Lightweight serializer for User lists"""
    role_name = serializers.CharField(source='role.name', read_only=True)
    branch_code = serializers.CharField(source='branch.code', read_only=True)
    
    class Meta:
        model = User
        fields = ['id', 'username', 'employee_code', 'full_name', 'role_name', 
                  'branch_code', 'status']


class UserCreateSerializer(serializers.ModelSerializer):
    """Serializer for creating users"""
    password = serializers.CharField(write_only=True, required=True, validators=[validate_password])
    password_confirm = serializers.CharField(write_only=True, required=True)
    
    class Meta:
        model = User
        fields = ['username', 'employee_code', 'full_name', 'full_name_ar', 'email',
                  'phone', 'role', 'branch', 'password', 'password_confirm']
    
    def validate(self, attrs):
        if attrs['password'] != attrs['password_confirm']:
            raise serializers.ValidationError({"password": "Passwords don't match"})
        return attrs
    
    def create(self, validated_data):
        validated_data.pop('password_confirm')
        password = validated_data.pop('password')
        user = User.objects.create(**validated_data)
        user.set_password(password)
        user.save()
        return user


class UserUpdateSerializer(serializers.ModelSerializer):
    """Serializer for updating users"""
    class Meta:
        model = User
        fields = ['employee_code', 'full_name', 'full_name_ar', 'email',
                  'phone', 'role', 'branch', 'status']


class ChangePasswordSerializer(serializers.Serializer):
    """Serializer for password change"""
    old_password = serializers.CharField(required=True)
    new_password = serializers.CharField(required=True, validators=[validate_password])
    new_password_confirm = serializers.CharField(required=True)
    
    def validate(self, attrs):
        if attrs['new_password'] != attrs['new_password_confirm']:
            raise serializers.ValidationError({"new_password": "Passwords don't match"})
        return attrs
    
    def validate_old_password(self, value):
        user = self.context['request'].user
        if not user.check_password(value):
            raise serializers.ValidationError("Old password is incorrect")
        return value


class LoginSerializer(serializers.Serializer):
    """Serializer for user login"""
    username = serializers.CharField(required=True)
    password = serializers.CharField(required=True, write_only=True)
    
    def validate(self, attrs):
        user = authenticate(username=attrs['username'], password=attrs['password'])
        if not user:
            raise serializers.ValidationError("Invalid credentials")
        if user.status != 'active':
            raise serializers.ValidationError("User account is not active")
        attrs['user'] = user
        return attrs


class UserSessionSerializer(serializers.ModelSerializer):
    """Serializer for UserSession model"""
    user_name = serializers.CharField(source='user.full_name', read_only=True)
    
    class Meta:
        model = UserSession
        fields = ['id', 'user', 'user_name', 'session_token', 'ip_address',
                  'user_agent', 'login_at', 'logout_at', 'is_active']
        read_only_fields = ['id', 'login_at']


class AuditLogSerializer(serializers.ModelSerializer):
    """Serializer for AuditLog model"""
    user_name = serializers.CharField(source='user.full_name', read_only=True)
    
    class Meta:
        model = AuditLog
        fields = ['id', 'user', 'user_name', 'action', 'table_name', 'record_id',
                  'old_values', 'new_values', 'ip_address', 'user_agent', 'created_at']
        read_only_fields = ['id', 'created_at']


class NotificationSerializer(serializers.ModelSerializer):
    """Serializer for Notification model"""
    user_name = serializers.CharField(source='user.full_name', read_only=True)
    branch_name = serializers.CharField(source='branch.name', read_only=True)
    
    class Meta:
        model = Notification
        fields = ['id', 'user', 'user_name', 'branch', 'branch_name', 'type',
                  'title', 'message', 'priority', 'reference_type', 'reference_id',
                  'is_read', 'read_at', 'expires_at', 'created_at']
        read_only_fields = ['id', 'created_at']


class NotificationListSerializer(serializers.ModelSerializer):
    """Lightweight serializer for Notification lists"""
    class Meta:
        model = Notification
        fields = ['id', 'type', 'title', 'priority', 'is_read', 'created_at']
