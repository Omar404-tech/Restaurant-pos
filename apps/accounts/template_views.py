from django.shortcuts import render, redirect, get_object_or_404
from django.contrib.auth import authenticate, login, logout
from django.contrib.auth.decorators import login_required
from django.contrib import messages
from django.core.paginator import Paginator
from django.db.models import Count

from .models import User, Role, Notification


def login_view(request):
    if request.user.is_authenticated:
        return redirect('dashboard')
    
    if request.method == 'POST':
        username = request.POST.get('username')
        password = request.POST.get('password')
        user = authenticate(request, username=username, password=password)
        
        if user is not None:
            if user.status == 'active':
                login(request, user)
                messages.success(request, f'مرحباً {user.full_name}')
                return redirect('dashboard')
            else:
                messages.error(request, 'حسابك غير نشط. تواصل مع المسؤول.')
        else:
            messages.error(request, 'اسم المستخدم أو كلمة المرور غير صحيحة')
    
    return render(request, 'accounts/login.html')


@login_required
def logout_view(request):
    logout(request)
    messages.info(request, 'تم تسجيل الخروج بنجاح')
    return redirect('accounts:login')


@login_required
def profile_view(request):
    if request.method == 'POST':
        user = request.user
        user.full_name = request.POST.get('full_name', user.full_name)
        user.email = request.POST.get('email', user.email)
        user.phone = request.POST.get('phone', user.phone)
        user.save()
        messages.success(request, 'تم تحديث الملف الشخصي بنجاح')
        return redirect('accounts:profile')
    
    return render(request, 'accounts/profile.html')


@login_required
def change_password_view(request):
    if request.method == 'POST':
        old_password = request.POST.get('old_password')
        new_password = request.POST.get('new_password')
        confirm_password = request.POST.get('confirm_password')
        
        if not request.user.check_password(old_password):
            messages.error(request, 'كلمة المرور الحالية غير صحيحة')
        elif new_password != confirm_password:
            messages.error(request, 'كلمة المرور الجديدة غير متطابقة')
        elif len(new_password) < 8:
            messages.error(request, 'كلمة المرور يجب أن تكون 8 أحرف على الأقل')
        else:
            request.user.set_password(new_password)
            request.user.save()
            messages.success(request, 'تم تغيير كلمة المرور بنجاح. يرجى تسجيل الدخول مرة أخرى')
            return redirect('accounts:login')
    
    return render(request, 'accounts/change_password.html')


@login_required
def user_list_view(request):
    users = User.objects.all().select_related('role', 'branch')
    
    # Filters
    role = request.GET.get('role')
    branch = request.GET.get('branch')
    status = request.GET.get('status')
    search = request.GET.get('search')
    
    if role:
        users = users.filter(role_id=role)
    if branch:
        users = users.filter(branch_id=branch)
    if status:
        users = users.filter(status=status)
    if search:
        users = users.filter(full_name__icontains=search) | users.filter(username__icontains=search)
    
    paginator = Paginator(users, 20)
    page = request.GET.get('page')
    users = paginator.get_page(page)
    
    roles = Role.objects.all()
    from apps.branches.models import Branch
    branches = Branch.objects.all()
    
    context = {
        'users': users,
        'roles': roles,
        'branches': branches,
    }
    return render(request, 'accounts/user_list.html', context)


@login_required
def user_create_view(request):
    if request.method == 'POST':
        try:
            user = User.objects.create(
                username=request.POST.get('username'),
                full_name=request.POST.get('full_name'),
                email=request.POST.get('email', ''),
                phone=request.POST.get('phone', ''),
                role_id=request.POST.get('role') or None,
                branch_id=request.POST.get('branch') or None,
                created_by=request.user
            )
            user.set_password(request.POST.get('password'))
            user.save()
            messages.success(request, 'تم إنشاء المستخدم بنجاح')
            return redirect('accounts:user_list')
        except Exception as e:
            messages.error(request, f'حدث خطأ: {str(e)}')
    
    roles = Role.objects.all()
    from apps.branches.models import Branch
    branches = Branch.objects.all()
    
    return render(request, 'accounts/user_form.html', {'roles': roles, 'branches': branches})


@login_required
def user_edit_view(request, pk):
    user = get_object_or_404(User, pk=pk)
    
    if request.method == 'POST':
        user.full_name = request.POST.get('full_name')
        user.email = request.POST.get('email', '')
        user.phone = request.POST.get('phone', '')
        user.role_id = request.POST.get('role') or None
        user.branch_id = request.POST.get('branch') or None
        user.status = request.POST.get('status', 'active')
        user.save()
        messages.success(request, 'تم تحديث المستخدم بنجاح')
        return redirect('accounts:user_list')
    
    roles = Role.objects.all()
    from apps.branches.models import Branch
    branches = Branch.objects.all()
    
    return render(request, 'accounts/user_form.html', {
        'user_obj': user,
        'roles': roles,
        'branches': branches,
        'edit': True
    })


@login_required
def role_list_view(request):
    roles = Role.objects.annotate(users_count=Count('users'))
    return render(request, 'accounts/role_list.html', {'roles': roles})
