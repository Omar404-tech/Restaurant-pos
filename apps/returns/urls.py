from django.urls import path
from . import views

app_name = 'returns'

urlpatterns = [
    # Supplier Returns
    path('supplier/', views.SupplierReturnListCreateView.as_view(), name='supplier-return-list'),
    path('supplier/<uuid:pk>/', views.SupplierReturnDetailView.as_view(), name='supplier-return-detail'),
    path('supplier/<uuid:pk>/approve/', views.SupplierReturnApproveView.as_view(), name='supplier-return-approve'),
    path('supplier/<uuid:pk>/reject/', views.SupplierReturnRejectView.as_view(), name='supplier-return-reject'),
    
    # Branch Return Reasons
    path('reasons/', views.BranchReturnReasonListCreateView.as_view(), name='return-reason-list'),
    path('reasons/<uuid:pk>/', views.BranchReturnReasonDetailView.as_view(), name='return-reason-detail'),
    
    # Branch Returns
    path('branch/', views.BranchReturnListCreateView.as_view(), name='branch-return-list'),
    path('branch/pending/', views.PendingBranchReturnsView.as_view(), name='branch-return-pending'),
    path('branch/<uuid:pk>/', views.BranchReturnDetailView.as_view(), name='branch-return-detail'),
    path('branch/<uuid:pk>/approve/', views.BranchReturnApproveView.as_view(), name='branch-return-approve'),
    path('branch/<uuid:pk>/reject/', views.BranchReturnRejectView.as_view(), name='branch-return-reject'),
    path('branch/<uuid:pk>/receive/', views.BranchReturnReceiveView.as_view(), name='branch-return-receive'),
    path('branch/<uuid:return_id>/items/', views.BranchReturnItemListView.as_view(), name='branch-return-items'),
]
