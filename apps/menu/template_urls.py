from django.urls import path
from . import template_views

app_name = 'menu'

urlpatterns = [
    path('', template_views.menu_item_list, name='item_list'),
    path('create/', template_views.menu_item_create, name='item_create'),
    path('<uuid:pk>/', template_views.menu_item_detail, name='item_detail'),
    path('<uuid:pk>/edit/', template_views.menu_item_edit, name='item_edit'),
    path('categories/', template_views.category_list, name='category_list'),
]
