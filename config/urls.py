from django.contrib import admin
from django.urls import path, include
from django.conf import settings
from django.conf.urls.static import static

urlpatterns = [
    path('admin/', admin.site.urls),
    path('api/', include([
        path('', include('apps.core.urls')),
        path('accounts/', include('apps.accounts.urls')),
        path('branches/', include('apps.branches.urls')),
        path('suppliers/', include('apps.suppliers.urls')),
        path('inventory/', include('apps.inventory.urls')),
        path('transfers/', include('apps.transfers.urls')),
        path('damages/', include('apps.damages.urls')),
        path('returns/', include('apps.returns.urls')),
        path('menu/', include('apps.menu.urls')),
        path('orders/', include('apps.orders.urls')),
        path('pos/', include('apps.pos.urls')),
        path('reports/', include('apps.reports.urls')),
    ])),
]

if settings.DEBUG:
    urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)
    urlpatterns += static(settings.STATIC_URL, document_root=settings.STATIC_ROOT)
