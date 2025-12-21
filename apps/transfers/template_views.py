from django.shortcuts import render, redirect, get_object_or_404
from django.contrib.auth.decorators import login_required
from django.contrib import messages
from django.core.paginator import Paginator
from django.utils import timezone
import uuid

from .models import Transfer, TransferItem
from apps.branches.models import Branch
from apps.inventory.models import Item


@login_required
def transfer_list(request):
    transfers = Transfer.objects.all().select_related('from_branch', 'to_branch', 'requested_by')
    status = request.GET.get('status')
    if status:
        transfers = transfers.filter(status=status)
    
    paginator = Paginator(transfers, 20)
    page = request.GET.get('page')
    transfers = paginator.get_page(page)
    return render(request, 'transfers/list.html', {'transfers': transfers})


@login_required
def transfer_create(request):
    if request.method == 'POST':
        transfer_number = f"TRF-{timezone.now().strftime('%Y%m%d')}-{str(uuid.uuid4())[:8].upper()}"
        transfer = Transfer.objects.create(
            transfer_number=transfer_number,
            from_branch_id=request.POST.get('from_branch'),
            to_branch_id=request.POST.get('to_branch'),
            notes=request.POST.get('notes', ''),
            requested_by=request.user
        )
        messages.success(request, f'تم إنشاء طلب التحويل {transfer_number}')
        return redirect('transfers:detail', pk=transfer.pk)
    
    branches = Branch.objects.filter(status='active')
    return render(request, 'transfers/form.html', {'branches': branches})


@login_required
def transfer_detail(request, pk):
    transfer = get_object_or_404(Transfer, pk=pk)
    items = Item.objects.filter(status='active')
    return render(request, 'transfers/detail.html', {'transfer': transfer, 'items': items})


@login_required
def transfer_approve(request, pk):
    transfer = get_object_or_404(Transfer, pk=pk)
    if transfer.status == 'pending':
        transfer.status = 'approved'
        transfer.approved_by = request.user
        transfer.approved_at = timezone.now()
        transfer.save()
        messages.success(request, 'تم الموافقة على التحويل')
    return redirect('transfers:detail', pk=pk)


@login_required
def transfer_receive(request, pk):
    transfer = get_object_or_404(Transfer, pk=pk)
    if transfer.status == 'approved':
        transfer.status = 'received'
        transfer.received_by = request.user
        transfer.received_at = timezone.now()
        transfer.save()
        messages.success(request, 'تم استلام التحويل')
    return redirect('transfers:detail', pk=pk)
