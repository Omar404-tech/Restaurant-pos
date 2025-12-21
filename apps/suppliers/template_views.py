from django.shortcuts import render, redirect, get_object_or_404
from django.contrib.auth.decorators import login_required
from django.contrib import messages
from django.core.paginator import Paginator
from django.utils import timezone
from django.db.models import Sum, Count
import uuid

from .models import Supplier, Supply, SupplyItem, SupplierPayment, PurchaseRequest, PurchaseRequestItem, PurchaseOrder, PurchaseOrderItem
from apps.inventory.models import Item
from apps.branches.models import Branch


@login_required
def supplier_list(request):
    suppliers = Supplier.objects.all()
    search = request.GET.get('search')
    if search:
        suppliers = suppliers.filter(name__icontains=search) | suppliers.filter(code__icontains=search)
    
    paginator = Paginator(suppliers, 20)
    page = request.GET.get('page')
    suppliers = paginator.get_page(page)
    return render(request, 'suppliers/list.html', {'suppliers': suppliers})


@login_required
def supplier_create(request):
    if request.method == 'POST':
        Supplier.objects.create(
            code=request.POST.get('code'),
            name=request.POST.get('name'),
            phone=request.POST.get('phone'),
            contact_person=request.POST.get('contact_person', ''),
            address=request.POST.get('address', ''),
            payment_method=request.POST.get('payment_method', 'cash'),
            created_by=request.user
        )
        messages.success(request, 'تم إنشاء المورد بنجاح')
        return redirect('suppliers:list')
    return render(request, 'suppliers/form.html')


@login_required
def supplier_detail(request, pk):
    supplier = get_object_or_404(Supplier, pk=pk)
    supplies = supplier.supplies.all()[:10]
    payments = supplier.payments.all()[:10]
    return render(request, 'suppliers/detail.html', {
        'supplier': supplier,
        'supplies': supplies,
        'payments': payments
    })


@login_required
def supplier_edit(request, pk):
    supplier = get_object_or_404(Supplier, pk=pk)
    if request.method == 'POST':
        supplier.name = request.POST.get('name')
        supplier.phone = request.POST.get('phone')
        supplier.contact_person = request.POST.get('contact_person', '')
        supplier.address = request.POST.get('address', '')
        supplier.status = request.POST.get('status', 'active')
        supplier.save()
        messages.success(request, 'تم تحديث المورد بنجاح')
        return redirect('suppliers:list')
    return render(request, 'suppliers/form.html', {'supplier': supplier, 'edit': True})


@login_required
def supply_list(request):
    supplies = Supply.objects.all().select_related('supplier', 'branch')
    supplier_id = request.GET.get('supplier')
    if supplier_id:
        supplies = supplies.filter(supplier_id=supplier_id)
    
    paginator = Paginator(supplies, 20)
    page = request.GET.get('page')
    supplies = paginator.get_page(page)
    suppliers = Supplier.objects.all()
    return render(request, 'suppliers/supply_list.html', {'supplies': supplies, 'suppliers': suppliers})


@login_required
def supply_create(request):
    if request.method == 'POST':
        supply_number = f"SUP-{timezone.now().strftime('%Y%m%d')}-{str(uuid.uuid4())[:8].upper()}"
        supply = Supply.objects.create(
            supply_number=supply_number,
            supplier_id=request.POST.get('supplier'),
            branch_id=request.POST.get('branch'),
            invoice_number=request.POST.get('invoice_number', ''),
            payment_method=request.POST.get('payment_method', 'cash'),
            received_by=request.user,
            received_at=timezone.now()
        )
        messages.success(request, f'تم إنشاء التوريد {supply_number} بنجاح')
        return redirect('suppliers:supply_detail', pk=supply.pk)
    
    suppliers = Supplier.objects.filter(status='active')
    branches = Branch.objects.filter(status='active')
    return render(request, 'suppliers/supply_form.html', {'suppliers': suppliers, 'branches': branches})


@login_required
def supply_detail(request, pk):
    supply = get_object_or_404(Supply, pk=pk)
    return render(request, 'suppliers/supply_detail.html', {'supply': supply})


@login_required
def payment_list(request):
    payments = SupplierPayment.objects.all().select_related('supplier')
    paginator = Paginator(payments, 20)
    page = request.GET.get('page')
    payments = paginator.get_page(page)
    return render(request, 'suppliers/payment_list.html', {'payments': payments})


@login_required
def payment_create(request):
    if request.method == 'POST':
        payment_number = f"PAY-{timezone.now().strftime('%Y%m%d')}-{str(uuid.uuid4())[:8].upper()}"
        supplier = Supplier.objects.get(pk=request.POST.get('supplier'))
        amount = float(request.POST.get('amount'))
        
        SupplierPayment.objects.create(
            payment_number=payment_number,
            supplier=supplier,
            amount=amount,
            payment_method=request.POST.get('payment_method'),
            payment_date=request.POST.get('payment_date'),
            created_by=request.user
        )
        
        supplier.current_balance -= amount
        supplier.save()
        
        messages.success(request, 'تم تسجيل السداد بنجاح')
        return redirect('suppliers:payment_list')
    
    suppliers = Supplier.objects.filter(status='active')
    return render(request, 'suppliers/payment_form.html', {'suppliers': suppliers})


