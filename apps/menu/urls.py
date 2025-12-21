from django.urls import path
from . import views

app_name = 'menu'

urlpatterns = [
    # Categories
    path('categories/', views.MenuCategoryListCreateView.as_view(), name='category-list'),
    path('categories/tree/', views.MenuCategoryTreeView.as_view(), name='category-tree'),
    path('categories/<uuid:pk>/', views.MenuCategoryDetailView.as_view(), name='category-detail'),
    
    # Items
    path('items/', views.MenuItemListCreateView.as_view(), name='item-list'),
    path('items/available/', views.AvailableMenuItemsView.as_view(), name='item-available'),
    path('items/<uuid:pk>/', views.MenuItemDetailView.as_view(), name='item-detail'),
    path('items/<uuid:pk>/availability/', views.MenuItemAvailabilityView.as_view(), name='item-availability'),
    path('items/<uuid:pk>/cost/', views.MenuItemCostCalculateView.as_view(), name='item-cost'),
    
    # Ingredients
    path('items/<uuid:menu_item_id>/ingredients/', views.MenuItemIngredientListCreateView.as_view(), name='ingredient-list'),
    path('ingredients/<uuid:pk>/', views.MenuItemIngredientDetailView.as_view(), name='ingredient-detail'),
]
