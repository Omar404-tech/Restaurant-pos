from django.urls import path
from . import views

app_name = 'core'

urlpatterns = [
    # Units
    path('units/', views.UnitListCreateView.as_view(), name='unit-list'),
    path('units/<uuid:pk>/', views.UnitDetailView.as_view(), name='unit-detail'),
    
    # Categories
    path('categories/', views.CategoryListCreateView.as_view(), name='category-list'),
    path('categories/tree/', views.CategoryTreeView.as_view(), name='category-tree'),
    path('categories/<uuid:pk>/', views.CategoryDetailView.as_view(), name='category-detail'),
    
    # Damage Reasons
    path('damage-reasons/', views.DamageReasonListCreateView.as_view(), name='damage-reason-list'),
    path('damage-reasons/<uuid:pk>/', views.DamageReasonDetailView.as_view(), name='damage-reason-detail'),
    
    # System Settings
    path('settings/', views.SystemSettingListView.as_view(), name='system-setting-list'),
    path('settings/<uuid:pk>/', views.SystemSettingDetailView.as_view(), name='system-setting-detail'),
]
