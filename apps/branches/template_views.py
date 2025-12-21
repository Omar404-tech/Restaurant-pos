from django.shortcuts import render, redirect, get_object_or_404
from django.contrib.auth.decorators import login_required
from django.contrib import messages
from .models import Branch


@login_required
def branch_list(request):
    branches = Branch.objects.all()
    return render(request, 'branches/list.html', {'branches': branches})


@login_required
def branch_create(request):
    if request.method == 'POST':
        Branch.objects.create(
            code=request.POST.get('code'),
            name=request.POST.get('name'),
            name_ar=request.POST.get('name_ar', ''),
            address=request.POST.get('address', ''),
            phone=request.POST.get('phone', ''),
            branch_type=request.POST.get('branch_type', 'branch'),
        )
        messages.success(request, 'تم إنشاء الفرع بنجاح')
        return redirect('branches:list')
    return render(request, 'branches/form.html')


@login_required
def branch_detail(request, pk):
    branch = get_object_or_404(Branch, pk=pk)
    return render(request, 'branches/detail.html', {'branch': branch})


@login_required
def branch_edit(request, pk):
    branch = get_object_or_404(Branch, pk=pk)
    if request.method == 'POST':
        branch.name = request.POST.get('name')
        branch.name_ar = request.POST.get('name_ar', '')
        branch.address = request.POST.get('address', '')
        branch.phone = request.POST.get('phone', '')
        branch.status = request.POST.get('status', 'active')
        branch.save()
        messages.success(request, 'تم تحديث الفرع بنجاح')
        return redirect('branches:list')
    return render(request, 'branches/form.html', {'branch': branch, 'edit': True})
