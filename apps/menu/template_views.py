from django.shortcuts import render, redirect, get_object_or_404
from django.contrib.auth.decorators import login_required
from django.contrib import messages
from django.core.paginator import Paginator

from .models import MenuCategory, MenuItem


@login_required
def menu_item_list(request):
    items = MenuItem.objects.all().select_related('category')
    category = request.GET.get('category')
    if category:
        items = items.filter(category_id=category)
    
    paginator = Paginator(items, 20)
    page = request.GET.get('page')
    items = paginator.get_page(page)
    categories = MenuCategory.objects.filter(is_active=True)
    return render(request, 'menu/item_list.html', {'items': items, 'categories': categories})


@login_required
def menu_item_create(request):
    if request.method == 'POST':
        MenuItem.objects.create(
            code=request.POST.get('code'),
            name=request.POST.get('name'),
            category_id=request.POST.get('category') or None,
            price=request.POST.get('price', 0),
            cost=request.POST.get('cost', 0),
        )
        messages.success(request, 'تم إنشاء صنف المنيو بنجاح')
        return redirect('menu:item_list')
    
    categories = MenuCategory.objects.filter(is_active=True)
    return render(request, 'menu/item_form.html', {'categories': categories})


@login_required
def menu_item_detail(request, pk):
    item = get_object_or_404(MenuItem, pk=pk)
    return render(request, 'menu/item_detail.html', {'item': item})


@login_required
def menu_item_edit(request, pk):
    item = get_object_or_404(MenuItem, pk=pk)
    if request.method == 'POST':
        item.name = request.POST.get('name')
        item.category_id = request.POST.get('category') or None
        item.price = request.POST.get('price', 0)
        item.cost = request.POST.get('cost', 0)
        item.is_available = request.POST.get('is_available') == 'on'
        item.save()
        messages.success(request, 'تم تحديث صنف المنيو بنجاح')
        return redirect('menu:item_list')
    
    categories = MenuCategory.objects.filter(is_active=True)
    return render(request, 'menu/item_form.html', {'item': item, 'categories': categories, 'edit': True})


@login_required
def category_list(request):
    categories = MenuCategory.objects.all()
    return render(request, 'menu/category_list.html', {'categories': categories})
