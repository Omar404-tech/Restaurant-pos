from rest_framework import serializers
from .models import MenuCategory, MenuItem, MenuItemIngredient


class MenuCategorySerializer(serializers.ModelSerializer):
    """Serializer for MenuCategory model"""
    parent_name = serializers.CharField(source='parent.name', read_only=True)
    items_count = serializers.SerializerMethodField()
    children_count = serializers.SerializerMethodField()
    
    class Meta:
        model = MenuCategory
        fields = ['id', 'code', 'name', 'name_ar', 'description', 'parent',
                  'parent_name', 'image', 'sort_order', 'is_active', 'items_count',
                  'children_count', 'created_at', 'updated_at']
        read_only_fields = ['id', 'created_at', 'updated_at']
    
    def get_items_count(self, obj):
        return obj.items.count()
    
    def get_children_count(self, obj):
        return obj.children.count()


class MenuCategoryListSerializer(serializers.ModelSerializer):
    """Lightweight serializer for MenuCategory lists"""
    items_count = serializers.SerializerMethodField()
    
    class Meta:
        model = MenuCategory
        fields = ['id', 'code', 'name', 'name_ar', 'is_active', 'items_count', 'sort_order']
    
    def get_items_count(self, obj):
        return obj.items.count()


class MenuCategoryTreeSerializer(serializers.ModelSerializer):
    """Serializer for MenuCategory with nested children"""
    children = serializers.SerializerMethodField()
    items_count = serializers.SerializerMethodField()
    
    class Meta:
        model = MenuCategory
        fields = ['id', 'code', 'name', 'name_ar', 'is_active', 'items_count', 
                  'sort_order', 'children']
    
    def get_children(self, obj):
        children = obj.children.filter(is_active=True).order_by('sort_order')
        return MenuCategoryTreeSerializer(children, many=True).data
    
    def get_items_count(self, obj):
        return obj.items.count()


class MenuItemIngredientSerializer(serializers.ModelSerializer):
    """Serializer for MenuItemIngredient model"""
    item_name = serializers.CharField(source='item.name', read_only=True)
    item_code = serializers.CharField(source='item.code', read_only=True)
    unit_name = serializers.CharField(source='unit.name', read_only=True)
    item_unit_name = serializers.CharField(source='item.unit.name', read_only=True)
    
    class Meta:
        model = MenuItemIngredient
        fields = ['id', 'menu_item', 'item', 'item_code', 'item_name', 'quantity',
                  'unit', 'unit_name', 'item_unit_name', 'notes']
        read_only_fields = ['id']


class MenuItemSerializer(serializers.ModelSerializer):
    """Serializer for MenuItem model"""
    category_name = serializers.CharField(source='category.name', read_only=True)
    ingredients = MenuItemIngredientSerializer(many=True, read_only=True)
    ingredients_count = serializers.SerializerMethodField()
    profit_margin = serializers.SerializerMethodField()
    
    class Meta:
        model = MenuItem
        fields = ['id', 'code', 'name', 'name_ar', 'description', 'category',
                  'category_name', 'price', 'cost', 'tax_percent', 'preparation_time',
                  'image', 'is_available', 'is_active', 'sort_order', 'ingredients',
                  'ingredients_count', 'profit_margin', 'created_at', 'updated_at']
        read_only_fields = ['id', 'created_at', 'updated_at']
    
    def get_ingredients_count(self, obj):
        return obj.ingredients.count()
    
    def get_profit_margin(self, obj):
        if obj.cost and obj.cost > 0:
            return round(((obj.price - obj.cost) / obj.price) * 100, 2)
        return 100


class MenuItemListSerializer(serializers.ModelSerializer):
    """Lightweight serializer for MenuItem lists"""
    category_name = serializers.CharField(source='category.name', read_only=True)
    
    class Meta:
        model = MenuItem
        fields = ['id', 'code', 'name', 'name_ar', 'category_name', 'price',
                  'is_available', 'is_active', 'sort_order']


class MenuItemDetailSerializer(serializers.ModelSerializer):
    """Detailed serializer for MenuItem"""
    category_name = serializers.CharField(source='category.name', read_only=True)
    ingredients = MenuItemIngredientSerializer(many=True, read_only=True)
    profit_margin = serializers.SerializerMethodField()
    calculated_cost = serializers.SerializerMethodField()
    
    class Meta:
        model = MenuItem
        fields = ['id', 'code', 'name', 'name_ar', 'description', 'category',
                  'category_name', 'price', 'cost', 'calculated_cost', 'tax_percent',
                  'preparation_time', 'image', 'is_available', 'is_active', 'sort_order',
                  'ingredients', 'profit_margin', 'created_at', 'updated_at']
        read_only_fields = ['id', 'created_at', 'updated_at']
    
    def get_profit_margin(self, obj):
        if obj.cost and obj.cost > 0:
            return round(((obj.price - obj.cost) / obj.price) * 100, 2)
        return 100
    
    def get_calculated_cost(self, obj):
        total = 0
        for ing in obj.ingredients.all():
            if ing.item.purchase_price:
                total += ing.quantity * ing.item.purchase_price
        return round(total, 2)


class MenuItemCreateSerializer(serializers.ModelSerializer):
    """Serializer for creating menu items"""
    ingredients = MenuItemIngredientSerializer(many=True, required=False)
    
    class Meta:
        model = MenuItem
        fields = ['code', 'name', 'name_ar', 'description', 'category', 'price',
                  'cost', 'tax_percent', 'preparation_time', 'image', 'is_available',
                  'is_active', 'sort_order', 'ingredients']
    
    def create(self, validated_data):
        ingredients_data = validated_data.pop('ingredients', [])
        menu_item = MenuItem.objects.create(**validated_data)
        
        for ing_data in ingredients_data:
            ing_data['menu_item'] = menu_item
            MenuItemIngredient.objects.create(**ing_data)
        
        return menu_item
