from rest_framework import generics, status
from rest_framework.views import APIView
from rest_framework.response import Response
from django_filters.rest_framework import DjangoFilterBackend
from rest_framework.filters import SearchFilter, OrderingFilter
from django.utils import timezone

from .models import SupplierReturn, BranchReturn, BranchReturnItem, BranchReturnReason
from .serializers import (
    SupplierReturnSerializer, SupplierReturnListSerializer, SupplierReturnCreateSerializer,
    BranchReturnSerializer, BranchReturnListSerializer, BranchReturnCreateSerializer,
    BranchReturnItemSerializer, BranchReturnReasonSerializer,
    BranchReturnApproveSerializer, BranchReturnReceiveSerializer
)
from apps.inventory.models import Inventory, InventoryTransaction


# Supplier Return Views
class SupplierReturnListCreateView(generics.ListCreateAPIView):
    queryset = SupplierReturn.objects.all()
    filter_backends = [DjangoFilterBackend, SearchFilter, OrderingFilter]
    search_fields = ['return_number']
    ordering_fields = ['created_at', 'total_amount']
    filterset_fields = ['supplier', 'item', 'status']
    
    def get_serializer_class(self):
        if self.request.method == 'GET':
            return SupplierReturnListSerializer
        return SupplierReturnCreateSerializer
    
    def perform_create(self, serializer):
        import uuid
        return_number = f"SRT-{timezone.now().strftime('%Y%m%d')}-{str(uuid.uuid4())[:8].upper()}"
        serializer.save(return_number=return_number, registered_by=self.request.user)


class SupplierReturnDetailView(generics.RetrieveUpdateAPIView):
    queryset = SupplierReturn.objects.all()
    serializer_class = SupplierReturnSerializer


class SupplierReturnApproveView(APIView):
    def post(self, request, pk):
        try:
            ret = SupplierReturn.objects.get(pk=pk)
            if ret.status != 'pending':
                return Response({'error': 'Return is not pending'}, status=400)
            
            ret.status = 'approved'
            ret.approved_by = request.user
            ret.approved_at = timezone.now()
            ret.save()
            
            # Update supplier balance
            ret.supplier.current_balance -= ret.total_amount
            ret.supplier.save()
            
            return Response(SupplierReturnSerializer(ret).data)
        except SupplierReturn.DoesNotExist:
            return Response({'error': 'Return not found'}, status=404)


class SupplierReturnRejectView(APIView):
    def post(self, request, pk):
        try:
            ret = SupplierReturn.objects.get(pk=pk)
            if ret.status != 'pending':
                return Response({'error': 'Return is not pending'}, status=400)
            
            ret.status = 'rejected'
            ret.rejected_by = request.user
            ret.rejected_at = timezone.now()
            ret.rejection_reason = request.data.get('reason', '')
            ret.save()
            
            return Response(SupplierReturnSerializer(ret).data)
        except SupplierReturn.DoesNotExist:
            return Response({'error': 'Return not found'}, status=404)


# Branch Return Reason Views
class BranchReturnReasonListCreateView(generics.ListCreateAPIView):
    queryset = BranchReturnReason.objects.all()
    serializer_class = BranchReturnReasonSerializer
    filter_backends = [DjangoFilterBackend]
    filterset_fields = ['is_active']


class BranchReturnReasonDetailView(generics.RetrieveUpdateDestroyAPIView):
    queryset = BranchReturnReason.objects.all()
    serializer_class = BranchReturnReasonSerializer


# Branch Return Views
class BranchReturnListCreateView(generics.ListCreateAPIView):
    queryset = BranchReturn.objects.all()
    filter_backends = [DjangoFilterBackend, SearchFilter, OrderingFilter]
    search_fields = ['return_number']
    ordering_fields = ['return_date', 'total_value', 'created_at']
    filterset_fields = ['from_branch', 'to_branch', 'status']
    
    def get_serializer_class(self):
        if self.request.method == 'GET':
            return BranchReturnListSerializer
        return BranchReturnCreateSerializer
    
    def perform_create(self, serializer):
        import uuid
        return_number = f"BRT-{timezone.now().strftime('%Y%m%d')}-{str(uuid.uuid4())[:8].upper()}"
        serializer.save(return_number=return_number, requested_by=self.request.user)


class BranchReturnDetailView(generics.RetrieveUpdateAPIView):
    queryset = BranchReturn.objects.all()
    serializer_class = BranchReturnSerializer


