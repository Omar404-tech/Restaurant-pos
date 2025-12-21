from django.shortcuts import render, redirect
from django.contrib.auth.decorators import login_required
from django.contrib import messages
from django.core.paginator import Paginator

from .models import SupplierReturn, BranchReturn


@login_required
def supplier_return_list(request):
    returns = SupplierReturn.objects.all().select_related('supplier', 'item')
    paginator = Paginator(returns, 20)
    page = request.GET.get('page')
    returns = paginator.get_page(page)
    return render(request, 'returns/supplier_list.html', {'returns': returns})


@login_required
def supplier_return_create(request):
    if request.method == 'POST':
        messages.success(request, 'تم إنشاء المرتجع بنجاح')
        return redirect('returns:supplier_list')
    return render(request, 'returns/supplier_form.html')


@login_required
def branch_return_list(request):
    returns = BranchReturn.objects.all().select_related('from_branch', 'to_branch')
    paginator = Paginator(returns, 20)
    page = request.GET.get('page')
    returns = paginator.get_page(page)
    return render(request, 'returns/branch_list.html', {'returns': returns})


@login_required
def branch_return_create(request):
    if request.method == 'POST':
        messages.success(request, 'تم إنشاء المرتجع بنجاح')
        return redirect('returns:branch_list')
    return render(request, 'returns/branch_form.html')
