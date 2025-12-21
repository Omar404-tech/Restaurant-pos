from rest_framework import generics, status
from rest_framework.views import APIView
from rest_framework.response import Response
from django_filters.rest_framework import DjangoFilterBackend
from rest_framework.filters import SearchFilter, OrderingFilter
from django.utils import timezone

from .models import Damage
from .serializers import (
    DamageSerializer, DamageListSerializer, DamageCreateSerializer,
    DamageApproveSerializer, DamageRejectSerializer
)
from apps.inventory.models import Inventory, InventoryTransaction


# Damage Views
class DamageListCreateView(generics.ListCreateAPIView):
    queryset = Damage.objects.all()
    filter_backends = [DjangoFilterBackend, SearchFilter, OrderingFilter]
    search_fields = ['damage_number']
    ordering_fields = ['created_at', 'total_cost']
    filterset_fields = ['branch', 'item', 'reason', 'status']
    
    def get_serializer_class(self):
        if self.request.method == 'GET':
            return DamageListSerializer
        return DamageCreateSerializer
    
    def perform_create(self, serializer):
        import uuid
        damage_number = f"DMG-{timezone.now().strftime('%Y%m%d')}-{str(uuid.uuid4())[:8].upper()}"
        serializer.save(damage_number=damage_number, registered_by=self.request.user)


class DamageDetailView(generics.RetrieveUpdateAPIView):
    queryset = Damage.objects.all()
    serializer_class = DamageSerializer


class PendingDamagesView(generics.ListAPIView):
    serializer_class = DamageListSerializer
    filter_backends = [DjangoFilterBackend]
    filterset_fields = ['branch']
    
    def get_queryset(self):
        return Damage.objects.filter(status='pending')


class DamageApproveView(APIView):
    def post(self, request, pk):
        try:
            damage = Damage.objects.get(pk=pk)
            if damage.status != 'pending':
                return Response({'error': 'Damage is not pending'}, status=400)
            
            damage.status = 'approved'
            damage.approved_by = request.user
            damage.approved_at = timezone.now()
            damage.save()
            
            # Deduct from inventory
            try:
                inv = Inventory.objects.get(branch=damage.branch, item=damage.item)
                old_qty = inv.quantity
                inv.quantity -= damage.quantity
                inv.save()
                
                InventoryTransaction.objects.create(
                    branch=damage.branch,
                    item=damage.item,
                    batch=damage.batch,
                    operation_type='damage',
                    quantity=-damage.quantity,
                    quantity_before=old_qty,
                    quantity_after=inv.quantity,
                    unit_cost=damage.unit_cost,
                    reference_type='damage',
                    reference_id=damage.id,
                    notes=f"Damage: {damage.reason.name}",
                    created_by=request.user
                )
            except Inventory.DoesNotExist:
                pass
            
            return Response(DamageSerializer(damage).data)
        except Damage.DoesNotExist:
            return Response({'error': 'Damage not found'}, status=404)


class DamageRejectView(APIView):
    def post(self, request, pk):
        try:
            damage = Damage.objects.get(pk=pk)
            if damage.status != 'pending':
                return Response({'error': 'Damage is not pending'}, status=400)
            
            serializer = DamageRejectSerializer(data=request.data)
            serializer.is_valid(raise_exception=True)
            
            damage.status = 'rejected'
            damage.rejected_by = request.user
            damage.rejected_at = timezone.now()
            damage.rejection_reason = serializer.validated_data['rejection_reason']
            damage.save()
            
            return Response(DamageSerializer(damage).data)
        except Damage.DoesNotExist:
            return Response({'error': 'Damage not found'}, status=404)