# ==================== Purchase Manager Views ====================

@login_required
def purchase_request_list(request):
    """List all purchase requests"""
    requests = PurchaseRequest.objects.all().select_related('branch', 'requested_by', 'approved_by')
    
    status = request.GET.get('status')
    if status:
        requests = requests.filter(status=status)
    
    branch = request.GET.get('branch')
    if branch:
        requests = requests.filter(branch_id=branch)
    
    paginator = Paginator(requests, 20)
    page = request.GET.get('page')
    requests = paginator.get_page(page)
    
    branches = Branch.objects.filter(status='active')
    status_choices = PurchaseRequest.STATUS_CHOICES
    
    return render(request, 'suppliers/purchase_request_list.html', {
        'requests': requests,
        'branches': branches,
        'status_choices': status_choices
    })


@login_required
def purchase_request_create(request):
    """Create new purchase request"""
    if request.method == 'POST':
        request_number = f"PR-{timezone.now().strftime('%Y%m%d')}-{str(uuid.uuid4())[:8].upper()}"
        
        pr = PurchaseRequest.objects.create(
            request_number=request_number,
            request_date=timezone.now().date(),
            branch_id=request.POST.get('branch'),
            priority=int(request.POST.get('priority', 1)),
            notes=request.POST.get('notes', ''),
            requested_by=request.user,
            status='draft'
        )
        
        messages.success(request, f'تم إنشاء طلب الشراء {request_number} بنجاح')
        return redirect('suppliers:purchase_request_detail', pk=pr.pk)
    
    branches = Branch.objects.filter(status='active')
    return render(request, 'suppliers/purchase_request_form.html', {'branches': branches})


@login_required
def purchase_request_detail(request, pk):
    """View purchase request details"""
    pr = get_object_or_404(PurchaseRequest, pk=pk)
    items = pr.items.all().select_related('item', 'supplier')
    available_items = Item.objects.filter(status='active')
    suppliers = Supplier.objects.filter(status='active')
    
    return render(request, 'suppliers/purchase_request_detail.html', {
        'pr': pr,
        'items': items,
        'available_items': available_items,
        'suppliers': suppliers
    })


@login_required
def purchase_request_add_item(request, pk):
    """Add item to purchase request"""
    pr = get_object_or_404(PurchaseRequest, pk=pk)
    
    if request.method == 'POST':
        item_id = request.POST.get('item')
        quantity = float(request.POST.get('quantity', 0))
        supplier_id = request.POST.get('supplier') or None
        estimated_price = request.POST.get('estimated_price') or None
        
        PurchaseRequestItem.objects.create(
            request=pr,
            item_id=item_id,
            supplier_id=supplier_id,
            requested_quantity=quantity,
            estimated_unit_price=estimated_price,
            notes=request.POST.get('notes', '')
        )
        
        # Update totals
        pr.total_items = pr.items.count()
        pr.total_quantity = pr.items.aggregate(total=Sum('requested_quantity'))['total'] or 0
        pr.save()
        
        messages.success(request, 'تم إضافة الصنف بنجاح')
    
    return redirect('suppliers:purchase_request_detail', pk=pk)


@login_required
def purchase_request_submit(request, pk):
    """Submit purchase request for approval"""
    pr = get_object_or_404(PurchaseRequest, pk=pk)
    
    if pr.status == 'draft' and pr.items.exists():
        pr.status = 'pending'
        pr.save()
        messages.success(request, 'تم إرسال طلب الشراء للموافقة')
    else:
        messages.error(request, 'لا يمكن إرسال الطلب - تأكد من إضافة أصناف')
    
    return redirect('suppliers:purchase_request_detail', pk=pk)


@login_required
def purchase_request_approve(request, pk):
    """Approve purchase request"""
    pr = get_object_or_404(PurchaseRequest, pk=pk)
    
    if pr.status == 'pending':
        pr.status = 'approved'
        pr.approved_by = request.user
        pr.approved_at = timezone.now()
        
        # Set approved quantities
        for item in pr.items.all():
            if item.approved_quantity is None:
                item.approved_quantity = item.requested_quantity
                item.save()
        
        pr.save()
        messages.success(request, 'تم الموافقة على طلب الشراء')
    
    return redirect('suppliers:purchase_request_detail', pk=pk)


@login_required
def purchase_request_reject(request, pk):
    """Reject purchase request"""
    pr = get_object_or_404(PurchaseRequest, pk=pk)
    
    if pr.status == 'pending':
        pr.status = 'rejected'
        pr.rejected_by = request.user
        pr.rejected_at = timezone.now()
        pr.rejection_reason = request.POST.get('reason', '')
        pr.save()
        messages.success(request, 'تم رفض طلب الشراء')
    
    return redirect('suppliers:purchase_request_detail', pk=pk)


