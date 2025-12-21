from rest_framework import generics, status
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated, AllowAny
from django_filters.rest_framework import DjangoFilterBackend
from rest_framework.filters import SearchFilter, OrderingFilter
from django.utils import timezone

from .models import User, Role, UserSession, AuditLog, Notification
from .serializers import (
    UserSerializer, UserListSerializer, UserCreateSerializer, UserUpdateSerializer,
    RoleSerializer, RoleListSerializer, LoginSerializer, ChangePasswordSerializer,
    UserSessionSerializer, AuditLogSerializer, NotificationSerializer, NotificationListSerializer
)


# Auth Views
class LoginView(APIView):
    permission_classes = [AllowAny]
    
    def post(self, request):
        serializer = LoginSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        user = serializer.validated_data['user']
        
        # Create session
        import secrets
        session = UserSession.objects.create(
            user=user,
            session_token=secrets.token_urlsafe(32),
            ip_address=request.META.get('REMOTE_ADDR'),
            user_agent=request.META.get('HTTP_USER_AGENT', '')[:500]
        )
        
        return Response({
            'token': session.session_token,
            'user': UserSerializer(user).data
        })


class LogoutView(APIView):
    def post(self, request):
        token = request.headers.get('Authorization', '').replace('Bearer ', '')
        UserSession.objects.filter(session_token=token, is_active=True).update(
            is_active=False, logout_at=timezone.now()
        )
        return Response({'message': 'Logged out successfully'})


class ProfileView(APIView):
    def get(self, request):
        return Response(UserSerializer(request.user).data)
    
    def patch(self, request):
        serializer = UserUpdateSerializer(request.user, data=request.data, partial=True)
        serializer.is_valid(raise_exception=True)
        serializer.save()
        return Response(UserSerializer(request.user).data)


class ChangePasswordView(APIView):
    def post(self, request):
        serializer = ChangePasswordSerializer(data=request.data, context={'request': request})
        serializer.is_valid(raise_exception=True)
        request.user.set_password(serializer.validated_data['new_password'])
        request.user.save()
        return Response({'message': 'Password changed successfully'})


# Role Views
class RoleListCreateView(generics.ListCreateAPIView):
    queryset = Role.objects.all()
    filter_backends = [SearchFilter]
    search_fields = ['name', 'name_ar']
    
    def get_serializer_class(self):
        if self.request.method == 'GET':
            return RoleListSerializer
        return RoleSerializer


class RoleDetailView(generics.RetrieveUpdateDestroyAPIView):
    queryset = Role.objects.all()
    serializer_class = RoleSerializer


# User Views
class UserListCreateView(generics.ListCreateAPIView):
    queryset = User.objects.all()
    filter_backends = [DjangoFilterBackend, SearchFilter, OrderingFilter]
    search_fields = ['username', 'full_name', 'employee_code', 'email']
    ordering_fields = ['username', 'full_name', 'created_at']
    filterset_fields = ['status', 'role', 'branch', 'is_active']
    
    def get_serializer_class(self):
        if self.request.method == 'GET':
            return UserListSerializer
        return UserCreateSerializer
    
    def perform_create(self, serializer):
        serializer.save(created_by=self.request.user)


class UserDetailView(generics.RetrieveUpdateDestroyAPIView):
    queryset = User.objects.all()
    
    def get_serializer_class(self):
        if self.request.method in ['PUT', 'PATCH']:
            return UserUpdateSerializer
        return UserSerializer


# Notification Views
class NotificationListView(generics.ListAPIView):
    serializer_class = NotificationListSerializer
    filter_backends = [DjangoFilterBackend, OrderingFilter]
    filterset_fields = ['is_read', 'type', 'priority']
    ordering_fields = ['created_at']
    
    def get_queryset(self):
        return Notification.objects.filter(user=self.request.user)


class NotificationDetailView(generics.RetrieveAPIView):
    serializer_class = NotificationSerializer
    
    def get_queryset(self):
        return Notification.objects.filter(user=self.request.user)


class NotificationMarkReadView(APIView):
    def post(self, request, pk):
        try:
            notification = Notification.objects.get(pk=pk, user=request.user)
            notification.is_read = True
            notification.read_at = timezone.now()
            notification.save()
            return Response({'message': 'Notification marked as read'})
        except Notification.DoesNotExist:
            return Response({'error': 'Notification not found'}, status=404)


class NotificationMarkAllReadView(APIView):
    def post(self, request):
        Notification.objects.filter(user=request.user, is_read=False).update(
            is_read=True, read_at=timezone.now()
        )
        return Response({'message': 'All notifications marked as read'})


# Audit Log Views
class AuditLogListView(generics.ListAPIView):
    queryset = AuditLog.objects.all()
    serializer_class = AuditLogSerializer
    filter_backends = [DjangoFilterBackend, OrderingFilter]
    filterset_fields = ['user', 'action', 'table_name']
    ordering_fields = ['created_at']


# Session Views
class UserSessionListView(generics.ListAPIView):
    serializer_class = UserSessionSerializer
    
    def get_queryset(self):
        return UserSession.objects.filter(user=self.request.user, is_active=True)
