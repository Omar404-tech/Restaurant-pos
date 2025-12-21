from django.urls import path
from . import views

app_name = 'reports'

urlpatterns = [
    path('dashboard/', views.DashboardView.as_view(), name='dashboard'),
    path('inventory/', views.InventoryReportView.as_view(), name='inventory-report'),
    path('sales/', views.SalesReportView.as_view(), name='sales-report'),
    path('suppliers/', views.SupplierReportView.as_view(), name='supplier-report'),
    path('damages/', views.DamageReportView.as_view(), name='damage-report'),
    path('transfers/', views.TransferReportView.as_view(), name='transfer-report'),
    path('top-selling/', views.TopSellingItemsView.as_view(), name='top-selling'),
]