@login_required
def purchase_order_list(request):
    """List all purchase orders"""
    orders = PurchaseOrder.objects.all().select_related('supplier', 'branch', 'created_by')
    
    status = request.GET.get('status')
    if status:
        orders = orders.filter(status=status)
    
    supplier = request.GET.get('supplier')
    if supplier:
        orders = orders.filter(supplier_id=supplier)
    
    paginator = Paginator(orders, 20)
    page = request.GET.get('page')
    orders = paginator.get_page(page)
    
    suppliers = Supplier.objects.filter(status='active')
    status_choices = PurchaseOrder.STATUS_CHOICES
    
    return render(request, 'suppliers/purchase_order_list.html', {
        'orders': orders,
        'suppliers': suppliers,
        'status_choices': status_choices
    })


@login_required
def purchase_order_create(request):
    """Create purchase order from approved request"""
    if request.method == 'POST':
        order_number = f"PO-{timezone.now().strftime('%Y%m%d')}-{str(uuid.uuid4())[:8].upper()}"
        
        request_id = request.POST.get('request')
        pr = PurchaseRequest.objects.get(pk=request_id) if request_id else None
        
        po = PurchaseOrder.objects.create(
            order_number=order_number,
            request=pr,
            supplier_id=request.POST.get('supplier'),
            branch_id=request.POST.get('branch'),
            order_date=timezone.now().date(),
            expected_delivery=request.POST.get('expected_delivery') or None,
            notes=request.POST.get('notes', ''),
            created_by=request.user,
            status='draft'
        )
        
        if pr:
            pr.status = 'ordered'
            pr.save()
        
        messages.success(request, f'تم إنشاء أمر الشراء {order_number} بنجاح')
        return redirect('suppliers:purchase_order_detail', pk=po.pk)
    
    suppliers = Supplier.objects.filter(status='active')
    branches = Branch.objects.filter(status='active')
    approved_requests = PurchaseRequest.objects.filter(status='approved')
    
    return render(request, 'suppliers/purchase_order_form.html', {
        'suppliers': suppliers,
        'branches': branches,
        'approved_requests': approved_requests
    })


@login_required
def purchase_order_detail(request, pk):
    """View purchase order details"""
    po = get_object_or_404(PurchaseOrder, pk=pk)
    items = po.items.all().select_related('item')
    available_items = Item.objects.filter(status='active')
    
    return render(request, 'suppliers/purchase_order_detail.html', {
        'po': po,
        'items': items,
        'available_items': available_items
    })


@login_required
def purchase_order_add_item(request, pk):
    """Add item to purchase order"""
    po = get_object_or_404(PurchaseOrder, pk=pk)
    
    if request.method == 'POST':
        item_id = request.POST.get('item')
        quantity = float(request.POST.get('quantity', 0))
        unit_price = float(request.POST.get('unit_price', 0))
        tax_percent = float(request.POST.get('tax_percent', 0))
        
        total_price = quantity * unit_price * (1 + tax_percent / 100)
        
        PurchaseOrderItem.objects.create(
            order=po,
            item_id=item_id,
            quantity=quantity,
            unit_price=unit_price,
            tax_percent=tax_percent,
            total_price=total_price,
            notes=request.POST.get('notes', '')
        )
        
        # Update totals
        totals = po.items.aggregate(
            subtotal=Sum('unit_price'),
            total=Sum('total_price')
        )
        po.subtotal = totals['subtotal'] or 0
        po.total_amount = totals['total'] or 0
        po.save()
        
        messages.success(request, 'تم إضافة الصنف بنجاح')
    
    return redirect('suppliers:purchase_order_detail', pk=pk)


@login_required
def purchase_order_send(request, pk):
    """Send purchase order to supplier"""
    po = get_object_or_404(PurchaseOrder, pk=pk)
    
    if po.status == 'draft' and po.items.exists():
        po.status = 'sent'
        po.save()
        messages.success(request, 'تم إرسال أمر الشراء للمورد')
    else:
        messages.error(request, 'لا يمكن إرسال الأمر - تأكد من إضافة أصناف')
    
    return redirect('suppliers:purchase_order_detail', pk=pk)


@login_required
def purchase_manager_dashboard(request):
    """Purchase manager dashboard"""
    # Statistics
    pending_requests = PurchaseRequest.objects.filter(status='pending').count()
    approved_requests = PurchaseRequest.objects.filter(status='approved').count()
    pending_orders = PurchaseOrder.objects.filter(status__in=['draft', 'sent']).count()
    
    # Recent requests
    recent_requests = PurchaseRequest.objects.all()[:5]
    
    # Recent orders
    recent_orders = PurchaseOrder.objects.all()[:5]
    
    # Low stock items
    from apps.inventory.models import Inventory
    from django.db.models import F
    low_stock = Inventory.objects.filter(quantity__lte=F('min_quantity')).select_related('item', 'branch')[:10]
    
    return render(request, 'suppliers/purchase_manager_dashboard.html', {
        'pending_requests': pending_requests,
        'approved_requests': approved_requests,
        'pending_orders': pending_orders,
        'recent_requests': recent_requests,
        'recent_orders': recent_orders,
        'low_stock': low_stock
    })
