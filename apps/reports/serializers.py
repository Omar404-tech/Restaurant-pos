from rest_framework import serializers


class DateRangeSerializer(serializers.Serializer):
    """Serializer for date range filters"""
    start_date = serializers.DateField()
    end_date = serializers.DateField()
    branch_id = serializers.UUIDField(required=False, allow_null=True)


class InventoryReportSerializer(serializers.Serializer):
    """Serializer for inventory report"""
    branch_code = serializers.CharField()
    branch_name = serializers.CharField()
    item_code = serializers.CharField()
    item_name = serializers.CharField()
    category_name = serializers.CharField()
    unit_name = serializers.CharField()
    current_quantity = serializers.DecimalField(max_digits=12, decimal_places=3)
    min_quantity = serializers.DecimalField(max_digits=12, decimal_places=3)
    purchase_price = serializers.DecimalField(max_digits=12, decimal_places=2)
    total_value = serializers.DecimalField(max_digits=12, decimal_places=2)
    is_low_stock = serializers.BooleanField()


class SalesReportSerializer(serializers.Serializer):
    """Serializer for sales report"""
    date = serializers.DateField()
    branch_code = serializers.CharField()
    branch_name = serializers.CharField()
    total_orders = serializers.IntegerField()
    total_items = serializers.IntegerField()
    subtotal = serializers.DecimalField(max_digits=12, decimal_places=2)
    tax_amount = serializers.DecimalField(max_digits=12, decimal_places=2)
    discount_amount = serializers.DecimalField(max_digits=12, decimal_places=2)
    total_amount = serializers.DecimalField(max_digits=12, decimal_places=2)
    cash_amount = serializers.DecimalField(max_digits=12, decimal_places=2)
    visa_amount = serializers.DecimalField(max_digits=12, decimal_places=2)
    cancelled_orders = serializers.IntegerField()


class SupplierReportSerializer(serializers.Serializer):
    """Serializer for supplier report"""
    supplier_code = serializers.CharField()
    supplier_name = serializers.CharField()
    total_supplies = serializers.IntegerField()
    total_supply_amount = serializers.DecimalField(max_digits=12, decimal_places=2)
    total_payments = serializers.IntegerField()
    total_payment_amount = serializers.DecimalField(max_digits=12, decimal_places=2)
    current_balance = serializers.DecimalField(max_digits=12, decimal_places=2)


class DamageReportSerializer(serializers.Serializer):
    """Serializer for damage report"""
    branch_code = serializers.CharField()
    branch_name = serializers.CharField()
    item_code = serializers.CharField()
    item_name = serializers.CharField()
    reason_name = serializers.CharField()
    total_quantity = serializers.DecimalField(max_digits=12, decimal_places=3)
    total_cost = serializers.DecimalField(max_digits=12, decimal_places=2)
    count = serializers.IntegerField()


class TransferReportSerializer(serializers.Serializer):
    """Serializer for transfer report"""
    from_branch_code = serializers.CharField()
    from_branch_name = serializers.CharField()
    to_branch_code = serializers.CharField()
    to_branch_name = serializers.CharField()
    total_transfers = serializers.IntegerField()
    total_items = serializers.IntegerField()
    pending_count = serializers.IntegerField()
    approved_count = serializers.IntegerField()
    received_count = serializers.IntegerField()


class ConsumptionReportSerializer(serializers.Serializer):
    """Serializer for consumption report"""
    date = serializers.DateField()
    branch_code = serializers.CharField()
    branch_name = serializers.CharField()
    item_code = serializers.CharField()
    item_name = serializers.CharField()
    opening_quantity = serializers.DecimalField(max_digits=12, decimal_places=3)
    incoming_quantity = serializers.DecimalField(max_digits=12, decimal_places=3)
    closing_quantity = serializers.DecimalField(max_digits=12, decimal_places=3)
    consumption = serializers.DecimalField(max_digits=12, decimal_places=3)
    variance = serializers.DecimalField(max_digits=12, decimal_places=3)


class DashboardSummarySerializer(serializers.Serializer):
    """Serializer for dashboard summary"""
    total_sales_today = serializers.DecimalField(max_digits=12, decimal_places=2)
    total_orders_today = serializers.IntegerField()
    pending_transfers = serializers.IntegerField()
    pending_damages = serializers.IntegerField()
    low_stock_items = serializers.IntegerField()
    expiring_items = serializers.IntegerField()
    pending_purchase_requests = serializers.IntegerField()
    unread_notifications = serializers.IntegerField()


class TopSellingItemSerializer(serializers.Serializer):
    """Serializer for top selling items"""
    item_code = serializers.CharField()
    item_name = serializers.CharField()
    category_name = serializers.CharField()
    total_quantity = serializers.IntegerField()
    total_amount = serializers.DecimalField(max_digits=12, decimal_places=2)


class ProfitLossSerializer(serializers.Serializer):
    """Serializer for profit/loss report"""
    date = serializers.DateField()
    branch_code = serializers.CharField()
    branch_name = serializers.CharField()
    total_sales = serializers.DecimalField(max_digits=12, decimal_places=2)
    total_cost = serializers.DecimalField(max_digits=12, decimal_places=2)
    gross_profit = serializers.DecimalField(max_digits=12, decimal_places=2)
    damage_cost = serializers.DecimalField(max_digits=12, decimal_places=2)
    net_profit = serializers.DecimalField(max_digits=12, decimal_places=2)
    profit_margin = serializers.DecimalField(max_digits=5, decimal_places=2)
