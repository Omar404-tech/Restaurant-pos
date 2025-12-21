from django.urls import path
from . import template_views

app_name = 'returns'

urlpatterns = [
    path('supplier/', template_views.supplier_return_list, name='supplier_list'),
    path('supplier/create/', template_views.supplier_return_create, name='supplier_create'),
    path('branch/', template_views.branch_return_list, name='branch_list'),
    path('branch/create/', template_views.branch_return_create, name='branch_create'),
]
