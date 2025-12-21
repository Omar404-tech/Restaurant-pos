from django.shortcuts import render
from django.contrib.auth.decorators import login_required
from django.db.models import Sum, Count
from datetime import date, timedelta

from apps.orders.models import Order
from apps.inventory.models import Inventory
from apps.suppliers.models import Supplier


@login_required
def reports_index(request):
    return render(request, 'reports/index.html')


@login_required
def sales_report(request):
    start_date = request.GET.get('start_date', date.today() - timedelta(days=30))
    end_date = request.GET.get('end_date', date.today())
    
    orders = Order.objects.filter(
        created_at__date__gte=start_date,
        created_at__date__lte=end_date
    ).exclude(status='cancelled')
    
    summary = {
        'total_orders': orders.count(),
        'total_amount': orders.aggregate(total=Sum('total_amount'))['total'] or 0,
        'total_tax': orders.aggregate(total=Sum('tax_amount'))['total'] or 0,
    }
    
    return render(request, 'reports/sales.html', {'summary': summary, 'orders': orders[:100]})


@login_required
def inventory_report(request):
    inventory = Inventory.objects.all().select_related('branch', 'item')
    return render(request, 'reports/inventory.html', {'inventory': inventory})


@login_required
def suppliers_report(request):
    suppliers = Supplier.objects.annotate(
        supplies_count=Count('supplies'),
        total_supplies=Sum('supplies__total_amount')
    )
    return render(request, 'reports/suppliers.html', {'suppliers': suppliers})
