from django.urls import path
from . import template_views

app_name = 'reports'

urlpatterns = [
    path('', template_views.reports_index, name='index'),
    path('sales/', template_views.sales_report, name='sales'),
    path('inventory/', template_views.inventory_report, name='inventory'),
    path('suppliers/', template_views.suppliers_report, name='suppliers'),
]
