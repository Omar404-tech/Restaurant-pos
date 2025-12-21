from rest_framework import generics, status
from rest_framework.views import APIView
from rest_framework.response import Response
from django_filters.rest_framework import DjangoFilterBackend
from rest_framework.filters import SearchFilter, OrderingFilter
from django.utils import timezone
from django.db.models import F
from datetime import timedelta

from .models import (Item, Inventory, InventoryBatch, InventoryTransaction,
                     DailyInventoryCount, DailyInventoryCountItem)
from .serializers import (
    ItemSerializer, ItemListSerializer, ItemDetailSerializer,
    InventorySerializer, InventoryListSerializer, InventoryBatchSerializer,
    InventoryTransactionSerializer, InventoryTransactionListSerializer,
    DailyInventoryCountSerializer, DailyInventoryCountListSerializer,
    DailyInventoryCountItemSerializer, LowStockSerializer, ExpiringItemsSerializer
)


# Item Views
class ItemListCreateView(generics.ListCreateAPIView):
    queryset = Item.objects.all()
    filter_backends = [DjangoFilterBackend, SearchFilter, OrderingFilter]
    search_fields = ['code', 'name', 'name_ar', 'barcode']
    ordering_fields = ['code', 'name', 'purchase_price', 'created_at']
    filterset_fields = ['status', 'category', 'unit', 'is_perishable']
    
    def get_serializer_class(self):
        if self.request.method == 'GET':
            return ItemListSerializer
        return ItemSerializer
    
    def perform_create(self, serializer):
        serializer.save(created_by=self.request.user)


class ItemDetailView(generics.RetrieveUpdateDestroyAPIView):
    queryset = Item.objects.all()
    serializer_class = ItemDetailSerializer


# Inventory Views
class InventoryListView(generics.ListAPIView):
    queryset = Inventory.objects.all()
    serializer_class = InventoryListSerializer
    filter_backends = [DjangoFilterBackend, SearchFilter, OrderingFilter]
    search_fields = ['item__code', 'item__name']
    ordering_fields = ['quantity', 'item__name']
    filterset_fields = ['branch', 'item']


class InventoryDetailView(generics.RetrieveUpdateAPIView):
    queryset = Inventory.objects.all()
    serializer_class = InventorySerializer


class InventoryByBranchView(generics.ListAPIView):
    serializer_class = InventoryListSerializer
    filter_backends = [SearchFilter, OrderingFilter]
    search_fields = ['item__code', 'item__name']
    ordering_fields = ['quantity', 'item__name']
    
    def get_queryset(self):
        branch_id = self.kwargs.get('branch_id')
        return Inventory.objects.filter(branch_id=branch_id)


class LowStockView(APIView):
    def get(self, request):
        branch_id = request.query_params.get('branch')
        queryset = Inventory.objects.filter(quantity__lte=F('min_quantity'))
        if branch_id:
            queryset = queryset.filter(branch_id=branch_id)
        
        data = [{
            'branch_code': inv.branch.code,
            'branch_name': inv.branch.name,
            'item_code': inv.item.code,
            'item_name': inv.item.name,
            'current_quantity': inv.quantity,
            'min_quantity': inv.min_quantity,
            'reorder_level': inv.item.reorder_level
        } for inv in queryset]
        
        return Response(LowStockSerializer(data, many=True).data)


class ExpiringItemsView(APIView):
    def get(self, request):
        days = int(request.query_params.get('days', 30))
        branch_id = request.query_params.get('branch')
        expiry_date = timezone.now().date() + timedelta(days=days)
        
        queryset = InventoryBatch.objects.filter(
            expiry_date__lte=expiry_date,
            remaining_quantity__gt=0
        )
        if branch_id:
            queryset = queryset.filter(inventory__branch_id=branch_id)
        
        data = [{
            'branch_code': batch.inventory.branch.code,
            'branch_name': batch.inventory.branch.name,
            'item_code': batch.inventory.item.code,
            'item_name': batch.inventory.item.name,
            'batch_number': batch.batch_number,
            'quantity': batch.remaining_quantity,
            'expiry_date': batch.expiry_date,
            'days_until_expiry': (batch.expiry_date - timezone.now().date()).days
        } for batch in queryset]
        
        return Response(ExpiringItemsSerializer(data, many=True).data)


