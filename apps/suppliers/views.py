from rest_framework import generics, status
from rest_framework.views import APIView
from rest_framework.response import Response
from django_filters.rest_framework import DjangoFilterBackend
from rest_framework.filters import SearchFilter, OrderingFilter
from django.utils import timezone
from django.db.models import Sum

from .models import (Supplier, Supply, SupplyItem, SupplierPayment, SupplierItem,
                     PurchaseRequest, PurchaseRequestItem, PurchaseOrder, PurchaseOrderItem)
from .serializers import (
    SupplierSerializer, SupplierListSerializer, SupplierDetailSerializer,
    SupplySerializer, SupplyListSerializer, SupplyCreateSerializer, SupplyItemSerializer,
    SupplierPaymentSerializer, SupplierPaymentListSerializer,
    SupplierItemSerializer, PurchaseRequestSerializer, PurchaseRequestListSerializer,
    PurchaseRequestItemSerializer, PurchaseOrderSerializer, PurchaseOrderListSerializer
)


# Supplier Views
class SupplierListCreateView(generics.ListCreateAPIView):
    queryset = Supplier.objects.all()
    filter_backends = [DjangoFilterBackend, SearchFilter, OrderingFilter]
    search_fields = ['code', 'name', 'name_ar', 'phone', 'contact_person']
    ordering_fields = ['code', 'name', 'current_balance', 'created_at']
    filterset_fields = ['status', 'payment_method']
    
    def get_serializer_class(self):
        if self.request.method == 'GET':
            return SupplierListSerializer
        return SupplierSerializer
    
    def perform_create(self, serializer):
        serializer.save(created_by=self.request.user)


class SupplierDetailView(generics.RetrieveUpdateDestroyAPIView):
    queryset = Supplier.objects.all()
    serializer_class = SupplierDetailSerializer


class SupplierBalanceView(APIView):
    def get(self, request, pk):
        try:
            supplier = Supplier.objects.get(pk=pk)
            supplies_total = supplier.supplies.aggregate(total=Sum('total_amount'))['total'] or 0
            payments_total = supplier.payments.aggregate(total=Sum('amount'))['total'] or 0
            return Response({
                'supplier': supplier.name,
                'total_supplies': supplies_total,
                'total_payments': payments_total,
                'current_balance': supplier.current_balance
            })
        except Supplier.DoesNotExist:
            return Response({'error': 'Supplier not found'}, status=404)


# Supply Views
class SupplyListCreateView(generics.ListCreateAPIView):
    queryset = Supply.objects.all()
    filter_backends = [DjangoFilterBackend, SearchFilter, OrderingFilter]
    search_fields = ['supply_number', 'invoice_number']
    ordering_fields = ['created_at', 'total_amount']
    filterset_fields = ['supplier', 'branch', 'payment_status', 'payment_method']
    
    def get_serializer_class(self):
        if self.request.method == 'GET':
            return SupplyListSerializer
        return SupplyCreateSerializer
    
    def perform_create(self, serializer):
        import uuid
        supply_number = f"SUP-{timezone.now().strftime('%Y%m%d')}-{str(uuid.uuid4())[:8].upper()}"
        serializer.save(supply_number=supply_number, received_by=self.request.user, received_at=timezone.now())


class SupplyDetailView(generics.RetrieveUpdateAPIView):
    queryset = Supply.objects.all()
    serializer_class = SupplySerializer


class SupplyApproveView(APIView):
    def post(self, request, pk):
        try:
            supply = Supply.objects.get(pk=pk)
            supply.approved_by = request.user
            supply.approved_at = timezone.now()
            supply.save()
            return Response(SupplySerializer(supply).data)
        except Supply.DoesNotExist:
            return Response({'error': 'Supply not found'}, status=404)


# Supplier Payment Views
class SupplierPaymentListCreateView(generics.ListCreateAPIView):
    queryset = SupplierPayment.objects.all()
    filter_backends = [DjangoFilterBackend, SearchFilter, OrderingFilter]
    search_fields = ['payment_number', 'reference_number']
    ordering_fields = ['payment_date', 'amount', 'created_at']
    filterset_fields = ['supplier', 'payment_method']
    
    def get_serializer_class(self):
        if self.request.method == 'GET':
            return SupplierPaymentListSerializer
        return SupplierPaymentSerializer
    
    def perform_create(self, serializer):
        import uuid
        payment_number = f"PAY-{timezone.now().strftime('%Y%m%d')}-{str(uuid.uuid4())[:8].upper()}"
        payment = serializer.save(payment_number=payment_number, created_by=self.request.user)
        
        # Update supplier balance
        supplier = payment.supplier
        supplier.current_balance -= payment.amount
        supplier.save()


