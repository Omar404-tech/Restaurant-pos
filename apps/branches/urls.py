from django.urls import path
from . import views

app_name = 'branches'

urlpatterns = [
    # Branches
    path('', views.BranchListCreateView.as_view(), name='branch-list'),
    path('main-warehouse/', views.MainWarehouseView.as_view(), name='main-warehouse'),
    path('<uuid:pk>/', views.BranchDetailView.as_view(), name='branch-detail'),
    
    # Branch Settings
    path('<uuid:branch_id>/settings/', views.BranchSettingListView.as_view(), name='branch-setting-list'),
    path('<uuid:branch_id>/settings/update/', views.BranchSettingCreateUpdateView.as_view(), name='branch-setting-update'),
    
    # Alert Settings
    path('<uuid:branch_id>/alerts/', views.AlertSettingListCreateView.as_view(), name='alert-setting-list'),
    path('alerts/', views.AlertSettingListCreateView.as_view(), name='alert-setting-all'),
    path('alerts/<uuid:pk>/', views.AlertSettingDetailView.as_view(), name='alert-setting-detail'),
]
