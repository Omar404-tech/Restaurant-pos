import uuid
from django.db import models
from apps.core.models import BaseModel


class Damage(BaseModel):
    """Damaged items"""
    damage_number = models.CharField(max_length=30, unique=True)
    branch = models.ForeignKey('branches.Branch', on_delete=models.PROTECT, related_name='damages')
    item = models.ForeignKey('inventory.Item', on_delete=models.PROTECT, related_name='damages')
    batch = models.ForeignKey('inventory.InventoryBatch', on_delete=models.SET_NULL, null=True, blank=True)
    
    quantity = models.DecimalField(max_digits=12, decimal_places=3)
    unit_cost = models.DecimalField(max_digits=12, decimal_places=2)
    total_cost = models.DecimalField(max_digits=12, decimal_places=2)
    
    reason = models.ForeignKey('core.DamageReason', on_delete=models.PROTECT, related_name='damages')
    description = models.TextField(blank=True)
    
    STATUS_CHOICES = [
        ('pending', 'Pending'),
        ('approved', 'Approved'),
        ('rejected', 'Rejected'),
    ]
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='pending')
    
    registered_by = models.ForeignKey('accounts.User', on_delete=models.SET_NULL, null=True, related_name='damages_registered')
    registered_at = models.DateTimeField(auto_now_add=True)
    approved_by = models.ForeignKey('accounts.User', on_delete=models.SET_NULL, null=True, blank=True, related_name='damages_approved')
    approved_at = models.DateTimeField(null=True, blank=True)
    rejected_by = models.ForeignKey('accounts.User', on_delete=models.SET_NULL, null=True, blank=True, related_name='damages_rejected')
    rejected_at = models.DateTimeField(null=True, blank=True)
    rejection_reason = models.TextField(blank=True)

    class Meta:
        db_table = 'damages'
        ordering = ['-created_at']

    def __str__(self):
        return f"{self.damage_number} - {self.item.name}"
    
    def save(self, *args, **kwargs):
        self.total_cost = self.quantity * self.unit_cost
        super().save(*args, **kwargs)
