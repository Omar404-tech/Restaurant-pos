import uuid
from django.db import models
from apps.core.models import BaseModel


class Transfer(BaseModel):
    """Transfers between branches"""
    transfer_number = models.CharField(max_length=30, unique=True)
    from_branch = models.ForeignKey('branches.Branch', on_delete=models.PROTECT, related_name='transfers_out')
    to_branch = models.ForeignKey('branches.Branch', on_delete=models.PROTECT, related_name='transfers_in')
    
    STATUS_CHOICES = [
        ('pending', 'Pending'),
        ('approved', 'Approved'),
        ('rejected', 'Rejected'),
        ('received', 'Received'),
        ('cancelled', 'Cancelled'),
    ]
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='pending')
    priority = models.IntegerField(default=1)
    notes = models.TextField(blank=True)
    
    requested_by = models.ForeignKey('accounts.User', on_delete=models.SET_NULL, null=True, related_name='transfers_requested')
    requested_at = models.DateTimeField(auto_now_add=True)
    approved_by = models.ForeignKey('accounts.User', on_delete=models.SET_NULL, null=True, blank=True, related_name='transfers_approved')
    approved_at = models.DateTimeField(null=True, blank=True)
    rejected_by = models.ForeignKey('accounts.User', on_delete=models.SET_NULL, null=True, blank=True, related_name='transfers_rejected')
    rejected_at = models.DateTimeField(null=True, blank=True)
    rejection_reason = models.TextField(blank=True)
    received_by = models.ForeignKey('accounts.User', on_delete=models.SET_NULL, null=True, blank=True, related_name='transfers_received')
    received_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        db_table = 'transfers'
        ordering = ['-created_at']

    def __str__(self):
        return f"{self.transfer_number}: {self.from_branch.code} -> {self.to_branch.code}"


class TransferItem(BaseModel):
    """Items in a transfer"""
    transfer = models.ForeignKey(Transfer, on_delete=models.CASCADE, related_name='items')
    item = models.ForeignKey('inventory.Item', on_delete=models.PROTECT, related_name='transfer_items')
    requested_quantity = models.DecimalField(max_digits=12, decimal_places=3)
    approved_quantity = models.DecimalField(max_digits=12, decimal_places=3, null=True, blank=True)
    shipped_quantity = models.DecimalField(max_digits=12, decimal_places=3, null=True, blank=True)
    received_quantity = models.DecimalField(max_digits=12, decimal_places=3, null=True, blank=True)
    notes = models.TextField(blank=True)

    class Meta:
        db_table = 'transfer_items'
        unique_together = ['transfer', 'item']

    def __str__(self):
        return f"{self.transfer.transfer_number} - {self.item.name}"
