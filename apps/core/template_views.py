from django.shortcuts import render
from django.contrib.auth.decorators import login_required
from django.db.models import Sum, F
from datetime import date

from apps.orders.models import Order
from apps.inventory.models import Inventory, Item
from apps.transfers.models import Transfer
from apps.suppliers.models import Supply
from apps.branches.models import Branch


@login_required
def dashboard(request):
    today = date.today()
    
    # Stats
    items_count = Item.objects.count()
    branches_count = Branch.objects.count()
    low_stock_items = Inventory.objects.filter(quantity__lte=F('min_quantity')).select_related('branch', 'item')
    low_stock_count = low_stock_items.count()
    today_orders = Order.objects.filter(created_at__date=today).count()
    
    # Recent supplies
    recent_supplies = Supply.objects.select_related('supplier').order_by('-received_at')[:5]
    
    # Pending transfers
    pending_transfers = Transfer.objects.filter(status='pending').select_related('from_branch', 'to_branch')[:5]
    
    context = {
        'items_count': items_count,
        'branches_count': branches_count,
        'low_stock_count': low_stock_count,
        'today_orders': today_orders,
        'recent_supplies': recent_supplies,
        'pending_transfers': pending_transfers,
        'low_stock_items': low_stock_items[:5],
    }
    return render(request, 'dashboard.html', context)