class PendingBranchReturnsView(generics.ListAPIView):
    serializer_class = BranchReturnListSerializer
    filter_backends = [DjangoFilterBackend]
    filterset_fields = ['from_branch', 'to_branch']
    
    def get_queryset(self):
        return BranchReturn.objects.filter(status='pending')


class BranchReturnApproveView(APIView):
    def post(self, request, pk):
        try:
            ret = BranchReturn.objects.get(pk=pk)
            if ret.status != 'pending':
                return Response({'error': 'Return is not pending'}, status=400)
            
            serializer = BranchReturnApproveSerializer(data=request.data)
            serializer.is_valid(raise_exception=True)
            
            # Update approved quantities
            for item_data in serializer.validated_data.get('items', []):
                BranchReturnItem.objects.filter(
                    return_order=ret, item_id=item_data['item_id']
                ).update(approved_quantity=item_data['approved_quantity'])
            
            ret.status = 'approved'
            ret.approved_by = request.user
            ret.approved_at = timezone.now()
            ret.save()
            
            # Deduct from source branch
            for item in ret.items.all():
                qty = item.approved_quantity or item.requested_quantity
                item.shipped_quantity = qty
                item.save()
                
                try:
                    inv = Inventory.objects.get(branch=ret.from_branch, item=item.item)
                    old_qty = inv.quantity
                    inv.quantity -= qty
                    inv.save()
                    
                    InventoryTransaction.objects.create(
                        branch=ret.from_branch,
                        item=item.item,
                        operation_type='return',
                        quantity=-qty,
                        quantity_before=old_qty,
                        quantity_after=inv.quantity,
                        reference_type='branch_return',
                        reference_id=ret.id,
                        created_by=request.user
                    )
                except Inventory.DoesNotExist:
                    pass
            
            ret.shipped_at = timezone.now()
            ret.status = 'in_transit'
            ret.save()
            
            return Response(BranchReturnSerializer(ret).data)
        except BranchReturn.DoesNotExist:
            return Response({'error': 'Return not found'}, status=404)


class BranchReturnRejectView(APIView):
    def post(self, request, pk):
        try:
            ret = BranchReturn.objects.get(pk=pk)
            if ret.status != 'pending':
                return Response({'error': 'Return is not pending'}, status=400)
            
            ret.status = 'rejected'
            ret.rejected_by = request.user
            ret.rejected_at = timezone.now()
            ret.rejection_reason = request.data.get('reason', '')
            ret.save()
            
            return Response(BranchReturnSerializer(ret).data)
        except BranchReturn.DoesNotExist:
            return Response({'error': 'Return not found'}, status=404)


class BranchReturnReceiveView(APIView):
    def post(self, request, pk):
        try:
            ret = BranchReturn.objects.get(pk=pk)
            if ret.status not in ['approved', 'in_transit']:
                return Response({'error': 'Return is not ready for receiving'}, status=400)
            
            serializer = BranchReturnReceiveSerializer(data=request.data)
            serializer.is_valid(raise_exception=True)
            
            # Update received quantities and add to destination branch
            for item_data in serializer.validated_data.get('items', []):
                item = BranchReturnItem.objects.get(return_order=ret, item_id=item_data['item_id'])
                item.received_quantity = item_data['received_quantity']
                item.save()
                
                # Add to destination inventory
                inv, created = Inventory.objects.get_or_create(
                    branch=ret.to_branch, item=item.item,
                    defaults={'quantity': 0}
                )
                old_qty = inv.quantity
                inv.quantity += item.received_quantity
                inv.last_restock_date = timezone.now()
                inv.save()
                
                InventoryTransaction.objects.create(
                    branch=ret.to_branch,
                    item=item.item,
                    operation_type='return',
                    quantity=item.received_quantity,
                    quantity_before=old_qty,
                    quantity_after=inv.quantity,
                    reference_type='branch_return',
                    reference_id=ret.id,
                    created_by=request.user
                )
            
            ret.status = 'received'
            ret.received_by = request.user
            ret.received_at = timezone.now()
            ret.save()
            
            return Response(BranchReturnSerializer(ret).data)
        except BranchReturn.DoesNotExist:
            return Response({'error': 'Return not found'}, status=404)


# Branch Return Item Views
class BranchReturnItemListView(generics.ListAPIView):
    serializer_class = BranchReturnItemSerializer
    
    def get_queryset(self):
        return_id = self.kwargs.get('return_id')
        return BranchReturnItem.objects.filter(return_order_id=return_id)
