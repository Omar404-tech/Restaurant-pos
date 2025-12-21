from django.shortcuts import render, redirect, get_object_or_404
from django.contrib.auth.decorators import login_required
from django.contrib import messages
from django.core.paginator import Paginator
from django.utils import timezone

from .models import Order


@login_required
def order_list(request):
    orders = Order.objects.all().select_related('branch', 'cashier')
    status = request.GET.get('status')
    order_type = request.GET.get('order_type')
    
    if status:
        orders = orders.filter(status=status)
    if order_type:
        orders = orders.filter(order_type=order_type)
    
    paginator = Paginator(orders, 20)
    page = request.GET.get('page')
    orders = paginator.get_page(page)
    return render(request, 'orders/list.html', {'orders': orders})


@login_required
def order_detail(request, pk):
    order = get_object_or_404(Order, pk=pk)
    return render(request, 'orders/detail.html', {'order': order})


@login_required
def order_cancel(request, pk):
    order = get_object_or_404(Order, pk=pk)
    if order.status not in ['delivered', 'cancelled']:
        order.status = 'cancelled'
        order.cancelled_at = timezone.now()
        order.cancelled_by = request.user
        order.cancellation_reason = request.POST.get('reason', '')
        order.save()
        messages.success(request, 'تم إلغاء الطلب')
    return redirect('orders:detail', pk=pk)
