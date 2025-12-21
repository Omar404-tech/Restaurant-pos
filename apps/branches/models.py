import uuid
from django.db import models


class Branch(models.Model):
    """Restaurant branches"""
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    code = models.CharField(max_length=20, unique=True)
    name = models.CharField(max_length=100)
    name_ar = models.CharField(max_length=100, blank=True)
    address = models.TextField(blank=True)
    phone = models.CharField(max_length=20, blank=True)
    email = models.EmailField(blank=True)
    
    BRANCH_TYPE_CHOICES = [
        ('main', 'Main Warehouse'),
        ('branch', 'Branch'),
    ]
    branch_type = models.CharField(max_length=20, choices=BRANCH_TYPE_CHOICES, default='branch')
    
    STATUS_CHOICES = [
        ('active', 'Active'),
        ('inactive', 'Inactive'),
        ('maintenance', 'Maintenance'),
    ]
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='active')
    
    is_main_warehouse = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'branches'
        verbose_name_plural = 'Branches'
        ordering = ['code']

    def __str__(self):
        return f"{self.code} - {self.name}"


class BranchSetting(models.Model):
    """Branch-specific settings"""
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    branch = models.ForeignKey(Branch, on_delete=models.CASCADE, related_name='settings')
    key = models.CharField(max_length=100)
    value = models.TextField()
    updated_by = models.ForeignKey('accounts.User', on_delete=models.SET_NULL, null=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'branch_settings'
        unique_together = ['branch', 'key']


class AlertSetting(models.Model):
    """Alert settings per branch"""
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    branch = models.ForeignKey(Branch, on_delete=models.CASCADE, related_name='alert_settings')
    alert_type = models.CharField(max_length=50)
    threshold = models.DecimalField(max_digits=12, decimal_places=3, null=True)
    is_enabled = models.BooleanField(default=True)
    notify_roles = models.JSONField(default=list)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'alert_settings'
