from django.urls import path
from . import template_views

app_name = 'inventory'

urlpatterns = [
    path('items/', template_views.item_list, name='item_list'),
    path('items/create/', template_views.item_create, name='item_create'),
    path('items/<uuid:pk>/', template_views.item_detail, name='item_detail'),
    path('items/<uuid:pk>/edit/', template_views.item_edit, name='item_edit'),
    path('stock/', template_views.stock_list, name='stock_list'),
    path('low-stock/', template_views.low_stock, name='low_stock'),
    path('daily-count/', template_views.daily_count_list, name='daily_count_list'),
    path('daily-count/create/', template_views.daily_count_create, name='daily_count_create'),
    
    # Chef Daily Consumption URLs
    path('consumption/', template_views.consumption_dashboard, name='consumption_dashboard'),
    path('consumption/record/', template_views.consumption_record, name='consumption_record'),
    path('consumption/count/<uuid:pk>/', template_views.consumption_count_detail, name='consumption_count_detail'),
    path('consumption/count/<uuid:pk>/add-item/', template_views.consumption_add_item, name='consumption_add_item'),
    path('consumption/count/<uuid:pk>/submit/', template_views.consumption_submit, name='consumption_submit'),
    path('consumption/count/<uuid:pk>/approve/', template_views.consumption_approve, name='consumption_approve'),
    path('consumption/report/', template_views.consumption_report, name='consumption_report'),
]
