from django.urls import path
from . import template_views

app_name = 'accounts'

urlpatterns = [
    path('login/', template_views.login_view, name='login'),
    path('logout/', template_views.logout_view, name='logout'),
    path('profile/', template_views.profile_view, name='profile'),
    path('change-password/', template_views.change_password_view, name='change_password'),
    path('users/', template_views.user_list_view, name='user_list'),
    path('users/create/', template_views.user_create_view, name='user_create'),
    path('users/<uuid:pk>/edit/', template_views.user_edit_view, name='user_edit'),
    path('roles/', template_views.role_list_view, name='role_list'),
]