class SupplierPaymentDetailView(generics.RetrieveAPIView):
    queryset = SupplierPayment.objects.all()
    serializer_class = SupplierPaymentSerializer


# Supplier Item Views
class SupplierItemListCreateView(generics.ListCreateAPIView):
    queryset = SupplierItem.objects.all()
    serializer_class = SupplierItemSerializer
    filter_backends = [DjangoFilterBackend]
    filterset_fields = ['supplier', 'item', 'is_preferred']


class SupplierItemDetailView(generics.RetrieveUpdateDestroyAPIView):
    queryset = SupplierItem.objects.all()
    serializer_class = SupplierItemSerializer


# Purchase Request Views
class PurchaseRequestListCreateView(generics.ListCreateAPIView):
    queryset = PurchaseRequest.objects.all()
    filter_backends = [DjangoFilterBackend, SearchFilter, OrderingFilter]
    search_fields = ['request_number']
    ordering_fields = ['request_date', 'priority', 'created_at']
    filterset_fields = ['branch', 'status', 'priority']
    
    def get_serializer_class(self):
        if self.request.method == 'GET':
            return PurchaseRequestListSerializer
        return PurchaseRequestSerializer
    
    def perform_create(self, serializer):
        import uuid
        request_number = f"PR-{timezone.now().strftime('%Y%m%d')}-{str(uuid.uuid4())[:8].upper()}"
        serializer.save(request_number=request_number, requested_by=self.request.user)


class PurchaseRequestDetailView(generics.RetrieveUpdateAPIView):
    queryset = PurchaseRequest.objects.all()
    serializer_class = PurchaseRequestSerializer


class PurchaseRequestApproveView(APIView):
    def post(self, request, pk):
        try:
            pr = PurchaseRequest.objects.get(pk=pk)
            pr.status = 'approved'
            pr.approved_by = request.user
            pr.approved_at = timezone.now()
            pr.save()
            return Response(PurchaseRequestSerializer(pr).data)
        except PurchaseRequest.DoesNotExist:
            return Response({'error': 'Purchase request not found'}, status=404)


class PurchaseRequestRejectView(APIView):
    def post(self, request, pk):
        try:
            pr = PurchaseRequest.objects.get(pk=pk)
            pr.status = 'rejected'
            pr.rejected_by = request.user
            pr.rejected_at = timezone.now()
            pr.rejection_reason = request.data.get('reason', '')
            pr.save()
            return Response(PurchaseRequestSerializer(pr).data)
        except PurchaseRequest.DoesNotExist:
            return Response({'error': 'Purchase request not found'}, status=404)


# Purchase Order Views
class PurchaseOrderListCreateView(generics.ListCreateAPIView):
    queryset = PurchaseOrder.objects.all()
    filter_backends = [DjangoFilterBackend, SearchFilter, OrderingFilter]
    search_fields = ['order_number']
    ordering_fields = ['order_date', 'total_amount', 'created_at']
    filterset_fields = ['supplier', 'branch', 'status']
    
    def get_serializer_class(self):
        if self.request.method == 'GET':
            return PurchaseOrderListSerializer
        return PurchaseOrderSerializer
    
    def perform_create(self, serializer):
        import uuid
        order_number = f"PO-{timezone.now().strftime('%Y%m%d')}-{str(uuid.uuid4())[:8].upper()}"
        serializer.save(order_number=order_number, created_by=self.request.user)


class PurchaseOrderDetailView(generics.RetrieveUpdateAPIView):
    queryset = PurchaseOrder.objects.all()
    serializer_class = PurchaseOrderSerializer


class PurchaseOrderApproveView(APIView):
    def post(self, request, pk):
        try:
            po = PurchaseOrder.objects.get(pk=pk)
            po.status = 'confirmed'
            po.approved_by = request.user
            po.approved_at = timezone.now()
            po.save()
            return Response(PurchaseOrderSerializer(po).data)
        except PurchaseOrder.DoesNotExist:
            return Response({'error': 'Purchase order not found'}, status=404)
