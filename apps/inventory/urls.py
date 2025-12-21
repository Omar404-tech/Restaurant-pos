from django.urls import path
from . import views

app_name = 'inventory'

urlpatterns = [
    # Items
    path('items/', views.ItemListCreateView.as_view(), name='item-list'),
    path('items/<uuid:pk>/', views.ItemDetailView.as_view(), name='item-detail'),
    
    # Inventory
    path('stock/', views.InventoryListView.as_view(), name='inventory-list'),
    path('stock/<uuid:pk>/', views.InventoryDetailView.as_view(), name='inventory-detail'),
    path('stock/branch/<uuid:branch_id>/', views.InventoryByBranchView.as_view(), name='inventory-by-branch'),
    path('stock/adjust/', views.InventoryAdjustView.as_view(), name='inventory-adjust'),
    
    # Alerts
    path('low-stock/', views.LowStockView.as_view(), name='low-stock'),
    path('expiring/', views.ExpiringItemsView.as_view(), name='expiring-items'),
    
    # Batches
    path('batches/', views.InventoryBatchListView.as_view(), name='batch-list'),
    path('batches/<uuid:pk>/', views.InventoryBatchDetailView.as_view(), name='batch-detail'),
    
    # Transactions
    path('transactions/', views.InventoryTransactionListView.as_view(), name='transaction-list'),
    path('transactions/<uuid:pk>/', views.InventoryTransactionDetailView.as_view(), name='transaction-detail'),
    
    # Daily Counts
    path('daily-counts/', views.DailyInventoryCountListCreateView.as_view(), name='daily-count-list'),
    path('daily-counts/<uuid:pk>/', views.DailyInventoryCountDetailView.as_view(), name='daily-count-detail'),
    path('daily-counts/<uuid:pk>/submit/', views.DailyInventoryCountSubmitView.as_view(), name='daily-count-submit'),
    path('daily-counts/<uuid:pk>/approve/', views.DailyInventoryCountApproveView.as_view(), name='daily-count-approve'),
    path('daily-counts/<uuid:count_id>/items/', views.DailyInventoryCountItemListCreateView.as_view(), name='daily-count-items'),
]
