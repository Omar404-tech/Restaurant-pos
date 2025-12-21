from django.urls import path
from . import views

app_name = 'pos'

urlpatterns = [
    # POS Menu
    path('menu/', views.POSMenuView.as_view(), name='pos-menu'),
    
    # POS Orders
    path('order/', views.POSOrderCreateView.as_view(), name='pos-order-create'),
    path('order/<uuid:pk>/pay/', views.POSPaymentView.as_view(), name='pos-payment'),
    path('order/<uuid:pk>/receipt/', views.POSReceiptView.as_view(), name='pos-receipt'),
    
    # Kitchen Display
    path('kitchen/', views.KitchenDisplayView.as_view(), name='kitchen-display'),
    path('kitchen/<uuid:pk>/start/', views.KitchenStartPreparingView.as_view(), name='kitchen-start'),
    path('kitchen/<uuid:pk>/ready/', views.KitchenReadyView.as_view(), name='kitchen-ready'),
    
    # Daily Summary
    path('summary/', views.POSDailySummaryView.as_view(), name='pos-summary'),
]
