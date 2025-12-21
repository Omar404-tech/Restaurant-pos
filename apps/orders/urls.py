from django.urls import path
from . import views

app_name = 'orders'

urlpatterns = [
    # Orders
    path('', views.OrderListCreateView.as_view(), name='order-list'),
    path('today/', views.TodayOrdersView.as_view(), name='order-today'),
    path('kitchen/', views.KitchenOrdersView.as_view(), name='order-kitchen'),
    path('<uuid:pk>/', views.OrderDetailView.as_view(), name='order-detail'),
    path('<uuid:pk>/status/', views.OrderStatusUpdateView.as_view(), name='order-status'),
    path('<uuid:pk>/cancel/', views.OrderCancelView.as_view(), name='order-cancel'),
    path('<uuid:pk>/pay/', views.OrderPayView.as_view(), name='order-pay'),
    
    # Order Items
    path('<uuid:order_id>/items/', views.OrderItemListView.as_view(), name='order-items'),
    path('items/<uuid:pk>/', views.OrderItemDetailView.as_view(), name='order-item-detail'),
    path('items/<uuid:pk>/status/', views.OrderItemStatusUpdateView.as_view(), name='order-item-status'),
    
    # Daily Summary
    path('summary/daily/', views.DailySalesView.as_view(), name='daily-summary'),
]
