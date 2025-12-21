from django.shortcuts import render, redirect, get_object_or_404
from django.contrib.auth.decorators import login_required
from django.contrib import messages
from django.core.paginator import Paginator
from django.db.models import F
from django.utils import timezone

from .models import Item, Inventory, DailyInventoryCount
from apps.core.models import Category, Unit


@login_required
def item_list(request):
    items = Item.objects.all().select_related('category', 'unit')
    search = request.GET.get('search')
    category = request.GET.get('category')
    
    if search:
        items = items.filter(name__icontains=search) | items.filter(code__icontains=search)
    if category:
        items = items.filter(category_id=category)
    
    paginator = Paginator(items, 20)
    page = request.GET.get('page')
    items = paginator.get_page(page)
    categories = Category.objects.filter(is_active=True)
    return render(request, 'inventory/item_list.html', {'items': items, 'categories': categories})


@login_required
def item_create(request):
    if request.method == 'POST':
        Item.objects.create(
            code=request.POST.get('code'),
            name=request.POST.get('name'),
            category_id=request.POST.get('category') or None,
            unit_id=request.POST.get('unit') or None,
            purchase_price=request.POST.get('purchase_price', 0),
            min_stock_level=request.POST.get('min_stock_level', 0),
            created_by=request.user
        )
        messages.success(request, 'تم إنشاء الصنف بنجاح')
        return redirect('inventory:item_list')
    
    categories = Category.objects.filter(is_active=True)
    units = Unit.objects.filter(is_active=True)
    return render(request, 'inventory/item_form.html', {'categories': categories, 'units': units})


@login_required
def item_detail(request, pk):
    item = get_object_or_404(Item, pk=pk)
    inventory = item.inventory.all().select_related('branch')
    return render(request, 'inventory/item_detail.html', {'item': item, 'inventory': inventory})


@login_required
def item_edit(request, pk):
    item = get_object_or_404(Item, pk=pk)
    if request.method == 'POST':
        item.name = request.POST.get('name')
        item.category_id = request.POST.get('category') or None
        item.unit_id = request.POST.get('unit') or None
        item.purchase_price = request.POST.get('purchase_price', 0)
        item.min_stock_level = request.POST.get('min_stock_level', 0)
        item.status = request.POST.get('status', 'active')
        item.save()
        messages.success(request, 'تم تحديث الصنف بنجاح')
        return redirect('inventory:item_list')
    
    categories = Category.objects.filter(is_active=True)
    units = Unit.objects.filter(is_active=True)
    return render(request, 'inventory/item_form.html', {'item': item, 'categories': categories, 'units': units, 'edit': True})


@login_required
def stock_list(request):
    inventory = Inventory.objects.all().select_related('branch', 'item')
    branch = request.GET.get('branch')
    if branch:
        inventory = inventory.filter(branch_id=branch)
    
    paginator = Paginator(inventory, 20)
    page = request.GET.get('page')
    inventory = paginator.get_page(page)
    
    from apps.branches.models import Branch
    branches = Branch.objects.all()
    return render(request, 'inventory/stock_list.html', {'inventory': inventory, 'branches': branches})


@login_required
def low_stock(request):
    inventory = Inventory.objects.filter(quantity__lte=F('min_quantity')).select_related('branch', 'item')
    return render(request, 'inventory/low_stock.html', {'inventory': inventory})


@login_required
def daily_count_list(request):
    counts = DailyInventoryCount.objects.all().select_related('branch', 'counted_by')
    paginator = Paginator(counts, 20)
    page = request.GET.get('page')
    counts = paginator.get_page(page)
    return render(request, 'inventory/daily_count_list.html', {'counts': counts})


@login_required
def daily_count_create(request):
    if request.method == 'POST':
        from datetime import date
        DailyInventoryCount.objects.create(
            branch=request.user.branch,
            count_date=date.today(),
            count_type=request.POST.get('count_type', 'morning'),
            counted_by=request.user
        )
        messages.success(request, 'تم إنشاء الجرد بنجاح')
        return redirect('inventory:daily_count_list')
    return render(request, 'inventory/daily_count_form.html')


