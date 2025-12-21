import uuid
from django.db import models
from apps.core.models import BaseModel


class SupplierReturn(BaseModel):
    """Returns to suppliers"""
    return_number = models.CharField(max_length=30, unique=True)
    supply = models.ForeignKey('suppliers.Supply', on_delete=models.SET_NULL, null=True, related_name='returns')
    supplier = models.ForeignKey('suppliers.Supplier', on_delete=models.PROTECT, related_name='returns')
    item = models.ForeignKey('inventory.Item', on_delete=models.PROTECT, related_name='supplier_returns')
    
    quantity = models.DecimalField(max_digits=12, decimal_places=3)
    unit_price = models.DecimalField(max_digits=12, decimal_places=2)
    total_amount = models.DecimalField(max_digits=12, decimal_places=2)
    
    reason = models.TextField()
    description = models.TextField(blank=True)
    
    STATUS_CHOICES = [
        ('pending', 'Pending'),
        ('approved', 'Approved'),
        ('rejected', 'Rejected'),
        ('received', 'Received'),
    ]
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='pending')
    
    registered_by = models.ForeignKey('accounts.User', on_delete=models.SET_NULL, null=True, related_name='supplier_returns_registered')
    registered_at = models.DateTimeField(auto_now_add=True)
    approved_by = models.ForeignKey('accounts.User', on_delete=models.SET_NULL, null=True, blank=True, related_name='supplier_returns_approved')
    approved_at = models.DateTimeField(null=True, blank=True)
    rejected_by = models.ForeignKey('accounts.User', on_delete=models.SET_NULL, null=True, blank=True, related_name='supplier_returns_rejected')
    rejected_at = models.DateTimeField(null=True, blank=True)
    rejection_reason = models.TextField(blank=True)

    class Meta:
        db_table = 'supplier_returns'
        ordering = ['-created_at']

    def __str__(self):
        return f"{self.return_number} - {self.supplier.name}"
    
    def save(self, *args, **kwargs):
        self.total_amount = self.quantity * self.unit_price
        super().save(*args, **kwargs)


class BranchReturn(BaseModel):
    """Returns from branches to main warehouse"""
    return_number = models.CharField(max_length=30, unique=True)
    return_date = models.DateField()
    from_branch = models.ForeignKey('branches.Branch', on_delete=models.PROTECT, related_name='returns_out')
    to_branch = models.ForeignKey('branches.Branch', on_delete=models.PROTECT, related_name='returns_in')
    
    STATUS_CHOICES = [
        ('pending', 'Pending'),
        ('approved', 'Approved'),
        ('rejected', 'Rejected'),
        ('in_transit', 'In Transit'),
        ('received', 'Received'),
        ('cancelled', 'Cancelled'),
    ]
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='pending')
    
    return_reason = models.TextField()
    notes = models.TextField(blank=True)
    
    total_items = models.IntegerField(default=0)
    total_quantity = models.DecimalField(max_digits=12, decimal_places=3, default=0)
    total_value = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    
    requested_by = models.ForeignKey('accounts.User', on_delete=models.SET_NULL, null=True, related_name='branch_returns_requested')
    requested_at = models.DateTimeField(auto_now_add=True)
    approved_by = models.ForeignKey('accounts.User', on_delete=models.SET_NULL, null=True, blank=True, related_name='branch_returns_approved')
    approved_at = models.DateTimeField(null=True, blank=True)
    rejected_by = models.ForeignKey('accounts.User', on_delete=models.SET_NULL, null=True, blank=True, related_name='branch_returns_rejected')
    rejected_at = models.DateTimeField(null=True, blank=True)
    rejection_reason = models.TextField(blank=True)
    shipped_at = models.DateTimeField(null=True, blank=True)
    received_by = models.ForeignKey('accounts.User', on_delete=models.SET_NULL, null=True, blank=True, related_name='branch_returns_received')
    received_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        db_table = 'branch_returns'
        ordering = ['-return_date']

    def __str__(self):
        return f"{self.return_number}: {self.from_branch.code} -> {self.to_branch.code}"


class BranchReturnItem(BaseModel):
    """Items in branch return"""
    return_order = models.ForeignKey(BranchReturn, on_delete=models.CASCADE, related_name='items')
    item = models.ForeignKey('inventory.Item', on_delete=models.PROTECT, related_name='branch_return_items')
    batch = models.ForeignKey('inventory.InventoryBatch', on_delete=models.SET_NULL, null=True, blank=True)
    
    requested_quantity = models.DecimalField(max_digits=12, decimal_places=3)
    approved_quantity = models.DecimalField(max_digits=12, decimal_places=3, null=True, blank=True)
    shipped_quantity = models.DecimalField(max_digits=12, decimal_places=3, null=True, blank=True)
    received_quantity = models.DecimalField(max_digits=12, decimal_places=3, null=True, blank=True)
    
    unit_cost = models.DecimalField(max_digits=12, decimal_places=2, null=True, blank=True)
    total_value = models.DecimalField(max_digits=12, decimal_places=2, null=True, blank=True)
    
    item_reason = models.TextField(blank=True)
    notes = models.TextField(blank=True)

    class Meta:
        db_table = 'branch_return_items'
        unique_together = ['return_order', 'item']

    def __str__(self):
        return f"{self.return_order.return_number} - {self.item.name}"


class BranchReturnReason(BaseModel):
    """Reasons for branch returns"""
    code = models.CharField(max_length=20, unique=True)
    name = models.CharField(max_length=100)
    name_ar = models.CharField(max_length=100)
    description = models.TextField(blank=True)
    is_active = models.BooleanField(default=True)
    sort_order = models.IntegerField(default=0)

    class Meta:
        db_table = 'branch_return_reasons'
        ordering = ['sort_order']

    def __str__(self):
        return self.name
