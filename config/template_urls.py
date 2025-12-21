from django.contrib import admin
from django.urls import path, include
from django.conf import settings
from django.conf.urls.static import static

from apps.core.template_views import dashboard

urlpatterns = [
    path('admin/', admin.site.urls),
    
    # Dashboard
    path('', dashboard, name='dashboard'),
    
    # Template URLs
    path('accounts/', include('apps.accounts.template_urls')),
    path('branches/', include('apps.branches.template_urls')),
    path('suppliers/', include('apps.suppliers.template_urls')),
    path('inventory/', include('apps.inventory.template_urls')),
    path('transfers/', include('apps.transfers.template_urls')),
    path('damages/', include('apps.damages.template_urls')),
    path('returns/', include('apps.returns.template_urls')),
    path('menu/', include('apps.menu.template_urls')),
    path('orders/', include('apps.orders.template_urls')),
    path('pos/', include('apps.pos.template_urls')),
    path('reports/', include('apps.reports.template_urls')),
    
    # API URLs
    path('api/', include([
        path('', include(('apps.core.urls', 'core'), namespace='api_core')),
        path('accounts/', include(('apps.accounts.urls', 'accounts'), namespace='api_accounts')),
        path('branches/', include(('apps.branches.urls', 'branches'), namespace='api_branches')),
        path('suppliers/', include(('apps.suppliers.urls', 'suppliers'), namespace='api_suppliers')),
        path('inventory/', include(('apps.inventory.urls', 'inventory'), namespace='api_inventory')),
        path('transfers/', include(('apps.transfers.urls', 'transfers'), namespace='api_transfers')),
        path('damages/', include(('apps.damages.urls', 'damages'), namespace='api_damages')),
        path('returns/', include(('apps.returns.urls', 'returns'), namespace='api_returns')),
        path('menu/', include(('apps.menu.urls', 'menu'), namespace='api_menu')),
        path('orders/', include(('apps.orders.urls', 'orders'), namespace='api_orders')),
        path('pos/', include(('apps.pos.urls', 'pos'), namespace='api_pos')),
        path('reports/', include(('apps.reports.urls', 'reports'), namespace='api_reports')),
    ])),
]

if settings.DEBUG:
    urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)
    urlpatterns += static(settings.STATIC_URL, document_root=settings.STATIC_ROOT)
