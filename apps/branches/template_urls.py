from django.urls import path
from . import template_views

app_name = 'branches'

urlpatterns = [
    path('', template_views.branch_list, name='list'),
    path('create/', template_views.branch_create, name='create'),
    path('<uuid:pk>/', template_views.branch_detail, name='detail'),
    path('<uuid:pk>/edit/', template_views.branch_edit, name='edit'),
]
