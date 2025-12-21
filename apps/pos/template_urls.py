from django.urls import path
from . import template_views

app_name = 'pos'

urlpatterns = [
    path('cashier/', template_views.cashier_view, name='cashier'),
    path('kitchen/', template_views.kitchen_view, name='kitchen'),
]
