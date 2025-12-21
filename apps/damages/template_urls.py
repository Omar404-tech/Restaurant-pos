from django.urls import path
from . import template_views

app_name = 'damages'

urlpatterns = [
    path('', template_views.damage_list, name='list'),
    path('create/', template_views.damage_create, name='create'),
    path('<uuid:pk>/', template_views.damage_detail, name='detail'),
    path('<uuid:pk>/approve/', template_views.damage_approve, name='approve'),
]
