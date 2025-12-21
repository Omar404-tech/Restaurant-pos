import uuid
from django.db import models


class BaseModel(models.Model):
    """Base model with common fields"""
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        abstract = True


class Unit(BaseModel):
    """Units of measurement"""
    code = models.CharField(max_length=10, unique=True)
    name = models.CharField(max_length=50)
    name_ar = models.CharField(max_length=50)
    is_active = models.BooleanField(default=True)

    class Meta:
        db_table = 'units'
        ordering = ['name']

    def __str__(self):
        return self.name


class Category(BaseModel):
    """Item categories"""
    code = models.CharField(max_length=20, unique=True)
    name = models.CharField(max_length=100)
    name_ar = models.CharField(max_length=100)
    parent = models.ForeignKey('self', on_delete=models.SET_NULL, null=True, blank=True, related_name='children')
    is_active = models.BooleanField(default=True)

    class Meta:
        db_table = 'categories'
        verbose_name_plural = 'Categories'
        ordering = ['name']

    def __str__(self):
        return self.name


class SystemSetting(BaseModel):
    """System-wide settings"""
    key = models.CharField(max_length=100, unique=True)
    value = models.TextField()
    value_type = models.CharField(max_length=20, default='string')
    description = models.TextField(blank=True)
    updated_by = models.ForeignKey('accounts.User', on_delete=models.SET_NULL, null=True)

    class Meta:
        db_table = 'system_settings'

    def __str__(self):
        return self.key


class DamageReason(BaseModel):
    """Reasons for damage"""
    code = models.CharField(max_length=20, unique=True)
    name = models.CharField(max_length=100)
    name_ar = models.CharField(max_length=100)
    description = models.TextField(blank=True)
    is_active = models.BooleanField(default=True)

    class Meta:
        db_table = 'damage_reasons'
        ordering = ['name']

    def __str__(self):
        return self.name
