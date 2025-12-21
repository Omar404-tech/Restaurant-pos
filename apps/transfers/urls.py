from django.urls import path
from . import views

app_name = 'transfers'

urlpatterns = [
    # Transfers
    path('', views.TransferListCreateView.as_view(), name='transfer-list'),
    path('pending/', views.PendingTransfersView.as_view(), name='transfer-pending'),
    path('<uuid:pk>/', views.TransferDetailView.as_view(), name='transfer-detail'),
    path('<uuid:pk>/approve/', views.TransferApproveView.as_view(), name='transfer-approve'),
    path('<uuid:pk>/reject/', views.TransferRejectView.as_view(), name='transfer-reject'),
    path('<uuid:pk>/receive/', views.TransferReceiveView.as_view(), name='transfer-receive'),
    path('<uuid:transfer_id>/items/', views.TransferItemListView.as_view(), name='transfer-items'),
]
