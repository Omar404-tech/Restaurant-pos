from django.urls import path
from . import template_views

app_name = 'suppliers'

urlpatterns = [
    path('', template_views.supplier_list, name='list'),
    path('create/', template_views.supplier_create, name='create'),
    path('<uuid:pk>/', template_views.supplier_detail, name='detail'),
    path('<uuid:pk>/edit/', template_views.supplier_edit, name='edit'),
    path('supplies/', template_views.supply_list, name='supply_list'),
    path('supplies/create/', template_views.supply_create, name='supply_create'),
    path('supplies/<uuid:pk>/', template_views.supply_detail, name='supply_detail'),
    path('payments/', template_views.payment_list, name='payment_list'),
    path('payments/create/', template_views.payment_create, name='payment_create'),
    
    # Purchase Manager URLs
    path('purchase-manager/', template_views.purchase_manager_dashboard, name='purchase_manager_dashboard'),
    path('purchase-requests/', template_views.purchase_request_list, name='purchase_request_list'),
    path('purchase-requests/create/', template_views.purchase_request_create, name='purchase_request_create'),
    path('purchase-requests/<uuid:pk>/', template_views.purchase_request_detail, name='purchase_request_detail'),
    path('purchase-requests/<uuid:pk>/add-item/', template_views.purchase_request_add_item, name='purchase_request_add_item'),
    path('purchase-requests/<uuid:pk>/submit/', template_views.purchase_request_submit, name='purchase_request_submit'),
    path('purchase-requests/<uuid:pk>/approve/', template_views.purchase_request_approve, name='purchase_request_approve'),
    path('purchase-requests/<uuid:pk>/reject/', template_views.purchase_request_reject, name='purchase_request_reject'),
    path('purchase-orders/', template_views.purchase_order_list, name='purchase_order_list'),
    path('purchase-orders/create/', template_views.purchase_order_create, name='purchase_order_create'),
    path('purchase-orders/<uuid:pk>/', template_views.purchase_order_detail, name='purchase_order_detail'),
    path('purchase-orders/<uuid:pk>/add-item/', template_views.purchase_order_add_item, name='purchase_order_add_item'),
    path('purchase-orders/<uuid:pk>/send/', template_views.purchase_order_send, name='purchase_order_send'),
]
