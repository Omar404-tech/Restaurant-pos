from rest_framework import generics, status
from rest_framework.views import APIView
from rest_framework.response import Response
from django_filters.rest_framework import DjangoFilterBackend
from rest_framework.filters import SearchFilter, OrderingFilter

from .models import Branch, BranchSetting, AlertSetting
from .serializers import (
    BranchSerializer, BranchListSerializer, BranchDetailSerializer,
    BranchSettingSerializer, AlertSettingSerializer
)


# Branch Views
class BranchListCreateView(generics.ListCreateAPIView):
    queryset = Branch.objects.all()
    filter_backends = [DjangoFilterBackend, SearchFilter, OrderingFilter]
    search_fields = ['code', 'name', 'name_ar']
    ordering_fields = ['code', 'name', 'created_at']
    filterset_fields = ['status', 'branch_type', 'is_main_warehouse']
    
    def get_serializer_class(self):
        if self.request.method == 'GET':
            return BranchListSerializer
        return BranchSerializer


class BranchDetailView(generics.RetrieveUpdateDestroyAPIView):
    queryset = Branch.objects.all()
    serializer_class = BranchDetailSerializer


class MainWarehouseView(APIView):
    def get(self, request):
        try:
            branch = Branch.objects.get(is_main_warehouse=True)
            return Response(BranchDetailSerializer(branch).data)
        except Branch.DoesNotExist:
            return Response({'error': 'Main warehouse not found'}, status=404)


# Branch Setting Views
class BranchSettingListView(generics.ListAPIView):
    serializer_class = BranchSettingSerializer
    
    def get_queryset(self):
        branch_id = self.kwargs.get('branch_id')
        return BranchSetting.objects.filter(branch_id=branch_id)


class BranchSettingCreateUpdateView(APIView):
    def post(self, request, branch_id):
        key = request.data.get('key')
        value = request.data.get('value')
        
        setting, created = BranchSetting.objects.update_or_create(
            branch_id=branch_id, key=key,
            defaults={'value': value, 'updated_by': request.user}
        )
        return Response(BranchSettingSerializer(setting).data)


# Alert Setting Views
class AlertSettingListCreateView(generics.ListCreateAPIView):
    serializer_class = AlertSettingSerializer
    filter_backends = [DjangoFilterBackend]
    filterset_fields = ['branch', 'alert_type', 'is_enabled']
    
    def get_queryset(self):
        branch_id = self.kwargs.get('branch_id')
        if branch_id:
            return AlertSetting.objects.filter(branch_id=branch_id)
        return AlertSetting.objects.all()


class AlertSettingDetailView(generics.RetrieveUpdateDestroyAPIView):
    queryset = AlertSetting.objects.all()
    serializer_class = AlertSettingSerializer
