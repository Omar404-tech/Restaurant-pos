from rest_framework import generics, status
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated
from django_filters.rest_framework import DjangoFilterBackend
from rest_framework.filters import SearchFilter, OrderingFilter

from .models import Unit, Category, SystemSetting, DamageReason
from .serializers import (
    UnitSerializer, UnitListSerializer,
    CategorySerializer, CategoryListSerializer, CategoryTreeSerializer,
    SystemSettingSerializer, DamageReasonSerializer, DamageReasonListSerializer
)


# Unit Views
class UnitListCreateView(generics.ListCreateAPIView):
    queryset = Unit.objects.all()
    filter_backends = [DjangoFilterBackend, SearchFilter, OrderingFilter]
    search_fields = ['code', 'name', 'name_ar']
    ordering_fields = ['code', 'name', 'created_at']
    filterset_fields = ['is_active']
    
    def get_serializer_class(self):
        if self.request.method == 'GET':
            return UnitListSerializer
        return UnitSerializer


class UnitDetailView(generics.RetrieveUpdateDestroyAPIView):
    queryset = Unit.objects.all()
    serializer_class = UnitSerializer


# Category Views
class CategoryListCreateView(generics.ListCreateAPIView):
    queryset = Category.objects.all()
    filter_backends = [DjangoFilterBackend, SearchFilter, OrderingFilter]
    search_fields = ['code', 'name', 'name_ar']
    ordering_fields = ['code', 'name', 'created_at']
    filterset_fields = ['is_active', 'parent']
    
    def get_serializer_class(self):
        if self.request.method == 'GET':
            return CategoryListSerializer
        return CategorySerializer


class CategoryDetailView(generics.RetrieveUpdateDestroyAPIView):
    queryset = Category.objects.all()
    serializer_class = CategorySerializer


class CategoryTreeView(APIView):
    def get(self, request):
        categories = Category.objects.filter(parent__isnull=True, is_active=True)
        serializer = CategoryTreeSerializer(categories, many=True)
        return Response(serializer.data)


# Damage Reason Views
class DamageReasonListCreateView(generics.ListCreateAPIView):
    queryset = DamageReason.objects.all()
    filter_backends = [DjangoFilterBackend, SearchFilter]
    search_fields = ['code', 'name', 'name_ar']
    filterset_fields = ['is_active']
    
    def get_serializer_class(self):
        if self.request.method == 'GET':
            return DamageReasonListSerializer
        return DamageReasonSerializer


class DamageReasonDetailView(generics.RetrieveUpdateDestroyAPIView):
    queryset = DamageReason.objects.all()
    serializer_class = DamageReasonSerializer


# System Setting Views
class SystemSettingListView(generics.ListAPIView):
    queryset = SystemSetting.objects.all()
    serializer_class = SystemSettingSerializer


class SystemSettingDetailView(generics.RetrieveUpdateAPIView):
    queryset = SystemSetting.objects.all()
    serializer_class = SystemSettingSerializer
    
    def perform_update(self, serializer):
        serializer.save(updated_by=self.request.user)
