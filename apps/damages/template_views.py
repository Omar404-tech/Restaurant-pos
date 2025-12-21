from django.shortcuts import render, redirect, get_object_or_404
from django.contrib.auth.decorators import login_required
from django.contrib import messages
from django.core.paginator import Paginator
from django.utils import timezone
import uuid

from .models import Damage
from apps.inventory.models import Item
from apps.core.models import DamageReason


@login_required
def damage_list(request):
    damages = Damage.objects.all().select_related('branch', 'item', 'reason')
    status = request.GET.get('status')
    if status:
        damages = damages.filter(status=status)
    
    paginator = Paginator(damages, 20)
    page = request.GET.get('page')
    damages = paginator.get_page(page)
    return render(request, 'damages/list.html', {'damages': damages})


@login_required
def damage_create(request):
    if request.method == 'POST':
        damage_number = f"DMG-{timezone.now().strftime('%Y%m%d')}-{str(uuid.uuid4())[:8].upper()}"
        Damage.objects.create(
            damage_number=damage_number,
            branch=request.user.branch,
            item_id=request.POST.get('item'),
            quantity=request.POST.get('quantity'),
            unit_cost=request.POST.get('unit_cost', 0),
            reason_id=request.POST.get('reason'),
            description=request.POST.get('description', ''),
            registered_by=request.user
        )
        messages.success(request, 'تم تسجيل التالف بنجاح')
        return redirect('damages:list')
    
    items = Item.objects.filter(status='active')
    reasons = DamageReason.objects.filter(is_active=True)
    return render(request, 'damages/form.html', {'items': items, 'reasons': reasons})


@login_required
def damage_detail(request, pk):
    damage = get_object_or_404(Damage, pk=pk)
    return render(request, 'damages/detail.html', {'damage': damage})


@login_required
def damage_approve(request, pk):
    damage = get_object_or_404(Damage, pk=pk)
    if damage.status == 'pending':
        damage.status = 'approved'
        damage.approved_by = request.user
        damage.approved_at = timezone.now()
        damage.save()
        messages.success(request, 'تم الموافقة على التالف')
    return redirect('damages:detail', pk=pk)
