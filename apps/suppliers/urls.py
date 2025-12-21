from django.urls import path
from . import views

app_name = 'suppliers'

urlpatterns = [
    # Suppliers
    path('', views.SupplierListCreateView.as_view(), name='supplier-list'),
    path('<uuid:pk>/', views.SupplierDetailView.as_view(), name='supplier-detail'),
    path('<uuid:pk>/balance/', views.SupplierBalanceView.as_view(), name='supplier-balance'),
    
    # Supplies
    path('supplies/', views.SupplyListCreateView.as_view(), name='supply-list'),
    path('supplies/<uuid:pk>/', views.SupplyDetailView.as_view(), name='supply-detail'),
    path('supplies/<uuid:pk>/approve/', views.SupplyApproveView.as_view(), name='supply-approve'),
    
    # Payments
    path('payments/', views.SupplierPaymentListCreateView.as_view(), name='payment-list'),
    path('payments/<uuid:pk>/', views.SupplierPaymentDetailView.as_view(), name='payment-detail'),
    
    # Supplier Items
    path('items/', views.SupplierItemListCreateView.as_view(), name='supplier-item-list'),
    path('items/<uuid:pk>/', views.SupplierItemDetailView.as_view(), name='supplier-item-detail'),
    
    # Purchase Requests
    path('purchase-requests/', views.PurchaseRequestListCreateView.as_view(), name='purchase-request-list'),
    path('purchase-requests/<uuid:pk>/', views.PurchaseRequestDetailView.as_view(), name='purchase-request-detail'),
    path('purchase-requests/<uuid:pk>/approve/', views.PurchaseRequestApproveView.as_view(), name='purchase-request-approve'),
    path('purchase-requests/<uuid:pk>/reject/', views.PurchaseRequestRejectView.as_view(), name='purchase-request-reject'),
    
    # Purchase Orders
    path('purchase-orders/', views.PurchaseOrderListCreateView.as_view(), name='purchase-order-list'),
    path('purchase-orders/<uuid:pk>/', views.PurchaseOrderDetailView.as_view(), name='purchase-order-detail'),
    path('purchase-orders/<uuid:pk>/approve/', views.PurchaseOrderApproveView.as_view(), name='purchase-order-approve'),
]
