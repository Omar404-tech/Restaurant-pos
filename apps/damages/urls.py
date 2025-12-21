from django.urls import path
from . import views

app_name = 'damages'

urlpatterns = [
    path('', views.DamageListCreateView.as_view(), name='damage-list'),
    path('pending/', views.PendingDamagesView.as_view(), name='damage-pending'),
    path('<uuid:pk>/', views.DamageDetailView.as_view(), name='damage-detail'),
    path('<uuid:pk>/approve/', views.DamageApproveView.as_view(), name='damage-approve'),
    path('<uuid:pk>/reject/', views.DamageRejectView.as_view(), name='damage-reject'),
]
