from django.urls import path
from . import template_views

app_name = 'transfers'

urlpatterns = [
    path('', template_views.transfer_list, name='list'),
    path('create/', template_views.transfer_create, name='create'),
    path('<uuid:pk>/', template_views.transfer_detail, name='detail'),
    path('<uuid:pk>/approve/', template_views.transfer_approve, name='approve'),
    path('<uuid:pk>/receive/', template_views.transfer_receive, name='receive'),
]
