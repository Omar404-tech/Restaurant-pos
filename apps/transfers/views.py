from rest_framework import generics, status
from rest_framework.views import APIView
from rest_framework.response import Response
from django_filters.rest_framework import DjangoFilterBackend
from rest_framework.filters import SearchFilter, OrderingFilter
from django.utils import timezone

from .models import Transfer, TransferItem
from .serializers import (
    TransferSerializer, TransferListSerializer, TransferCreateSerializer,
    TransferItemSerializer, TransferApproveSerializer, TransferReceiveSerializer
)
from apps.inventory.models import Inventory, InventoryTransaction


# Transfer Views
class TransferListCreateView(generics.ListCreateAPIView):
    queryset = Transfer.objects.all()
    filter_backends = [DjangoFilterBackend, SearchFilter, OrderingFilter]
    search_fields = ['transfer_number']
    ordering_fields = ['created_at', 'requested_at']
    filterset_fields = ['from_branch', 'to_branch', 'status', 'priority']
    
    def get_serializer_class(self):
        if self.request.method == 'GET':
            return TransferListSerializer
        return TransferCreateSerializer
    
    def perform_create(self, serializer):
        import uuid
        transfer_number = f"TRF-{timezone.now().strftime('%Y%m%d')}-{str(uuid.uuid4())[:8].upper()}"
        serializer.save(transfer_number=transfer_number, requested_by=self.request.user)


class TransferDetailView(generics.RetrieveUpdateAPIView):
    queryset = Transfer.objects.all()
    serializer_class = TransferSerializer


class PendingTransfersView(generics.ListAPIView):
    serializer_class = TransferListSerializer
    filter_backends = [DjangoFilterBackend]
    filterset_fields = ['from_branch', 'to_branch']
    
    def get_queryset(self):
        return Transfer.objects.filter(status='pending')


class TransferApproveView(APIView):
    def post(self, request, pk):
        try:
            transfer = Transfer.objects.get(pk=pk)
            if transfer.status != 'pending':
                return Response({'error': 'Transfer is not pending'}, status=400)
            
            serializer = TransferApproveSerializer(data=request.data)
            serializer.is_valid(raise_exception=True)
            
            # Update approved quantities
            for item_data in serializer.validated_data.get('items', []):
                TransferItem.objects.filter(
                    transfer=transfer, item_id=item_data['item_id']
                ).update(approved_quantity=item_data['approved_quantity'])
            
            transfer.status = 'approved'
            transfer.approved_by = request.user
            transfer.approved_at = timezone.now()
            transfer.save()
            
            # Deduct from source branch
            for item in transfer.items.all():
                qty = item.approved_quantity or item.requested_quantity
                item.shipped_quantity = qty
                item.save()
                
                try:
                    inv = Inventory.objects.get(branch=transfer.from_branch, item=item.item)
                    old_qty = inv.quantity
                    inv.quantity -= qty
                    inv.save()
                    
                    InventoryTransaction.objects.create(
                        branch=transfer.from_branch,
                        item=item.item,
                        operation_type='transfer_out',
                        quantity=-qty,
                        quantity_before=old_qty,
                        quantity_after=inv.quantity,
                        reference_type='transfer',
                        reference_id=transfer.id,
                        created_by=request.user
                    )
                except Inventory.DoesNotExist:
                    pass
            
            return Response(TransferSerializer(transfer).data)
        except Transfer.DoesNotExist:
            return Response({'error': 'Transfer not found'}, status=404)


class TransferRejectView(APIView):
    def post(self, request, pk):
        try:
            transfer = Transfer.objects.get(pk=pk)
            if transfer.status != 'pending':
                return Response({'error': 'Transfer is not pending'}, status=400)
            
            transfer.status = 'rejected'
            transfer.rejected_by = request.user
            transfer.rejected_at = timezone.now()
            transfer.rejection_reason = request.data.get('reason', '')
            transfer.save()
            
            return Response(TransferSerializer(transfer).data)
        except Transfer.DoesNotExist:
            return Response({'error': 'Transfer not found'}, status=404)


class TransferReceiveView(APIView):
    def post(self, request, pk):
        try:
            transfer = Transfer.objects.get(pk=pk)
            if transfer.status != 'approved':
                return Response({'error': 'Transfer is not approved'}, status=400)
            
            serializer = TransferReceiveSerializer(data=request.data)
            serializer.is_valid(raise_exception=True)
            
            # Update received quantities and add to destination branch
            for item_data in serializer.validated_data.get('items', []):
                item = TransferItem.objects.get(transfer=transfer, item_id=item_data['item_id'])
                item.received_quantity = item_data['received_quantity']
                item.save()
                
                # Add to destination inventory
                inv, created = Inventory.objects.get_or_create(
                    branch=transfer.to_branch, item=item.item,
                    defaults={'quantity': 0}
                )
                old_qty = inv.quantity
                inv.quantity += item.received_quantity
                inv.last_restock_date = timezone.now()
                inv.save()
                
                InventoryTransaction.objects.create(
                    branch=transfer.to_branch,
                    item=item.item,
                    operation_type='transfer_in',
                    quantity=item.received_quantity,
                    quantity_before=old_qty,
                    quantity_after=inv.quantity,
                    reference_type='transfer',
                    reference_id=transfer.id,
                    created_by=request.user
                )
            
            transfer.status = 'received'
            transfer.received_by = request.user
            transfer.received_at = timezone.now()
            transfer.save()
            
            return Response(TransferSerializer(transfer).data)
        except Transfer.DoesNotExist:
            return Response({'error': 'Transfer not found'}, status=404)


# Transfer Item Views
class TransferItemListView(generics.ListAPIView):
    serializer_class = TransferItemSerializer
    
    def get_queryset(self):
        transfer_id = self.kwargs.get('transfer_id')
        return TransferItem.objects.filter(transfer_id=transfer_id)