class InventoryAdjustView(APIView):
    def post(self, request):
        branch_id = request.data.get('branch_id')
        item_id = request.data.get('item_id')
        quantity = request.data.get('quantity')
        reason = request.data.get('reason', '')
        
        try:
            inventory = Inventory.objects.get(branch_id=branch_id, item_id=item_id)
            old_qty = inventory.quantity
            inventory.quantity = quantity
            inventory.save()
            
            # Create transaction
            InventoryTransaction.objects.create(
                branch_id=branch_id,
                item_id=item_id,
                operation_type='adjustment',
                quantity=quantity - old_qty,
                quantity_before=old_qty,
                quantity_after=quantity,
                notes=reason,
                created_by=request.user
            )
            
            return Response(InventorySerializer(inventory).data)
        except Inventory.DoesNotExist:
            return Response({'error': 'Inventory not found'}, status=404)


# Inventory Batch Views
class InventoryBatchListView(generics.ListAPIView):
    queryset = InventoryBatch.objects.all()
    serializer_class = InventoryBatchSerializer
    filter_backends = [DjangoFilterBackend, SearchFilter, OrderingFilter]
    search_fields = ['batch_number']
    ordering_fields = ['expiry_date', 'received_date']
    filterset_fields = ['inventory', 'inventory__branch', 'inventory__item']


class InventoryBatchDetailView(generics.RetrieveUpdateAPIView):
    queryset = InventoryBatch.objects.all()
    serializer_class = InventoryBatchSerializer


# Inventory Transaction Views
class InventoryTransactionListView(generics.ListAPIView):
    queryset = InventoryTransaction.objects.all()
    serializer_class = InventoryTransactionListSerializer
    filter_backends = [DjangoFilterBackend, OrderingFilter]
    ordering_fields = ['created_at']
    filterset_fields = ['branch', 'item', 'operation_type']


class InventoryTransactionDetailView(generics.RetrieveAPIView):
    queryset = InventoryTransaction.objects.all()
    serializer_class = InventoryTransactionSerializer


# Daily Inventory Count Views
class DailyInventoryCountListCreateView(generics.ListCreateAPIView):
    queryset = DailyInventoryCount.objects.all()
    filter_backends = [DjangoFilterBackend, OrderingFilter]
    ordering_fields = ['count_date']
    filterset_fields = ['branch', 'count_type', 'status', 'count_date']
    
    def get_serializer_class(self):
        if self.request.method == 'GET':
            return DailyInventoryCountListSerializer
        return DailyInventoryCountSerializer
    
    def perform_create(self, serializer):
        serializer.save(counted_by=self.request.user)


class DailyInventoryCountDetailView(generics.RetrieveUpdateAPIView):
    queryset = DailyInventoryCount.objects.all()
    serializer_class = DailyInventoryCountSerializer


class DailyInventoryCountSubmitView(APIView):
    def post(self, request, pk):
        try:
            count = DailyInventoryCount.objects.get(pk=pk)
            count.status = 'submitted'
            count.submitted_at = timezone.now()
            count.save()
            return Response(DailyInventoryCountSerializer(count).data)
        except DailyInventoryCount.DoesNotExist:
            return Response({'error': 'Count not found'}, status=404)


class DailyInventoryCountApproveView(APIView):
    def post(self, request, pk):
        try:
            count = DailyInventoryCount.objects.get(pk=pk)
            count.status = 'approved'
            count.approved_by = request.user
            count.approved_at = timezone.now()
            count.save()
            return Response(DailyInventoryCountSerializer(count).data)
        except DailyInventoryCount.DoesNotExist:
            return Response({'error': 'Count not found'}, status=404)


class DailyInventoryCountItemListCreateView(generics.ListCreateAPIView):
    serializer_class = DailyInventoryCountItemSerializer
    
    def get_queryset(self):
        count_id = self.kwargs.get('count_id')
        return DailyInventoryCountItem.objects.filter(count_id=count_id)
    
    def perform_create(self, serializer):
        count_id = self.kwargs.get('count_id')
        serializer.save(count_id=count_id)
