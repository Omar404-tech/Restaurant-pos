from django.urls import path
from . import template_views

app_name = 'orders'

urlpatterns = [
    path('', template_views.order_list, name='list'),
    path('<uuid:pk>/', template_views.order_detail, name='detail'),
    path('<uuid:pk>/cancel/', template_views.order_cancel, name='cancel'),
]
