from rest_framework import generics, status
from rest_framework.views import APIView
from rest_framework.response import Response
from django_filters.rest_framework import DjangoFilterBackend
from rest_framework.filters import SearchFilter, OrderingFilter

from .models import MenuCategory, MenuItem, MenuItemIngredient
from .serializers import (
    MenuCategorySerializer, MenuCategoryListSerializer, MenuCategoryTreeSerializer,
    MenuItemSerializer, MenuItemListSerializer, MenuItemDetailSerializer,
    MenuItemCreateSerializer, MenuItemIngredientSerializer
)


# Menu Category Views
class MenuCategoryListCreateView(generics.ListCreateAPIView):
    queryset = MenuCategory.objects.all()
    filter_backends = [DjangoFilterBackend, SearchFilter, OrderingFilter]
    search_fields = ['code', 'name', 'name_ar']
    ordering_fields = ['sort_order', 'name', 'created_at']
    filterset_fields = ['is_active', 'parent']
    
    def get_serializer_class(self):
        if self.request.method == 'GET':
            return MenuCategoryListSerializer
        return MenuCategorySerializer


class MenuCategoryDetailView(generics.RetrieveUpdateDestroyAPIView):
    queryset = MenuCategory.objects.all()
    serializer_class = MenuCategorySerializer


class MenuCategoryTreeView(APIView):
    def get(self, request):
        categories = MenuCategory.objects.filter(parent__isnull=True, is_active=True).order_by('sort_order')
        serializer = MenuCategoryTreeSerializer(categories, many=True)
        return Response(serializer.data)


# Menu Item Views
class MenuItemListCreateView(generics.ListCreateAPIView):
    queryset = MenuItem.objects.all()
    filter_backends = [DjangoFilterBackend, SearchFilter, OrderingFilter]
    search_fields = ['code', 'name', 'name_ar']
    ordering_fields = ['sort_order', 'name', 'price', 'created_at']
    filterset_fields = ['category', 'is_active', 'is_available']
    
    def get_serializer_class(self):
        if self.request.method == 'GET':
            return MenuItemListSerializer
        return MenuItemCreateSerializer


class MenuItemDetailView(generics.RetrieveUpdateDestroyAPIView):
    queryset = MenuItem.objects.all()
    
    def get_serializer_class(self):
        if self.request.method == 'GET':
            return MenuItemDetailSerializer
        return MenuItemSerializer


class MenuItemAvailabilityView(APIView):
    def post(self, request, pk):
        try:
            item = MenuItem.objects.get(pk=pk)
            item.is_available = request.data.get('is_available', not item.is_available)
            item.save()
            return Response(MenuItemSerializer(item).data)
        except MenuItem.DoesNotExist:
            return Response({'error': 'Menu item not found'}, status=404)


class AvailableMenuItemsView(generics.ListAPIView):
    serializer_class = MenuItemListSerializer
    filter_backends = [DjangoFilterBackend, SearchFilter, OrderingFilter]
    search_fields = ['code', 'name', 'name_ar']
    ordering_fields = ['sort_order', 'name']
    filterset_fields = ['category']
    
    def get_queryset(self):
        return MenuItem.objects.filter(is_active=True, is_available=True)


# Menu Item Ingredient Views
class MenuItemIngredientListCreateView(generics.ListCreateAPIView):
    serializer_class = MenuItemIngredientSerializer
    
    def get_queryset(self):
        menu_item_id = self.kwargs.get('menu_item_id')
        return MenuItemIngredient.objects.filter(menu_item_id=menu_item_id)
    
    def perform_create(self, serializer):
        menu_item_id = self.kwargs.get('menu_item_id')
        serializer.save(menu_item_id=menu_item_id)


class MenuItemIngredientDetailView(generics.RetrieveUpdateDestroyAPIView):
    queryset = MenuItemIngredient.objects.all()
    serializer_class = MenuItemIngredientSerializer


class MenuItemCostCalculateView(APIView):
    def get(self, request, pk):
        try:
            item = MenuItem.objects.get(pk=pk)
            total_cost = 0
            ingredients = []
            
            for ing in item.ingredients.all():
                cost = ing.quantity * (ing.item.purchase_price or 0)
                total_cost += cost
                ingredients.append({
                    'item': ing.item.name,
                    'quantity': ing.quantity,
                    'unit_price': ing.item.purchase_price,
                    'cost': cost
                })
            
            return Response({
                'menu_item': item.name,
                'selling_price': item.price,
                'calculated_cost': total_cost,
                'profit': item.price - total_cost,
                'profit_margin': ((item.price - total_cost) / item.price * 100) if item.price > 0 else 0,
                'ingredients': ingredients
            })
        except MenuItem.DoesNotExist:
            return Response({'error': 'Menu item not found'}, status=404)
