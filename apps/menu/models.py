import uuid
from django.db import models
from apps.core.models import BaseModel


class MenuCategory(BaseModel):
    """Menu categories"""
    code = models.CharField(max_length=20, unique=True)
    name = models.CharField(max_length=100)
    name_ar = models.CharField(max_length=100, blank=True)
    description = models.TextField(blank=True)
    parent = models.ForeignKey('self', on_delete=models.SET_NULL, null=True, blank=True, related_name='children')
    image = models.ImageField(upload_to='menu_categories/', blank=True, null=True)
    sort_order = models.IntegerField(default=0)
    is_active = models.BooleanField(default=True)

    class Meta:
        db_table = 'menu_categories'
        verbose_name_plural = 'Menu Categories'
        ordering = ['sort_order', 'name']

    def __str__(self):
        return self.name


class MenuItem(BaseModel):
    """Menu items"""
    code = models.CharField(max_length=20, unique=True)
    name = models.CharField(max_length=100)
    name_ar = models.CharField(max_length=100, blank=True)
    description = models.TextField(blank=True)
    category = models.ForeignKey(MenuCategory, on_delete=models.SET_NULL, null=True, related_name='items')
    
    price = models.DecimalField(max_digits=12, decimal_places=2)
    cost = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    tax_percent = models.DecimalField(max_digits=5, decimal_places=2, default=14)
    
    preparation_time = models.IntegerField(default=15, help_text='Minutes')
    image = models.ImageField(upload_to='menu_items/', blank=True, null=True)
    
    is_available = models.BooleanField(default=True)
    is_active = models.BooleanField(default=True)
    sort_order = models.IntegerField(default=0)

    class Meta:
        db_table = 'menu_items'
        ordering = ['sort_order', 'name']

    def __str__(self):
        return f"{self.code} - {self.name}"


class MenuItemIngredient(BaseModel):
    """Ingredients for menu items"""
    menu_item = models.ForeignKey(MenuItem, on_delete=models.CASCADE, related_name='ingredients')
    item = models.ForeignKey('inventory.Item', on_delete=models.PROTECT, related_name='menu_ingredients')
    quantity = models.DecimalField(max_digits=12, decimal_places=3)
    unit = models.ForeignKey('core.Unit', on_delete=models.SET_NULL, null=True)
    notes = models.TextField(blank=True)

    class Meta:
        db_table = 'menu_item_ingredients'
        unique_together = ['menu_item', 'item']

    def __str__(self):
        return f"{self.menu_item.name} - {self.item.name}"
