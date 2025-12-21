import uuid
from django.db import models
from apps.core.models import BaseModel


class Item(BaseModel):
    """Inventory items"""
    code = models.CharField(max_length=20, unique=True)
    name = models.CharField(max_length=100)
    name_ar = models.CharField(max_length=100, blank=True)
    description = models.TextField(blank=True)
    category = models.ForeignKey('core.Category', on_delete=models.SET_NULL, null=True, related_name='items')
    unit = models.ForeignKey('core.Unit', on_delete=models.SET_NULL, null=True, related_name='items')
    barcode = models.CharField(max_length=50, blank=True)
    
    purchase_price = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    selling_price = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    min_stock_level = models.DecimalField(max_digits=12, decimal_places=3, default=0)
    max_stock_level = models.DecimalField(max_digits=12, decimal_places=3, null=True, blank=True)
    reorder_level = models.DecimalField(max_digits=12, decimal_places=3, default=0)
    
    is_perishable = models.BooleanField(default=False)
    shelf_life_days = models.IntegerField(null=True, blank=True)
    
    STATUS_CHOICES = [
        ('active', 'Active'),
        ('inactive', 'Inactive'),
    ]
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='active')
    image = models.ImageField(upload_to='items/', blank=True, null=True)
    created_by = models.ForeignKey('accounts.User', on_delete=models.SET_NULL, null=True)

    class Meta:
        db_table = 'items'
        ordering = ['name']

    def __str__(self):
        return f"{self.code} - {self.name}"


class Inventory(BaseModel):
    """Inventory per branch"""
    branch = models.ForeignKey('branches.Branch', on_delete=models.CASCADE, related_name='inventory')
    item = models.ForeignKey(Item, on_delete=models.CASCADE, related_name='inventory')
    quantity = models.DecimalField(max_digits=12, decimal_places=3, default=0)
    reserved_quantity = models.DecimalField(max_digits=12, decimal_places=3, default=0)
    min_quantity = models.DecimalField(max_digits=12, decimal_places=3, default=0)
    
    # New fields for branch inventory
    entry_date = models.DateField(auto_now_add=True)
    document_number = models.CharField(max_length=30, blank=True)
    partial_quantity = models.DecimalField(max_digits=12, decimal_places=3, default=0)
    content_quantity = models.DecimalField(max_digits=12, decimal_places=3, default=0)
    total_quantity = models.DecimalField(max_digits=12, decimal_places=3, default=0)
    content_description = models.TextField(blank=True)
    
    # Main warehouse fields
    opening_balance = models.DecimalField(max_digits=12, decimal_places=3, default=0)
    incoming_quantity = models.DecimalField(max_digits=12, decimal_places=3, default=0)
    consumption_quantity = models.DecimalField(max_digits=12, decimal_places=3, default=0)
    consumption_description = models.TextField(blank=True)
    period_start_date = models.DateField(null=True, blank=True)
    period_end_date = models.DateField(null=True, blank=True)
    
    last_restock_date = models.DateTimeField(null=True, blank=True)
    last_count_date = models.DateTimeField(null=True, blank=True)

    class Meta:
        db_table = 'inventory'
        unique_together = ['branch', 'item']
        ordering = ['item__name']

    def __str__(self):
        return f"{self.branch.code} - {self.item.name}: {self.quantity}"
    
    def save(self, *args, **kwargs):
        # Auto-calculate total_quantity = partial * content
        self.total_quantity = self.partial_quantity * self.content_quantity
        super().save(*args, **kwargs)


class InventoryBatch(BaseModel):
    """Batch tracking for inventory"""
    inventory = models.ForeignKey(Inventory, on_delete=models.CASCADE, related_name='batches')
    batch_number = models.CharField(max_length=50)
    quantity = models.DecimalField(max_digits=12, decimal_places=3)
    remaining_quantity = models.DecimalField(max_digits=12, decimal_places=3)
    purchase_price = models.DecimalField(max_digits=12, decimal_places=2)
    expiry_date = models.DateField(null=True, blank=True)
    received_date = models.DateField()
    supply = models.ForeignKey('suppliers.Supply', on_delete=models.SET_NULL, null=True, blank=True)

    class Meta:
        db_table = 'inventory_batches'
        ordering = ['expiry_date', 'received_date']

    def __str__(self):
        return f"{self.batch_number} - {self.inventory.item.name}"


