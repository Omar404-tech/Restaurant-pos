import uuid
from django.db import models
from apps.core.models import BaseModel


class Order(BaseModel):
    """Customer orders"""
    order_number = models.CharField(max_length=30, unique=True)
    branch = models.ForeignKey('branches.Branch', on_delete=models.PROTECT, related_name='orders')
    
    ORDER_TYPE_CHOICES = [
        ('dine_in', 'Dine In'),
        ('takeaway', 'Takeaway'),
        ('delivery', 'Delivery'),
    ]
    order_type = models.CharField(max_length=20, choices=ORDER_TYPE_CHOICES, default='dine_in')
    
    table_number = models.CharField(max_length=10, blank=True)
    customer_name = models.CharField(max_length=100, blank=True)
    customer_phone = models.CharField(max_length=20, blank=True)
    customer_address = models.TextField(blank=True)
    
    subtotal = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    tax_amount = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    discount_amount = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    total_amount = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    
    PAYMENT_METHOD_CHOICES = [
        ('cash', 'Cash'),
        ('visa', 'Visa'),
        ('instapay', 'InstaPay'),
        ('wallet', 'Wallet'),
    ]
    payment_method = models.CharField(max_length=20, choices=PAYMENT_METHOD_CHOICES, null=True, blank=True)
    
    STATUS_CHOICES = [
        ('new', 'New'),
        ('pending_payment', 'Pending Payment'),
        ('paid', 'Paid'),
        ('in_kitchen', 'In Kitchen'),
        ('preparing', 'Preparing'),
        ('ready', 'Ready'),
        ('delivered', 'Delivered'),
        ('cancelled', 'Cancelled'),
    ]
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='new')
    
    notes = models.TextField(blank=True)
    
    cashier = models.ForeignKey('accounts.User', on_delete=models.SET_NULL, null=True, related_name='orders_cashier')
    chef = models.ForeignKey('accounts.User', on_delete=models.SET_NULL, null=True, blank=True, related_name='orders_chef')
    
    paid_at = models.DateTimeField(null=True, blank=True)
    sent_to_kitchen_at = models.DateTimeField(null=True, blank=True)
    preparation_started_at = models.DateTimeField(null=True, blank=True)
    ready_at = models.DateTimeField(null=True, blank=True)
    delivered_at = models.DateTimeField(null=True, blank=True)
    cancelled_at = models.DateTimeField(null=True, blank=True)
    cancelled_by = models.ForeignKey('accounts.User', on_delete=models.SET_NULL, null=True, blank=True, related_name='orders_cancelled')
    cancellation_reason = models.TextField(blank=True)

    class Meta:
        db_table = 'orders'
        ordering = ['-created_at']

    def __str__(self):
        return f"{self.order_number} - {self.branch.code}"


class OrderItem(BaseModel):
    """Items in an order"""
    order = models.ForeignKey(Order, on_delete=models.CASCADE, related_name='items')
    menu_item = models.ForeignKey('menu.MenuItem', on_delete=models.PROTECT, related_name='order_items')
    quantity = models.IntegerField(default=1)
    unit_price = models.DecimalField(max_digits=12, decimal_places=2)
    discount_amount = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    total_price = models.DecimalField(max_digits=12, decimal_places=2)
    
    STATUS_CHOICES = [
        ('pending', 'Pending'),
        ('in_kitchen', 'In Kitchen'),
        ('preparing', 'Preparing'),
        ('ready', 'Ready'),
        ('delivered', 'Delivered'),
        ('cancelled', 'Cancelled'),
    ]
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='pending')
    notes = models.TextField(blank=True)

    class Meta:
        db_table = 'order_items'

    def __str__(self):
        return f"{self.order.order_number} - {self.menu_item.name}"
    
    def save(self, *args, **kwargs):
        self.total_price = (self.unit_price * self.quantity) - self.discount_amount
        super().save(*args, **kwargs)