# ==================== Chef Daily Consumption Views ====================

@login_required
def consumption_dashboard(request):
    """Chef consumption dashboard"""
    from datetime import date, timedelta
    from django.db.models import Sum
    
    today = date.today()
    
    # Today's counts
    morning_count = DailyInventoryCount.objects.filter(
        count_date=today, count_type='morning'
    ).first()
    
    evening_count = DailyInventoryCount.objects.filter(
        count_date=today, count_type='evening'
    ).first()
    
    # Calculate consumption if both counts exist
    consumption_data = []
    if morning_count and evening_count:
        morning_items = {i.item_id: i.actual_quantity for i in morning_count.items.all()}
        for evening_item in evening_count.items.all():
            morning_qty = morning_items.get(evening_item.item_id, 0)
            consumption = morning_qty - evening_item.actual_quantity
            consumption_data.append({
                'item': evening_item.item,
                'morning': morning_qty,
                'evening': evening_item.actual_quantity,
                'consumption': consumption
            })
    
    # Recent consumption history
    recent_counts = DailyInventoryCount.objects.filter(
        count_date__gte=today - timedelta(days=7)
    ).select_related('branch', 'counted_by').order_by('-count_date', '-count_type')[:20]
    
    # Branch filter
    from apps.branches.models import Branch
    branches = Branch.objects.filter(status='active')
    
    return render(request, 'inventory/consumption_dashboard.html', {
        'today': today,
        'morning_count': morning_count,
        'evening_count': evening_count,
        'consumption_data': consumption_data,
        'recent_counts': recent_counts,
        'branches': branches
    })


@login_required
def consumption_record(request):
    """Record daily consumption (morning/evening count)"""
    from datetime import date
    from apps.branches.models import Branch
    
    if request.method == 'POST':
        branch_id = request.POST.get('branch')
        count_type = request.POST.get('count_type')
        count_date = request.POST.get('count_date') or date.today()
        
        # Check if count already exists
        existing = DailyInventoryCount.objects.filter(
            branch_id=branch_id,
            count_date=count_date,
            count_type=count_type
        ).first()
        
        if existing:
            messages.warning(request, f'يوجد جرد {count_type} بالفعل لهذا التاريخ')
            return redirect('inventory:consumption_count_detail', pk=existing.pk)
        
        # Create new count
        count = DailyInventoryCount.objects.create(
            branch_id=branch_id,
            count_date=count_date,
            count_type=count_type,
            counted_by=request.user,
            status='draft'
        )
        
        messages.success(request, 'تم إنشاء الجرد بنجاح - قم بإضافة الأصناف')
        return redirect('inventory:consumption_count_detail', pk=count.pk)
    
    branches = Branch.objects.filter(status='active')
    return render(request, 'inventory/consumption_record.html', {'branches': branches})


@login_required
def consumption_count_detail(request, pk):
    """View and edit daily count details"""
    from .models import DailyInventoryCountItem
    
    count = get_object_or_404(DailyInventoryCount, pk=pk)
    items = count.items.all().select_related('item')
    
    # Get all inventory items for this branch
    inventory_items = Inventory.objects.filter(branch=count.branch).select_related('item')
    
    return render(request, 'inventory/consumption_count_detail.html', {
        'count': count,
        'items': items,
        'inventory_items': inventory_items
    })