class InventoryTransaction(BaseModel):
    """All inventory movements"""
    branch = models.ForeignKey('branches.Branch', on_delete=models.CASCADE, related_name='transactions')
    item = models.ForeignKey(Item, on_delete=models.CASCADE, related_name='transactions')
    batch = models.ForeignKey(InventoryBatch, on_delete=models.SET_NULL, null=True, blank=True)
    
    OPERATION_CHOICES = [
        ('supply', 'Supply'),
        ('transfer_out', 'Transfer Out'),
        ('transfer_in', 'Transfer In'),
        ('consumption', 'Consumption'),
        ('damage', 'Damage'),
        ('return', 'Return'),
        ('adjustment', 'Adjustment'),
    ]
    operation_type = models.CharField(max_length=20, choices=OPERATION_CHOICES)
    
    quantity = models.DecimalField(max_digits=12, decimal_places=3)
    quantity_before = models.DecimalField(max_digits=12, decimal_places=3, null=True)
    quantity_after = models.DecimalField(max_digits=12, decimal_places=3, null=True)
    unit_cost = models.DecimalField(max_digits=12, decimal_places=2, null=True, blank=True)
    
    reference_type = models.CharField(max_length=50, blank=True)
    reference_id = models.UUIDField(null=True, blank=True)
    notes = models.TextField(blank=True)
    created_by = models.ForeignKey('accounts.User', on_delete=models.SET_NULL, null=True)

    class Meta:
        db_table = 'inventory_transactions'
        ordering = ['-created_at']

    def __str__(self):
        return f"{self.operation_type} - {self.item.name}: {self.quantity}"


class DailyInventoryCount(BaseModel):
    """Daily inventory counts"""
    branch = models.ForeignKey('branches.Branch', on_delete=models.CASCADE, related_name='daily_counts')
    count_date = models.DateField()
    
    COUNT_TYPE_CHOICES = [
        ('morning', 'Morning'),
        ('evening', 'Evening'),
    ]
    count_type = models.CharField(max_length=20, choices=COUNT_TYPE_CHOICES)
    
    STATUS_CHOICES = [
        ('draft', 'Draft'),
        ('submitted', 'Submitted'),
        ('approved', 'Approved'),
        ('rejected', 'Rejected'),
    ]
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='draft')
    
    notes = models.TextField(blank=True)
    counted_by = models.ForeignKey('accounts.User', on_delete=models.SET_NULL, null=True, related_name='counts_made')
    submitted_at = models.DateTimeField(null=True, blank=True)
    approved_by = models.ForeignKey('accounts.User', on_delete=models.SET_NULL, null=True, blank=True, related_name='counts_approved')
    approved_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        db_table = 'daily_inventory_counts'
        unique_together = ['branch', 'count_date', 'count_type']
        ordering = ['-count_date']


class DailyInventoryCountItem(BaseModel):
    """Items in daily count"""
    count = models.ForeignKey(DailyInventoryCount, on_delete=models.CASCADE, related_name='items')
    item = models.ForeignKey(Item, on_delete=models.CASCADE)
    system_quantity = models.DecimalField(max_digits=12, decimal_places=3)
    actual_quantity = models.DecimalField(max_digits=12, decimal_places=3)
    variance = models.DecimalField(max_digits=12, decimal_places=3, default=0)
    variance_reason = models.TextField(blank=True)

    class Meta:
        db_table = 'daily_inventory_count_items'
        unique_together = ['count', 'item']

    def save(self, *args, **kwargs):
        self.variance = self.actual_quantity - self.system_quantity
        super().save(*args, **kwargs)
