from django.shortcuts import render
from django.contrib.auth.decorators import login_required
from datetime import date

from apps.menu.models import MenuCategory, MenuItem
from apps.orders.models import Order


@login_required
def cashier_view(request):
    categories = MenuCategory.objects.filter(is_active=True, parent__isnull=True).order_by('sort_order')
    items = MenuItem.objects.filter(is_active=True, is_available=True).order_by('sort_order')
    return render(request, 'pos/cashier.html', {'categories': categories, 'items': items})


@login_required
def kitchen_view(request):
    branch = request.user.branch
    orders = Order.objects.filter(
        status__in=['in_kitchen', 'preparing'],
        created_at__date=date.today()
    ).order_by('sent_to_kitchen_at')
    
    if branch:
        orders = orders.filter(branch=branch)
    
    return render(request, 'pos/kitchen.html', {'orders': orders})