@login_required
def consumption_add_item(request, pk):
    """Add item to daily count"""
    from .models import DailyInventoryCountItem
    
    count = get_object_or_404(DailyInventoryCount, pk=pk)
    
    if request.method == 'POST' and count.status == 'draft':
        item_id = request.POST.get('item')
        actual_qty = float(request.POST.get('actual_quantity', 0))
        
        # Get system quantity from inventory
        inventory = Inventory.objects.filter(branch=count.branch, item_id=item_id).first()
        system_qty = inventory.quantity if inventory else 0
        
        # Check if item already exists
        existing = DailyInventoryCountItem.objects.filter(count=count, item_id=item_id).first()
        if existing:
            existing.actual_quantity = actual_qty
            existing.system_quantity = system_qty
            existing.save()
            messages.success(request, 'تم تحديث الصنف')
        else:
            DailyInventoryCountItem.objects.create(
                count=count,
                item_id=item_id,
                system_quantity=system_qty,
                actual_quantity=actual_qty,
                variance_reason=request.POST.get('variance_reason', '')
            )
            messages.success(request, 'تم إضافة الصنف')
    
    return redirect('inventory:consumption_count_detail', pk=pk)


@login_required
def consumption_submit(request, pk):
    """Submit daily count"""
    count = get_object_or_404(DailyInventoryCount, pk=pk)
    
    if count.status == 'draft' and count.items.exists():
        count.status = 'submitted'
        count.submitted_at = timezone.now()
        count.save()
        messages.success(request, 'تم إرسال الجرد للمراجعة')
    else:
        messages.error(request, 'لا يمكن إرسال الجرد - تأكد من إضافة أصناف')
    
    return redirect('inventory:consumption_count_detail', pk=pk)


@login_required
def consumption_approve(request, pk):
    """Approve daily count and update inventory"""
    count = get_object_or_404(DailyInventoryCount, pk=pk)
    
    if count.status == 'submitted':
        count.status = 'approved'
        count.approved_by = request.user
        count.approved_at = timezone.now()
        count.save()
        
        # Update inventory quantities based on actual count
        for item in count.items.all():
            inventory = Inventory.objects.filter(branch=count.branch, item=item.item).first()
            if inventory:
                inventory.quantity = item.actual_quantity
                inventory.last_count_date = timezone.now()
                inventory.save()
        
        messages.success(request, 'تم الموافقة على الجرد وتحديث المخزون')
    
    return redirect('inventory:consumption_count_detail', pk=pk)


@login_required
def consumption_report(request):
    """Consumption report"""
    from datetime import date, timedelta
    from django.db.models import Sum
    from apps.branches.models import Branch
    
    # Date range
    end_date = date.today()
    start_date = end_date - timedelta(days=30)
    
    if request.GET.get('start_date'):
        start_date = date.fromisoformat(request.GET.get('start_date'))
    if request.GET.get('end_date'):
        end_date = date.fromisoformat(request.GET.get('end_date'))
    
    branch_id = request.GET.get('branch')
    
    # Get counts in date range
    counts = DailyInventoryCount.objects.filter(
        count_date__range=[start_date, end_date],
        status='approved'
    ).select_related('branch')
    
    if branch_id:
        counts = counts.filter(branch_id=branch_id)
    
    # Calculate daily consumption
    consumption_by_date = {}
    for count in counts:
        date_key = count.count_date.isoformat()
        if date_key not in consumption_by_date:
            consumption_by_date[date_key] = {'morning': None, 'evening': None, 'branch': count.branch}
        consumption_by_date[date_key][count.count_type] = count
    
    # Calculate consumption for each day
    daily_consumption = []
    for date_key, data in sorted(consumption_by_date.items()):
        if data['morning'] and data['evening']:
            morning_total = sum(i.actual_quantity for i in data['morning'].items.all())
            evening_total = sum(i.actual_quantity for i in data['evening'].items.all())
            daily_consumption.append({
                'date': date_key,
                'branch': data['branch'],
                'morning_total': morning_total,
                'evening_total': evening_total,
                'consumption': morning_total - evening_total
            })
    
    branches = Branch.objects.filter(status='active')
    
    return render(request, 'inventory/consumption_report.html', {
        'daily_consumption': daily_consumption,
        'branches': branches,
        'start_date': start_date,
        'end_date': end_date,
        'selected_branch': branch_id
    })
