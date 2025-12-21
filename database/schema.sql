-- =============================================
-- Restaurant Management System Database Schema
-- Production-Ready with all PKs, FKs, Indexes, Constraints
-- =============================================

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- =============================================
-- ENUM TYPES
-- =============================================

-- User Status
CREATE TYPE user_status AS ENUM ('active', 'inactive', 'suspended');

-- Supplier Status
CREATE TYPE supplier_status AS ENUM ('active', 'inactive');

-- Payment Method for Suppliers
CREATE TYPE supplier_payment_method AS ENUM ('cash', 'credit');

-- Payment Status
CREATE TYPE payment_status AS ENUM ('paid', 'pending', 'partial');

-- Transfer Status
CREATE TYPE transfer_status AS ENUM ('pending', 'approved', 'rejected', 'received', 'cancelled');

-- Damage Status
CREATE TYPE damage_status AS ENUM ('pending', 'approved', 'rejected');

-- Supplier Return Status
CREATE TYPE return_status AS ENUM ('pending', 'approved', 'rejected', 'received');

-- Order Status
CREATE TYPE order_status AS ENUM ('new', 'pending_payment', 'paid', 'in_kitchen', 'preparing', 'ready', 'delivered', 'cancelled');

-- Order Payment Method
CREATE TYPE order_payment_method AS ENUM ('cash', 'visa', 'instapay', 'wallet');

-- Inventory Operation Type
CREATE TYPE inventory_operation AS ENUM ('supply', 'transfer_out', 'transfer_in', 'consumption', 'damage', 'return', 'adjustment');

-- Branch Status
CREATE TYPE branch_status AS ENUM ('active', 'inactive', 'maintenance');

-- Item Status
CREATE TYPE item_status AS ENUM ('active', 'inactive');


-- =============================================
-- CORE TABLES
-- =============================================

-- ---------------------------------------------
-- 1. ROLES (الأدوار)
-- ---------------------------------------------
CREATE TABLE roles (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(50) NOT NULL UNIQUE,
    name_ar VARCHAR(50) NOT NULL,
    description TEXT,
    permissions JSONB DEFAULT '{}',
    is_system_role BOOLEAN DEFAULT FALSE, -- للأدوار الأساسية التي لا يمكن حذفها
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Index for role lookup
CREATE INDEX idx_roles_name ON roles(name);

-- ---------------------------------------------
-- 2. BRANCHES (الفروع)
-- ---------------------------------------------
CREATE TABLE branches (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    code VARCHAR(20) NOT NULL UNIQUE, -- كود الفرع (BR001, BR002)
    name VARCHAR(100) NOT NULL,
    name_ar VARCHAR(100) NOT NULL,
    address TEXT,
    phone VARCHAR(20),
    email VARCHAR(100),
    status branch_status DEFAULT 'active',
    is_main_warehouse BOOLEAN DEFAULT FALSE, -- هل هو المخزن الرئيسي
    opening_time TIME,
    closing_time TIME,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT chk_branch_phone CHECK (phone ~ '^\+?[0-9]{10,15}$')
);

-- Index for branch queries
CREATE INDEX idx_branches_status ON branches(status);
CREATE INDEX idx_branches_is_main ON branches(is_main_warehouse);

-- ---------------------------------------------
-- 3. USERS (المستخدمين)
-- ---------------------------------------------
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    employee_code VARCHAR(20) NOT NULL UNIQUE, -- كود الموظف
    username VARCHAR(50) NOT NULL UNIQUE,
    email VARCHAR(100) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    full_name VARCHAR(100) NOT NULL,
    full_name_ar VARCHAR(100),
    phone VARCHAR(20),
    role_id UUID NOT NULL REFERENCES roles(id) ON DELETE RESTRICT,
    branch_id UUID REFERENCES branches(id) ON DELETE SET NULL, -- الفرع المرتبط به
    status user_status DEFAULT 'active',
    last_login TIMESTAMP WITH TIME ZONE,
    password_changed_at TIMESTAMP WITH TIME ZONE,
    failed_login_attempts INTEGER DEFAULT 0,
    locked_until TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    created_by UUID REFERENCES users(id),
    
    CONSTRAINT chk_user_email CHECK (email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$')
);

-- Indexes for user queries
CREATE INDEX idx_users_role ON users(role_id);
CREATE INDEX idx_users_branch ON users(branch_id);
CREATE INDEX idx_users_status ON users(status);
CREATE INDEX idx_users_username ON users(username);
CREATE INDEX idx_users_email ON users(email);


-- ---------------------------------------------
-- 4. CATEGORIES (فئات الأصناف)
-- ---------------------------------------------
CREATE TABLE categories (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    code VARCHAR(20) NOT NULL UNIQUE,
    name VARCHAR(100) NOT NULL,
    name_ar VARCHAR(100) NOT NULL,
    description TEXT,
    parent_id UUID REFERENCES categories(id) ON DELETE SET NULL, -- للفئات الفرعية
    sort_order INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Index for category hierarchy
CREATE INDEX idx_categories_parent ON categories(parent_id);
CREATE INDEX idx_categories_active ON categories(is_active);

-- ---------------------------------------------
-- 5. UNITS (وحدات القياس)
-- ---------------------------------------------
CREATE TABLE units (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    code VARCHAR(10) NOT NULL UNIQUE, -- KG, PC, BOX, etc.
    name VARCHAR(50) NOT NULL,
    name_ar VARCHAR(50) NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- ---------------------------------------------
-- 6. ITEMS (الأصناف)
-- ---------------------------------------------
CREATE TABLE items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    code VARCHAR(50) NOT NULL UNIQUE, -- كود الصنف (ITM001)
    barcode VARCHAR(50) UNIQUE, -- الباركود
    name VARCHAR(150) NOT NULL,
    name_ar VARCHAR(150) NOT NULL,
    description TEXT,
    category_id UUID REFERENCES categories(id) ON DELETE SET NULL,
    unit_id UUID NOT NULL REFERENCES units(id) ON DELETE RESTRICT,
    purchase_price DECIMAL(12, 2) DEFAULT 0, -- سعر الشراء
    selling_price DECIMAL(12, 2) DEFAULT 0, -- سعر البيع
    min_stock_level DECIMAL(12, 3) DEFAULT 0, -- الحد الأدنى للمخزون
    max_stock_level DECIMAL(12, 3), -- الحد الأقصى للمخزون
    reorder_level DECIMAL(12, 3), -- مستوى إعادة الطلب
    is_perishable BOOLEAN DEFAULT FALSE, -- هل قابل للتلف
    shelf_life_days INTEGER, -- مدة الصلاحية بالأيام
    storage_conditions TEXT, -- شروط التخزين
    status item_status DEFAULT 'active',
    image_url TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    created_by UUID REFERENCES users(id),
    
    CONSTRAINT chk_item_prices CHECK (purchase_price >= 0 AND selling_price >= 0),
    CONSTRAINT chk_item_stock_levels CHECK (min_stock_level >= 0 AND (max_stock_level IS NULL OR max_stock_level >= min_stock_level))
);

-- Indexes for item queries
CREATE INDEX idx_items_category ON items(category_id);
CREATE INDEX idx_items_status ON items(status);
CREATE INDEX idx_items_code ON items(code);
CREATE INDEX idx_items_barcode ON items(barcode) WHERE barcode IS NOT NULL;
CREATE INDEX idx_items_perishable ON items(is_perishable) WHERE is_perishable = TRUE;


-- ---------------------------------------------
-- 7. SUPPLIERS (الموردين)
-- ---------------------------------------------
CREATE TABLE suppliers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    code VARCHAR(20) NOT NULL UNIQUE, -- كود المورد (SUP001)
    name VARCHAR(150) NOT NULL,
    name_ar VARCHAR(150),
    contact_person VARCHAR(100), -- اسم المسؤول
    phone VARCHAR(20) NOT NULL,
    phone_alt VARCHAR(20), -- رقم بديل
    email VARCHAR(100),
    address TEXT,
    city VARCHAR(50),
    tax_number VARCHAR(50), -- الرقم الضريبي
    commercial_register VARCHAR(50), -- السجل التجاري
    payment_terms supplier_payment_method DEFAULT 'cash',
    credit_limit DECIMAL(12, 2) DEFAULT 0, -- حد الائتمان
    credit_period_days INTEGER DEFAULT 0, -- فترة السداد بالأيام
    current_balance DECIMAL(12, 2) DEFAULT 0, -- الرصيد الحالي (المديونية)
    status supplier_status DEFAULT 'active',
    notes TEXT,
    rating INTEGER CHECK (rating >= 1 AND rating <= 5), -- تقييم المورد
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    created_by UUID REFERENCES users(id),
    
    CONSTRAINT chk_supplier_balance CHECK (current_balance >= 0),
    CONSTRAINT chk_supplier_credit CHECK (credit_limit >= 0)
);

-- Indexes for supplier queries
CREATE INDEX idx_suppliers_status ON suppliers(status);
CREATE INDEX idx_suppliers_code ON suppliers(code);
CREATE INDEX idx_suppliers_balance ON suppliers(current_balance) WHERE current_balance > 0;

-- ---------------------------------------------
-- 8. SUPPLIER_ITEMS (أصناف الموردين)
-- ربط الموردين بالأصناف التي يوردونها
-- ---------------------------------------------
CREATE TABLE supplier_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    supplier_id UUID NOT NULL REFERENCES suppliers(id) ON DELETE CASCADE,
    item_id UUID NOT NULL REFERENCES items(id) ON DELETE CASCADE,
    supplier_item_code VARCHAR(50), -- كود الصنف عند المورد
    unit_price DECIMAL(12, 2), -- سعر الوحدة من هذا المورد
    min_order_quantity DECIMAL(12, 3), -- الحد الأدنى للطلب
    lead_time_days INTEGER, -- وقت التوريد بالأيام
    is_preferred BOOLEAN DEFAULT FALSE, -- هل هو المورد المفضل لهذا الصنف
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT uk_supplier_item UNIQUE (supplier_id, item_id)
);

-- Indexes
CREATE INDEX idx_supplier_items_supplier ON supplier_items(supplier_id);
CREATE INDEX idx_supplier_items_item ON supplier_items(item_id);
CREATE INDEX idx_supplier_items_preferred ON supplier_items(is_preferred) WHERE is_preferred = TRUE;


-- =============================================
-- INVENTORY TABLES
-- =============================================

-- ---------------------------------------------
-- 9. INVENTORY (المخزون)
-- جدول موحد للمخزون الرئيسي والفرعي
-- ---------------------------------------------
CREATE TABLE inventory (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    branch_id UUID NOT NULL REFERENCES branches(id) ON DELETE RESTRICT,
    item_id UUID NOT NULL REFERENCES items(id) ON DELETE RESTRICT,
    quantity DECIMAL(12, 3) NOT NULL DEFAULT 0,
    reserved_quantity DECIMAL(12, 3) DEFAULT 0, -- الكمية المحجوزة
    available_quantity DECIMAL(12, 3) GENERATED ALWAYS AS (quantity - reserved_quantity) STORED,
    min_quantity DECIMAL(12, 3) DEFAULT 0, -- الحد الأدنى لهذا الفرع
    last_restock_date TIMESTAMP WITH TIME ZONE,
    last_count_date TIMESTAMP WITH TIME ZONE, -- آخر جرد
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT uk_inventory_branch_item UNIQUE (branch_id, item_id),
    CONSTRAINT chk_inventory_quantity CHECK (quantity >= 0),
    CONSTRAINT chk_inventory_reserved CHECK (reserved_quantity >= 0 AND reserved_quantity <= quantity)
);

-- Indexes for inventory queries
CREATE INDEX idx_inventory_branch ON inventory(branch_id);
CREATE INDEX idx_inventory_item ON inventory(item_id);
CREATE INDEX idx_inventory_low_stock ON inventory(branch_id, item_id) WHERE quantity <= min_quantity;

-- ---------------------------------------------
-- 10. INVENTORY_BATCHES (دفعات المخزون)
-- لتتبع الصلاحية والـ FIFO
-- ---------------------------------------------
CREATE TABLE inventory_batches (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    inventory_id UUID NOT NULL REFERENCES inventory(id) ON DELETE CASCADE,
    batch_number VARCHAR(50), -- رقم الدفعة
    quantity DECIMAL(12, 3) NOT NULL,
    remaining_quantity DECIMAL(12, 3) NOT NULL,
    purchase_price DECIMAL(12, 2), -- سعر الشراء لهذه الدفعة
    production_date DATE,
    expiry_date DATE,
    received_date DATE NOT NULL DEFAULT CURRENT_DATE,
    supply_id UUID, -- مرجع للتوريد (سيتم ربطه لاحقاً)
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT chk_batch_quantity CHECK (quantity > 0),
    CONSTRAINT chk_batch_remaining CHECK (remaining_quantity >= 0 AND remaining_quantity <= quantity),
    CONSTRAINT chk_batch_dates CHECK (expiry_date IS NULL OR expiry_date > production_date)
);

-- Indexes for batch queries
CREATE INDEX idx_batches_inventory ON inventory_batches(inventory_id);
CREATE INDEX idx_batches_expiry ON inventory_batches(expiry_date) WHERE expiry_date IS NOT NULL;
CREATE INDEX idx_batches_remaining ON inventory_batches(remaining_quantity) WHERE remaining_quantity > 0;


-- =============================================
-- SUPPLY TABLES (التوريدات)
-- =============================================

-- ---------------------------------------------
-- 11. SUPPLIES (التوريدات)
-- ---------------------------------------------
CREATE TABLE supplies (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    supply_number VARCHAR(30) NOT NULL UNIQUE, -- رقم التوريد (SUP-2024-0001)
    supplier_id UUID NOT NULL REFERENCES suppliers(id) ON DELETE RESTRICT,
    branch_id UUID NOT NULL REFERENCES branches(id) ON DELETE RESTRICT, -- المخزن المستلم (الرئيسي)
    invoice_number VARCHAR(50), -- رقم فاتورة المورد
    invoice_date DATE,
    subtotal DECIMAL(12, 2) NOT NULL DEFAULT 0, -- المجموع قبل الضريبة
    tax_amount DECIMAL(12, 2) DEFAULT 0, -- الضريبة
    discount_amount DECIMAL(12, 2) DEFAULT 0, -- الخصم
    total_amount DECIMAL(12, 2) NOT NULL DEFAULT 0, -- الإجمالي
    payment_method supplier_payment_method NOT NULL,
    payment_status payment_status DEFAULT 'pending',
    paid_amount DECIMAL(12, 2) DEFAULT 0, -- المبلغ المدفوع
    remaining_amount DECIMAL(12, 2) GENERATED ALWAYS AS (total_amount - paid_amount) STORED,
    due_date DATE, -- تاريخ الاستحقاق (للآجل)
    notes TEXT,
    received_by UUID NOT NULL REFERENCES users(id), -- من استلم
    received_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    approved_by UUID REFERENCES users(id),
    approved_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT chk_supply_amounts CHECK (
        subtotal >= 0 AND 
        tax_amount >= 0 AND 
        discount_amount >= 0 AND 
        total_amount >= 0 AND
        paid_amount >= 0 AND
        paid_amount <= total_amount
    )
);

-- Indexes for supply queries
CREATE INDEX idx_supplies_supplier ON supplies(supplier_id);
CREATE INDEX idx_supplies_branch ON supplies(branch_id);
CREATE INDEX idx_supplies_date ON supplies(received_at);
CREATE INDEX idx_supplies_payment_status ON supplies(payment_status) WHERE payment_status != 'paid';
CREATE INDEX idx_supplies_number ON supplies(supply_number);

-- ---------------------------------------------
-- 12. SUPPLY_ITEMS (تفاصيل التوريدات)
-- ---------------------------------------------
CREATE TABLE supply_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    supply_id UUID NOT NULL REFERENCES supplies(id) ON DELETE CASCADE,
    item_id UUID NOT NULL REFERENCES items(id) ON DELETE RESTRICT,
    quantity DECIMAL(12, 3) NOT NULL,
    received_quantity DECIMAL(12, 3) NOT NULL, -- الكمية المستلمة فعلياً
    unit_price DECIMAL(12, 2) NOT NULL,
    discount_percent DECIMAL(5, 2) DEFAULT 0,
    tax_percent DECIMAL(5, 2) DEFAULT 0,
    total_price DECIMAL(12, 2) NOT NULL,
    batch_number VARCHAR(50),
    production_date DATE,
    expiry_date DATE,
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT chk_supply_item_qty CHECK (quantity > 0 AND received_quantity >= 0),
    CONSTRAINT chk_supply_item_price CHECK (unit_price >= 0 AND total_price >= 0),
    CONSTRAINT chk_supply_item_discount CHECK (discount_percent >= 0 AND discount_percent <= 100)
);

-- Indexes
CREATE INDEX idx_supply_items_supply ON supply_items(supply_id);
CREATE INDEX idx_supply_items_item ON supply_items(item_id);

-- Add FK to inventory_batches
ALTER TABLE inventory_batches ADD CONSTRAINT fk_batch_supply 
    FOREIGN KEY (supply_id) REFERENCES supplies(id) ON DELETE SET NULL;


-- ---------------------------------------------
-- 13. SUPPLIER_PAYMENTS (مدفوعات الموردين)
-- ---------------------------------------------
CREATE TABLE supplier_payments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    payment_number VARCHAR(30) NOT NULL UNIQUE, -- رقم السداد (PAY-2024-0001)
    supplier_id UUID NOT NULL REFERENCES suppliers(id) ON DELETE RESTRICT,
    supply_id UUID REFERENCES supplies(id) ON DELETE SET NULL, -- التوريد المرتبط (اختياري)
    amount DECIMAL(12, 2) NOT NULL,
    payment_method VARCHAR(50) NOT NULL, -- cash, bank_transfer, check
    reference_number VARCHAR(50), -- رقم الشيك أو التحويل
    bank_name VARCHAR(100),
    payment_date DATE NOT NULL DEFAULT CURRENT_DATE,
    notes TEXT,
    created_by UUID NOT NULL REFERENCES users(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT chk_payment_amount CHECK (amount > 0)
);

-- Indexes
CREATE INDEX idx_supplier_payments_supplier ON supplier_payments(supplier_id);
CREATE INDEX idx_supplier_payments_supply ON supplier_payments(supply_id);
CREATE INDEX idx_supplier_payments_date ON supplier_payments(payment_date);

-- =============================================
-- TRANSFER TABLES (التحويلات)
-- =============================================

-- ---------------------------------------------
-- 14. TRANSFERS (تحويلات المخزون)
-- ---------------------------------------------
CREATE TABLE transfers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    transfer_number VARCHAR(30) NOT NULL UNIQUE, -- رقم التحويل (TRF-2024-0001)
    from_branch_id UUID NOT NULL REFERENCES branches(id) ON DELETE RESTRICT,
    to_branch_id UUID NOT NULL REFERENCES branches(id) ON DELETE RESTRICT,
    status transfer_status DEFAULT 'pending',
    priority INTEGER DEFAULT 0, -- أولوية التحويل
    notes TEXT,
    requested_by UUID NOT NULL REFERENCES users(id),
    requested_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    approved_by UUID REFERENCES users(id),
    approved_at TIMESTAMP WITH TIME ZONE,
    rejected_by UUID REFERENCES users(id),
    rejected_at TIMESTAMP WITH TIME ZONE,
    rejection_reason TEXT,
    shipped_at TIMESTAMP WITH TIME ZONE,
    received_by UUID REFERENCES users(id),
    received_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT chk_transfer_branches CHECK (from_branch_id != to_branch_id)
);

-- Indexes
CREATE INDEX idx_transfers_from_branch ON transfers(from_branch_id);
CREATE INDEX idx_transfers_to_branch ON transfers(to_branch_id);
CREATE INDEX idx_transfers_status ON transfers(status);
CREATE INDEX idx_transfers_date ON transfers(requested_at);

-- ---------------------------------------------
-- 15. TRANSFER_ITEMS (تفاصيل التحويلات)
-- ---------------------------------------------
CREATE TABLE transfer_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    transfer_id UUID NOT NULL REFERENCES transfers(id) ON DELETE CASCADE,
    item_id UUID NOT NULL REFERENCES items(id) ON DELETE RESTRICT,
    requested_quantity DECIMAL(12, 3) NOT NULL,
    approved_quantity DECIMAL(12, 3), -- الكمية الموافق عليها
    shipped_quantity DECIMAL(12, 3), -- الكمية المشحونة
    received_quantity DECIMAL(12, 3), -- الكمية المستلمة
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT chk_transfer_item_qty CHECK (
        requested_quantity > 0 AND
        (approved_quantity IS NULL OR approved_quantity >= 0) AND
        (shipped_quantity IS NULL OR shipped_quantity >= 0) AND
        (received_quantity IS NULL OR received_quantity >= 0)
    )
);

-- Indexes
CREATE INDEX idx_transfer_items_transfer ON transfer_items(transfer_id);
CREATE INDEX idx_transfer_items_item ON transfer_items(item_id);


-- =============================================
-- DAMAGE TABLES (التالف)
-- =============================================

-- ---------------------------------------------
-- 16. DAMAGE_REASONS (أسباب التلف)
-- ---------------------------------------------
CREATE TABLE damage_reasons (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    code VARCHAR(20) NOT NULL UNIQUE,
    name VARCHAR(100) NOT NULL,
    name_ar VARCHAR(100) NOT NULL,
    description TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    sort_order INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- ---------------------------------------------
-- 17. DAMAGES (التالف)
-- ---------------------------------------------
CREATE TABLE damages (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    damage_number VARCHAR(30) NOT NULL UNIQUE, -- رقم التالف (DMG-2024-0001)
    branch_id UUID NOT NULL REFERENCES branches(id) ON DELETE RESTRICT,
    item_id UUID NOT NULL REFERENCES items(id) ON DELETE RESTRICT,
    quantity DECIMAL(12, 3) NOT NULL,
    unit_cost DECIMAL(12, 2), -- تكلفة الوحدة
    total_cost DECIMAL(12, 2), -- التكلفة الإجمالية
    reason_id UUID NOT NULL REFERENCES damage_reasons(id) ON DELETE RESTRICT,
    description TEXT, -- وصف تفصيلي
    image_url TEXT, -- صورة التالف
    batch_id UUID REFERENCES inventory_batches(id) ON DELETE SET NULL, -- الدفعة التالفة
    status damage_status DEFAULT 'pending',
    registered_by UUID NOT NULL REFERENCES users(id),
    registered_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    approved_by UUID REFERENCES users(id),
    approved_at TIMESTAMP WITH TIME ZONE,
    rejected_by UUID REFERENCES users(id),
    rejected_at TIMESTAMP WITH TIME ZONE,
    rejection_reason TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT chk_damage_quantity CHECK (quantity > 0),
    CONSTRAINT chk_damage_cost CHECK (unit_cost IS NULL OR unit_cost >= 0)
);

-- Indexes
CREATE INDEX idx_damages_branch ON damages(branch_id);
CREATE INDEX idx_damages_item ON damages(item_id);
CREATE INDEX idx_damages_status ON damages(status);
CREATE INDEX idx_damages_reason ON damages(reason_id);
CREATE INDEX idx_damages_date ON damages(registered_at);

-- =============================================
-- SUPPLIER RETURNS (مرتجعات الموردين)
-- =============================================

-- ---------------------------------------------
-- 18. SUPPLIER_RETURNS (مرتجعات الموردين)
-- ---------------------------------------------
CREATE TABLE supplier_returns (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    return_number VARCHAR(30) NOT NULL UNIQUE, -- رقم المرتجع (RET-2024-0001)
    supply_id UUID NOT NULL REFERENCES supplies(id) ON DELETE RESTRICT, -- التوريد الأصلي
    supplier_id UUID NOT NULL REFERENCES suppliers(id) ON DELETE RESTRICT,
    item_id UUID NOT NULL REFERENCES items(id) ON DELETE RESTRICT,
    quantity DECIMAL(12, 3) NOT NULL,
    unit_price DECIMAL(12, 2) NOT NULL, -- سعر الوحدة من التوريد الأصلي
    total_amount DECIMAL(12, 2) NOT NULL,
    reason TEXT NOT NULL, -- سبب الإرجاع
    description TEXT,
    image_url TEXT,
    status return_status DEFAULT 'pending',
    registered_by UUID NOT NULL REFERENCES users(id),
    registered_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    approved_by UUID REFERENCES users(id),
    approved_at TIMESTAMP WITH TIME ZONE,
    rejected_by UUID REFERENCES users(id),
    rejected_at TIMESTAMP WITH TIME ZONE,
    rejection_reason TEXT,
    received_by_supplier_at TIMESTAMP WITH TIME ZONE, -- تاريخ استلام المورد
    credit_note_number VARCHAR(50), -- رقم إشعار الدائن
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT chk_return_quantity CHECK (quantity > 0),
    CONSTRAINT chk_return_amount CHECK (total_amount >= 0)
);

-- Indexes
CREATE INDEX idx_returns_supply ON supplier_returns(supply_id);
CREATE INDEX idx_returns_supplier ON supplier_returns(supplier_id);
CREATE INDEX idx_returns_status ON supplier_returns(status);
CREATE INDEX idx_returns_date ON supplier_returns(registered_at);


-- =============================================
-- ORDER TABLES (الأوردرات)
-- =============================================

-- ---------------------------------------------
-- 19. MENU_CATEGORIES (فئات المنيو)
-- ---------------------------------------------
CREATE TABLE menu_categories (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    code VARCHAR(20) NOT NULL UNIQUE,
    name VARCHAR(100) NOT NULL,
    name_ar VARCHAR(100) NOT NULL,
    description TEXT,
    image_url TEXT,
    parent_id UUID REFERENCES menu_categories(id) ON DELETE SET NULL,
    sort_order INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Index
CREATE INDEX idx_menu_categories_parent ON menu_categories(parent_id);
CREATE INDEX idx_menu_categories_active ON menu_categories(is_active);

-- ---------------------------------------------
-- 20. MENU_ITEMS (أصناف المنيو - المنتجات للبيع)
-- ---------------------------------------------
CREATE TABLE menu_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    name_ar VARCHAR(150) NOT NULL,
    description TEXT,
    description_ar TEXT,
    category_id UUID REFERENCES menu_categories(id) ON DELETE SET NULL,
    price DECIMAL(12, 2) NOT NULL,
    cost DECIMAL(12, 2) DEFAULT 0, -- التكلفة (محسوبة من المكونات)
    tax_percent DECIMAL(5, 2) DEFAULT 0,
    image_url TEXT,
    preparation_time_minutes INTEGER, -- وقت التحضير
    calories INTEGER,
    is_available BOOLEAN DEFAULT TRUE,
    is_active BOOLEAN DEFAULT TRUE,
    sort_order INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT chk_menu_item_price CHECK (price >= 0),
    CONSTRAINT chk_menu_item_cost CHECK (cost >= 0)
);

-- Indexes
CREATE INDEX idx_menu_items_category ON menu_items(category_id);
CREATE INDEX idx_menu_items_available ON menu_items(is_available, is_active);

-- ---------------------------------------------
-- 21. MENU_ITEM_INGREDIENTS (مكونات المنتج - الوصفة)
-- ---------------------------------------------
CREATE TABLE menu_item_ingredients (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    menu_item_id UUID NOT NULL REFERENCES menu_items(id) ON DELETE CASCADE,
    item_id UUID NOT NULL REFERENCES items(id) ON DELETE RESTRICT, -- الصنف من المخزون
    quantity DECIMAL(12, 4) NOT NULL, -- الكمية المطلوبة
    unit_id UUID NOT NULL REFERENCES units(id) ON DELETE RESTRICT,
    is_optional BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT uk_menu_ingredient UNIQUE (menu_item_id, item_id),
    CONSTRAINT chk_ingredient_qty CHECK (quantity > 0)
);

-- Indexes
CREATE INDEX idx_menu_ingredients_menu ON menu_item_ingredients(menu_item_id);
CREATE INDEX idx_menu_ingredients_item ON menu_item_ingredients(item_id);


-- ---------------------------------------------
-- 22. ORDERS (الأوردرات)
-- ---------------------------------------------
CREATE TABLE orders (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    order_number VARCHAR(30) NOT NULL UNIQUE, -- رقم الأوردر (ORD-2024-0001)
    branch_id UUID NOT NULL REFERENCES branches(id) ON DELETE RESTRICT,
    order_type VARCHAR(20) DEFAULT 'takeaway', -- takeaway, dine_in, delivery (للمستقبل)
    customer_name VARCHAR(100),
    customer_phone VARCHAR(20),
    subtotal DECIMAL(12, 2) NOT NULL DEFAULT 0,
    tax_amount DECIMAL(12, 2) DEFAULT 0,
    discount_amount DECIMAL(12, 2) DEFAULT 0,
    discount_reason TEXT,
    total_amount DECIMAL(12, 2) NOT NULL DEFAULT 0,
    payment_method order_payment_method,
    payment_reference VARCHAR(100), -- رقم مرجع الدفع
    status order_status DEFAULT 'new',
    notes TEXT,
    kitchen_notes TEXT, -- ملاحظات للمطبخ
    cashier_id UUID NOT NULL REFERENCES users(id),
    chef_id UUID REFERENCES users(id), -- الطباخ المسؤول
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    paid_at TIMESTAMP WITH TIME ZONE,
    sent_to_kitchen_at TIMESTAMP WITH TIME ZONE,
    preparation_started_at TIMESTAMP WITH TIME ZONE,
    ready_at TIMESTAMP WITH TIME ZONE,
    delivered_at TIMESTAMP WITH TIME ZONE,
    cancelled_at TIMESTAMP WITH TIME ZONE,
    cancelled_by UUID REFERENCES users(id),
    cancellation_reason TEXT,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT chk_order_amounts CHECK (
        subtotal >= 0 AND
        tax_amount >= 0 AND
        discount_amount >= 0 AND
        total_amount >= 0
    )
);

-- Indexes
CREATE INDEX idx_orders_branch ON orders(branch_id);
CREATE INDEX idx_orders_status ON orders(status);
CREATE INDEX idx_orders_date ON orders(created_at);
CREATE INDEX idx_orders_cashier ON orders(cashier_id);
CREATE INDEX idx_orders_number ON orders(order_number);
CREATE INDEX idx_orders_pending ON orders(branch_id, status) WHERE status NOT IN ('delivered', 'cancelled');

-- ---------------------------------------------
-- 23. ORDER_ITEMS (تفاصيل الأوردر)
-- ---------------------------------------------
CREATE TABLE order_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    menu_item_id UUID NOT NULL REFERENCES menu_items(id) ON DELETE RESTRICT,
    quantity INTEGER NOT NULL,
    unit_price DECIMAL(12, 2) NOT NULL,
    discount_amount DECIMAL(12, 2) DEFAULT 0,
    total_price DECIMAL(12, 2) NOT NULL,
    notes TEXT, -- ملاحظات خاصة بهذا الصنف
    status VARCHAR(20) DEFAULT 'pending', -- pending, preparing, ready
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT chk_order_item_qty CHECK (quantity > 0),
    CONSTRAINT chk_order_item_price CHECK (unit_price >= 0 AND total_price >= 0)
);

-- Indexes
CREATE INDEX idx_order_items_order ON order_items(order_id);
CREATE INDEX idx_order_items_menu ON order_items(menu_item_id);


-- =============================================
-- INVENTORY TRACKING TABLES
-- =============================================

-- ---------------------------------------------
-- 24. INVENTORY_TRANSACTIONS (حركات المخزون)
-- سجل كامل لكل حركة على المخزون
-- ---------------------------------------------
CREATE TABLE inventory_transactions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    branch_id UUID NOT NULL REFERENCES branches(id) ON DELETE RESTRICT,
    item_id UUID NOT NULL REFERENCES items(id) ON DELETE RESTRICT,
    operation_type inventory_operation NOT NULL,
    quantity DECIMAL(12, 3) NOT NULL, -- موجب للإضافة، سالب للخصم
    quantity_before DECIMAL(12, 3) NOT NULL, -- الكمية قبل العملية
    quantity_after DECIMAL(12, 3) NOT NULL, -- الكمية بعد العملية
    unit_cost DECIMAL(12, 2), -- تكلفة الوحدة
    reference_type VARCHAR(50), -- supply, transfer, order, damage, return, adjustment
    reference_id UUID, -- معرف العملية المرجعية
    batch_id UUID REFERENCES inventory_batches(id) ON DELETE SET NULL,
    notes TEXT,
    created_by UUID NOT NULL REFERENCES users(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT chk_transaction_qty CHECK (quantity != 0)
);

-- Indexes
CREATE INDEX idx_inv_trans_branch ON inventory_transactions(branch_id);
CREATE INDEX idx_inv_trans_item ON inventory_transactions(item_id);
CREATE INDEX idx_inv_trans_type ON inventory_transactions(operation_type);
CREATE INDEX idx_inv_trans_date ON inventory_transactions(created_at);
CREATE INDEX idx_inv_trans_ref ON inventory_transactions(reference_type, reference_id);

-- ---------------------------------------------
-- 25. DAILY_INVENTORY_COUNTS (الجرد اليومي)
-- ---------------------------------------------
CREATE TABLE daily_inventory_counts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    branch_id UUID NOT NULL REFERENCES branches(id) ON DELETE RESTRICT,
    count_date DATE NOT NULL,
    count_type VARCHAR(20) NOT NULL, -- opening, closing
    status VARCHAR(20) DEFAULT 'draft', -- draft, submitted, approved
    notes TEXT,
    counted_by UUID NOT NULL REFERENCES users(id),
    submitted_at TIMESTAMP WITH TIME ZONE,
    approved_by UUID REFERENCES users(id),
    approved_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT uk_daily_count UNIQUE (branch_id, count_date, count_type)
);

-- Index
CREATE INDEX idx_daily_counts_branch_date ON daily_inventory_counts(branch_id, count_date);

-- ---------------------------------------------
-- 26. DAILY_INVENTORY_COUNT_ITEMS (تفاصيل الجرد)
-- ---------------------------------------------
CREATE TABLE daily_inventory_count_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    count_id UUID NOT NULL REFERENCES daily_inventory_counts(id) ON DELETE CASCADE,
    item_id UUID NOT NULL REFERENCES items(id) ON DELETE RESTRICT,
    system_quantity DECIMAL(12, 3) NOT NULL, -- الكمية في النظام
    actual_quantity DECIMAL(12, 3) NOT NULL, -- الكمية الفعلية
    variance DECIMAL(12, 3) GENERATED ALWAYS AS (actual_quantity - system_quantity) STORED,
    variance_reason TEXT, -- سبب الفرق
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT uk_count_item UNIQUE (count_id, item_id)
);

-- Index
CREATE INDEX idx_count_items_count ON daily_inventory_count_items(count_id);
CREATE INDEX idx_count_items_variance ON daily_inventory_count_items(count_id) 
    WHERE actual_quantity != system_quantity;


-- =============================================
-- NOTIFICATION & ALERT TABLES
-- =============================================

-- ---------------------------------------------
-- 27. NOTIFICATIONS (الإشعارات)
-- ---------------------------------------------
CREATE TABLE notifications (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE, -- NULL = للجميع
    branch_id UUID REFERENCES branches(id) ON DELETE CASCADE,
    type VARCHAR(50) NOT NULL, -- low_stock, expiry_warning, pending_approval, etc.
    title VARCHAR(200) NOT NULL,
    message TEXT NOT NULL,
    priority VARCHAR(20) DEFAULT 'normal', -- low, normal, high, urgent
    reference_type VARCHAR(50), -- item, supply, transfer, damage, etc.
    reference_id UUID,
    is_read BOOLEAN DEFAULT FALSE,
    read_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP WITH TIME ZONE
);

-- Indexes
CREATE INDEX idx_notifications_user ON notifications(user_id);
CREATE INDEX idx_notifications_branch ON notifications(branch_id);
CREATE INDEX idx_notifications_unread ON notifications(user_id, is_read) WHERE is_read = FALSE;
CREATE INDEX idx_notifications_type ON notifications(type);

-- ---------------------------------------------
-- 28. ALERT_SETTINGS (إعدادات التنبيهات)
-- ---------------------------------------------
CREATE TABLE alert_settings (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    branch_id UUID REFERENCES branches(id) ON DELETE CASCADE, -- NULL = عام
    alert_type VARCHAR(50) NOT NULL, -- low_stock, expiry_warning, etc.
    is_enabled BOOLEAN DEFAULT TRUE,
    threshold_value DECIMAL(12, 3), -- القيمة الحدية
    threshold_days INTEGER, -- عدد الأيام (للصلاحية)
    notify_roles TEXT[], -- الأدوار التي تستلم التنبيه
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT uk_alert_setting UNIQUE (branch_id, alert_type)
);

-- =============================================
-- AUDIT & LOG TABLES
-- =============================================

-- ---------------------------------------------
-- 29. AUDIT_LOGS (سجل المراجعة)
-- ---------------------------------------------
CREATE TABLE audit_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    action VARCHAR(50) NOT NULL, -- create, update, delete, login, logout, etc.
    table_name VARCHAR(100),
    record_id UUID,
    old_values JSONB,
    new_values JSONB,
    ip_address INET,
    user_agent TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Indexes
CREATE INDEX idx_audit_user ON audit_logs(user_id);
CREATE INDEX idx_audit_table ON audit_logs(table_name);
CREATE INDEX idx_audit_date ON audit_logs(created_at);
CREATE INDEX idx_audit_action ON audit_logs(action);

-- ---------------------------------------------
-- 30. USER_SESSIONS (جلسات المستخدمين)
-- ---------------------------------------------
CREATE TABLE user_sessions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token_hash VARCHAR(255) NOT NULL,
    device_info TEXT,
    ip_address INET,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    last_activity_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Indexes
CREATE INDEX idx_sessions_user ON user_sessions(user_id);
CREATE INDEX idx_sessions_active ON user_sessions(user_id, is_active) WHERE is_active = TRUE;
CREATE INDEX idx_sessions_token ON user_sessions(token_hash);


-- =============================================
-- SETTINGS & CONFIGURATION TABLES
-- =============================================

-- ---------------------------------------------
-- 31. SYSTEM_SETTINGS (إعدادات النظام)
-- ---------------------------------------------
CREATE TABLE system_settings (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    key VARCHAR(100) NOT NULL UNIQUE,
    value TEXT,
    value_type VARCHAR(20) DEFAULT 'string', -- string, number, boolean, json
    description TEXT,
    is_public BOOLEAN DEFAULT FALSE, -- هل يظهر للمستخدمين
    updated_by UUID REFERENCES users(id),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Index
CREATE INDEX idx_settings_key ON system_settings(key);

-- ---------------------------------------------
-- 32. BRANCH_SETTINGS (إعدادات الفروع)
-- ---------------------------------------------
CREATE TABLE branch_settings (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    branch_id UUID NOT NULL REFERENCES branches(id) ON DELETE CASCADE,
    key VARCHAR(100) NOT NULL,
    value TEXT,
    updated_by UUID REFERENCES users(id),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT uk_branch_setting UNIQUE (branch_id, key)
);

-- Index
CREATE INDEX idx_branch_settings_branch ON branch_settings(branch_id);

-- =============================================
-- REPORTING VIEWS
-- =============================================

-- ---------------------------------------------
-- View: Current Inventory Status
-- ---------------------------------------------
CREATE OR REPLACE VIEW v_inventory_status AS
SELECT 
    i.id,
    b.id AS branch_id,
    b.name AS branch_name,
    b.is_main_warehouse,
    it.id AS item_id,
    it.code AS item_code,
    it.name AS item_name,
    it.name_ar AS item_name_ar,
    c.name AS category_name,
    u.name AS unit_name,
    i.quantity,
    i.reserved_quantity,
    i.available_quantity,
    i.min_quantity,
    CASE 
        WHEN i.quantity <= 0 THEN 'out_of_stock'
        WHEN i.quantity <= i.min_quantity THEN 'low_stock'
        ELSE 'in_stock'
    END AS stock_status,
    i.last_restock_date,
    i.last_count_date
FROM inventory i
JOIN branches b ON i.branch_id = b.id
JOIN items it ON i.item_id = it.id
LEFT JOIN categories c ON it.category_id = c.id
LEFT JOIN units u ON it.unit_id = u.id
WHERE it.status = 'active';

-- ---------------------------------------------
-- View: Supplier Balances
-- ---------------------------------------------
CREATE OR REPLACE VIEW v_supplier_balances AS
SELECT 
    s.id,
    s.code,
    s.name,
    s.phone,
    s.payment_terms,
    s.credit_limit,
    s.current_balance,
    s.status,
    COUNT(DISTINCT sup.id) AS total_supplies,
    COALESCE(SUM(CASE WHEN sup.payment_status != 'paid' THEN sup.remaining_amount ELSE 0 END), 0) AS pending_amount,
    MAX(sup.received_at) AS last_supply_date
FROM suppliers s
LEFT JOIN supplies sup ON s.id = sup.supplier_id
GROUP BY s.id;

-- ---------------------------------------------
-- View: Daily Sales Summary
-- ---------------------------------------------
CREATE OR REPLACE VIEW v_daily_sales AS
SELECT 
    o.branch_id,
    b.name AS branch_name,
    DATE(o.created_at) AS sale_date,
    COUNT(*) AS total_orders,
    COUNT(*) FILTER (WHERE o.status = 'delivered') AS completed_orders,
    COUNT(*) FILTER (WHERE o.status = 'cancelled') AS cancelled_orders,
    SUM(CASE WHEN o.status = 'delivered' THEN o.total_amount ELSE 0 END) AS total_sales,
    SUM(CASE WHEN o.status = 'delivered' THEN o.discount_amount ELSE 0 END) AS total_discounts,
    SUM(CASE WHEN o.status = 'delivered' THEN o.tax_amount ELSE 0 END) AS total_tax,
    COUNT(*) FILTER (WHERE o.payment_method = 'cash' AND o.status = 'delivered') AS cash_orders,
    COUNT(*) FILTER (WHERE o.payment_method = 'visa' AND o.status = 'delivered') AS visa_orders,
    COUNT(*) FILTER (WHERE o.payment_method = 'instapay' AND o.status = 'delivered') AS instapay_orders,
    COUNT(*) FILTER (WHERE o.payment_method = 'wallet' AND o.status = 'delivered') AS wallet_orders
FROM orders o
JOIN branches b ON o.branch_id = b.id
GROUP BY o.branch_id, b.name, DATE(o.created_at);


-- ---------------------------------------------
-- View: Pending Approvals
-- ---------------------------------------------
CREATE OR REPLACE VIEW v_pending_approvals AS
SELECT 
    'transfer' AS type,
    t.id,
    t.transfer_number AS reference_number,
    t.requested_at AS created_at,
    u.full_name AS requested_by,
    fb.name AS from_location,
    tb.name AS to_location,
    NULL AS amount
FROM transfers t
JOIN users u ON t.requested_by = u.id
JOIN branches fb ON t.from_branch_id = fb.id
JOIN branches tb ON t.to_branch_id = tb.id
WHERE t.status = 'pending'

UNION ALL

SELECT 
    'damage' AS type,
    d.id,
    d.damage_number AS reference_number,
    d.registered_at AS created_at,
    u.full_name AS requested_by,
    b.name AS from_location,
    NULL AS to_location,
    d.total_cost AS amount
FROM damages d
JOIN users u ON d.registered_by = u.id
JOIN branches b ON d.branch_id = b.id
WHERE d.status = 'pending'

UNION ALL

SELECT 
    'supplier_return' AS type,
    sr.id,
    sr.return_number AS reference_number,
    sr.registered_at AS created_at,
    u.full_name AS requested_by,
    s.name AS from_location,
    NULL AS to_location,
    sr.total_amount AS amount
FROM supplier_returns sr
JOIN users u ON sr.registered_by = u.id
JOIN suppliers s ON sr.supplier_id = s.id
WHERE sr.status = 'pending';

-- ---------------------------------------------
-- View: Expiring Items
-- ---------------------------------------------
CREATE OR REPLACE VIEW v_expiring_items AS
SELECT 
    ib.id AS batch_id,
    i.branch_id,
    b.name AS branch_name,
    it.id AS item_id,
    it.code AS item_code,
    it.name AS item_name,
    ib.batch_number,
    ib.remaining_quantity,
    ib.expiry_date,
    ib.expiry_date - CURRENT_DATE AS days_until_expiry,
    CASE 
        WHEN ib.expiry_date <= CURRENT_DATE THEN 'expired'
        WHEN ib.expiry_date <= CURRENT_DATE + INTERVAL '7 days' THEN 'critical'
        WHEN ib.expiry_date <= CURRENT_DATE + INTERVAL '30 days' THEN 'warning'
        ELSE 'ok'
    END AS expiry_status
FROM inventory_batches ib
JOIN inventory i ON ib.inventory_id = i.id
JOIN branches b ON i.branch_id = b.id
JOIN items it ON i.item_id = it.id
WHERE ib.remaining_quantity > 0
  AND ib.expiry_date IS NOT NULL
  AND ib.expiry_date <= CURRENT_DATE + INTERVAL '30 days'
ORDER BY ib.expiry_date;

-- =============================================
-- FUNCTIONS & TRIGGERS
-- =============================================

-- ---------------------------------------------
-- Function: Update timestamp
-- ---------------------------------------------
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Apply to all tables with updated_at
CREATE TRIGGER update_roles_updated_at BEFORE UPDATE ON roles
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_branches_updated_at BEFORE UPDATE ON branches
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_categories_updated_at BEFORE UPDATE ON categories
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_items_updated_at BEFORE UPDATE ON items
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_suppliers_updated_at BEFORE UPDATE ON suppliers
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_supplier_items_updated_at BEFORE UPDATE ON supplier_items
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_inventory_updated_at BEFORE UPDATE ON inventory
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_supplies_updated_at BEFORE UPDATE ON supplies
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_transfers_updated_at BEFORE UPDATE ON transfers
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_damages_updated_at BEFORE UPDATE ON damages
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_supplier_returns_updated_at BEFORE UPDATE ON supplier_returns
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_menu_categories_updated_at BEFORE UPDATE ON menu_categories
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_menu_items_updated_at BEFORE UPDATE ON menu_items
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_orders_updated_at BEFORE UPDATE ON orders
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_daily_counts_updated_at BEFORE UPDATE ON daily_inventory_counts
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_alert_settings_updated_at BEFORE UPDATE ON alert_settings
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();


-- ---------------------------------------------
-- Function: Generate Sequential Number
-- ---------------------------------------------
CREATE OR REPLACE FUNCTION generate_sequence_number(
    p_prefix VARCHAR,
    p_table VARCHAR,
    p_column VARCHAR
) RETURNS VARCHAR AS $$
DECLARE
    v_year VARCHAR(4);
    v_sequence INTEGER;
    v_result VARCHAR;
BEGIN
    v_year := TO_CHAR(CURRENT_DATE, 'YYYY');
    
    EXECUTE format(
        'SELECT COALESCE(MAX(CAST(SUBSTRING(%I FROM ''[0-9]+$'') AS INTEGER)), 0) + 1 
         FROM %I 
         WHERE %I LIKE %L',
        p_column, p_table, p_column, p_prefix || '-' || v_year || '-%'
    ) INTO v_sequence;
    
    v_result := p_prefix || '-' || v_year || '-' || LPAD(v_sequence::TEXT, 6, '0');
    RETURN v_result;
END;
$$ LANGUAGE plpgsql;

-- ---------------------------------------------
-- Function: Update Supplier Balance
-- ---------------------------------------------
CREATE OR REPLACE FUNCTION update_supplier_balance()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        -- For new supply with credit payment
        IF NEW.payment_method = 'credit' THEN
            UPDATE suppliers 
            SET current_balance = current_balance + NEW.total_amount,
                updated_at = CURRENT_TIMESTAMP
            WHERE id = NEW.supplier_id;
        END IF;
    ELSIF TG_OP = 'UPDATE' THEN
        -- Handle payment status changes
        IF OLD.paid_amount != NEW.paid_amount THEN
            UPDATE suppliers 
            SET current_balance = current_balance - (NEW.paid_amount - OLD.paid_amount),
                updated_at = CURRENT_TIMESTAMP
            WHERE id = NEW.supplier_id;
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_update_supplier_balance
    AFTER INSERT OR UPDATE ON supplies
    FOR EACH ROW EXECUTE FUNCTION update_supplier_balance();

-- ---------------------------------------------
-- Function: Update Supplier Balance on Return
-- ---------------------------------------------
CREATE OR REPLACE FUNCTION update_supplier_balance_on_return()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.status = 'approved' AND (OLD.status IS NULL OR OLD.status != 'approved') THEN
        UPDATE suppliers 
        SET current_balance = current_balance - NEW.total_amount,
            updated_at = CURRENT_TIMESTAMP
        WHERE id = NEW.supplier_id;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_update_supplier_balance_return
    AFTER UPDATE ON supplier_returns
    FOR EACH ROW EXECUTE FUNCTION update_supplier_balance_on_return();

-- ---------------------------------------------
-- Function: Update Inventory on Supply
-- ---------------------------------------------
CREATE OR REPLACE FUNCTION update_inventory_on_supply()
RETURNS TRIGGER AS $$
DECLARE
    v_inventory_id UUID;
BEGIN
    -- Get or create inventory record
    SELECT id INTO v_inventory_id
    FROM inventory
    WHERE branch_id = (SELECT branch_id FROM supplies WHERE id = NEW.supply_id)
      AND item_id = NEW.item_id;
    
    IF v_inventory_id IS NULL THEN
        INSERT INTO inventory (branch_id, item_id, quantity, min_quantity)
        SELECT branch_id, NEW.item_id, NEW.received_quantity, 
               COALESCE((SELECT min_stock_level FROM items WHERE id = NEW.item_id), 0)
        FROM supplies WHERE id = NEW.supply_id
        RETURNING id INTO v_inventory_id;
    ELSE
        UPDATE inventory 
        SET quantity = quantity + NEW.received_quantity,
            last_restock_date = CURRENT_TIMESTAMP,
            updated_at = CURRENT_TIMESTAMP
        WHERE id = v_inventory_id;
    END IF;
    
    -- Create batch if expiry date exists
    IF NEW.expiry_date IS NOT NULL THEN
        INSERT INTO inventory_batches (
            inventory_id, batch_number, quantity, remaining_quantity,
            purchase_price, production_date, expiry_date, supply_id
        ) VALUES (
            v_inventory_id, NEW.batch_number, NEW.received_quantity, NEW.received_quantity,
            NEW.unit_price, NEW.production_date, NEW.expiry_date, NEW.supply_id
        );
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_update_inventory_supply
    AFTER INSERT ON supply_items
    FOR EACH ROW EXECUTE FUNCTION update_inventory_on_supply();


-- ---------------------------------------------
-- Function: Update Inventory on Transfer
-- ---------------------------------------------
CREATE OR REPLACE FUNCTION update_inventory_on_transfer()
RETURNS TRIGGER AS $$
DECLARE
    v_from_inventory_id UUID;
    v_to_inventory_id UUID;
BEGIN
    -- Only process when transfer is received
    IF NEW.status = 'received' AND OLD.status != 'received' THEN
        -- Process each transfer item
        FOR v_from_inventory_id, v_to_inventory_id IN
            SELECT 
                (SELECT id FROM inventory WHERE branch_id = NEW.from_branch_id AND item_id = ti.item_id),
                (SELECT id FROM inventory WHERE branch_id = NEW.to_branch_id AND item_id = ti.item_id)
            FROM transfer_items ti
            WHERE ti.transfer_id = NEW.id
        LOOP
            -- Deduct from source
            UPDATE inventory 
            SET quantity = quantity - COALESCE(
                (SELECT received_quantity FROM transfer_items WHERE transfer_id = NEW.id AND item_id = inventory.item_id),
                0
            ),
            updated_at = CURRENT_TIMESTAMP
            WHERE id = v_from_inventory_id;
            
            -- Add to destination (create if not exists)
            IF v_to_inventory_id IS NULL THEN
                INSERT INTO inventory (branch_id, item_id, quantity)
                SELECT NEW.to_branch_id, ti.item_id, ti.received_quantity
                FROM transfer_items ti
                WHERE ti.transfer_id = NEW.id;
            ELSE
                UPDATE inventory 
                SET quantity = quantity + COALESCE(
                    (SELECT received_quantity FROM transfer_items WHERE transfer_id = NEW.id AND item_id = inventory.item_id),
                    0
                ),
                last_restock_date = CURRENT_TIMESTAMP,
                updated_at = CURRENT_TIMESTAMP
                WHERE id = v_to_inventory_id;
            END IF;
        END LOOP;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_update_inventory_transfer
    AFTER UPDATE ON transfers
    FOR EACH ROW EXECUTE FUNCTION update_inventory_on_transfer();

-- ---------------------------------------------
-- Function: Update Inventory on Damage Approval
-- ---------------------------------------------
CREATE OR REPLACE FUNCTION update_inventory_on_damage()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.status = 'approved' AND (OLD.status IS NULL OR OLD.status != 'approved') THEN
        -- Deduct from inventory
        UPDATE inventory 
        SET quantity = quantity - NEW.quantity,
            updated_at = CURRENT_TIMESTAMP
        WHERE branch_id = NEW.branch_id AND item_id = NEW.item_id;
        
        -- Update batch if specified
        IF NEW.batch_id IS NOT NULL THEN
            UPDATE inventory_batches
            SET remaining_quantity = remaining_quantity - NEW.quantity
            WHERE id = NEW.batch_id;
        END IF;
        
        -- Log the transaction
        INSERT INTO inventory_transactions (
            branch_id, item_id, operation_type, quantity,
            quantity_before, quantity_after, unit_cost,
            reference_type, reference_id, batch_id, created_by
        )
        SELECT 
            NEW.branch_id, NEW.item_id, 'damage', -NEW.quantity,
            i.quantity + NEW.quantity, i.quantity, NEW.unit_cost,
            'damage', NEW.id, NEW.batch_id, NEW.approved_by
        FROM inventory i
        WHERE i.branch_id = NEW.branch_id AND i.item_id = NEW.item_id;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_update_inventory_damage
    AFTER UPDATE ON damages
    FOR EACH ROW EXECUTE FUNCTION update_inventory_on_damage();

-- ---------------------------------------------
-- Function: Update Inventory on Return Approval
-- ---------------------------------------------
CREATE OR REPLACE FUNCTION update_inventory_on_return()
RETURNS TRIGGER AS $$
DECLARE
    v_branch_id UUID;
BEGIN
    IF NEW.status = 'approved' AND (OLD.status IS NULL OR OLD.status != 'approved') THEN
        -- Get branch from supply
        SELECT branch_id INTO v_branch_id FROM supplies WHERE id = NEW.supply_id;
        
        -- Deduct from inventory
        UPDATE inventory 
        SET quantity = quantity - NEW.quantity,
            updated_at = CURRENT_TIMESTAMP
        WHERE branch_id = v_branch_id AND item_id = NEW.item_id;
        
        -- Log the transaction
        INSERT INTO inventory_transactions (
            branch_id, item_id, operation_type, quantity,
            quantity_before, quantity_after, unit_cost,
            reference_type, reference_id, created_by
        )
        SELECT 
            v_branch_id, NEW.item_id, 'return', -NEW.quantity,
            i.quantity + NEW.quantity, i.quantity, NEW.unit_price,
            'supplier_return', NEW.id, NEW.approved_by
        FROM inventory i
        WHERE i.branch_id = v_branch_id AND i.item_id = NEW.item_id;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_update_inventory_return
    AFTER UPDATE ON supplier_returns
    FOR EACH ROW EXECUTE FUNCTION update_inventory_on_return();


-- ---------------------------------------------
-- Function: Check Low Stock and Create Alert
-- ---------------------------------------------
CREATE OR REPLACE FUNCTION check_low_stock_alert()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.quantity <= NEW.min_quantity AND 
       (OLD.quantity IS NULL OR OLD.quantity > OLD.min_quantity) THEN
        INSERT INTO notifications (
            branch_id, type, title, message, priority,
            reference_type, reference_id
        )
        SELECT 
            NEW.branch_id,
            'low_stock',
            'تنبيه نقص مخزون - ' || i.name,
            'الصنف ' || i.name || ' وصل للحد الأدنى. الكمية الحالية: ' || NEW.quantity,
            'high',
            'item',
            NEW.item_id
        FROM items i WHERE i.id = NEW.item_id;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_check_low_stock
    AFTER INSERT OR UPDATE ON inventory
    FOR EACH ROW EXECUTE FUNCTION check_low_stock_alert();

-- =============================================
-- INITIAL DATA (Seed Data)
-- =============================================

-- Insert default roles
INSERT INTO roles (name, name_ar, description, permissions, is_system_role) VALUES
('admin', 'مدير النظام', 'Full system access', '{"all": true}', TRUE),
('warehouse_manager', 'مدير المخزن', 'Warehouse and supplier management', 
 '{"suppliers": true, "inventory": true, "transfers": true, "damages": true, "returns": true, "reports": true}', TRUE),
('branch_supervisor', 'مشرف الفرع', 'Branch operations management',
 '{"branch_inventory": true, "daily_count": true, "transfer_request": true, "damage_register": true, "branch_reports": true}', TRUE),
('chef', 'طباخ', 'Kitchen operations',
 '{"kitchen_pos": true, "order_status": true}', TRUE),
('cashier', 'كاشير', 'POS and order management',
 '{"cashier_pos": true, "create_order": true, "payment": true}', TRUE);

-- Insert default units
INSERT INTO units (code, name, name_ar) VALUES
('KG', 'Kilogram', 'كيلوجرام'),
('G', 'Gram', 'جرام'),
('L', 'Liter', 'لتر'),
('ML', 'Milliliter', 'مللي لتر'),
('PC', 'Piece', 'قطعة'),
('BOX', 'Box', 'علبة'),
('PKT', 'Packet', 'باكت'),
('BTL', 'Bottle', 'زجاجة'),
('CAN', 'Can', 'علبة معدنية'),
('BAG', 'Bag', 'كيس'),
('CTN', 'Carton', 'كرتونة'),
('DOZ', 'Dozen', 'درزن');

-- Insert default damage reasons
INSERT INTO damage_reasons (code, name, name_ar, sort_order) VALUES
('EXPIRED', 'Expired', 'انتهاء الصلاحية', 1),
('STORAGE', 'Poor Storage', 'سوء التخزين', 2),
('TRANSPORT', 'Transport Damage', 'تلف أثناء النقل', 3),
('CONTAMINATION', 'Contamination', 'تلوث أو حشرات', 4),
('MOISTURE', 'Moisture/Leak', 'تسرب أو رطوبة', 5),
('HEAT', 'Heat/Fire', 'حريق أو حرارة', 6),
('OTHER', 'Other', 'أخرى', 99);

-- Insert main warehouse as default branch
INSERT INTO branches (code, name, name_ar, is_main_warehouse, status) VALUES
('MAIN', 'Main Warehouse', 'المخزن الرئيسي', TRUE, 'active');

-- Insert default system settings
INSERT INTO system_settings (key, value, value_type, description) VALUES
('company_name', 'Restaurant Name', 'string', 'اسم المطعم'),
('company_name_ar', 'اسم المطعم', 'string', 'اسم المطعم بالعربي'),
('currency', 'EGP', 'string', 'العملة'),
('tax_rate', '14', 'number', 'نسبة الضريبة'),
('low_stock_threshold_days', '7', 'number', 'عدد أيام التنبيه قبل نفاد المخزون'),
('expiry_warning_days', '30', 'number', 'عدد أيام التنبيه قبل انتهاء الصلاحية'),
('session_timeout_minutes', '30', 'number', 'مدة انتهاء الجلسة بالدقائق'),
('max_login_attempts', '5', 'number', 'الحد الأقصى لمحاولات تسجيل الدخول'),
('order_number_prefix', 'ORD', 'string', 'بادئة رقم الأوردر'),
('supply_number_prefix', 'SUP', 'string', 'بادئة رقم التوريد'),
('transfer_number_prefix', 'TRF', 'string', 'بادئة رقم التحويل'),
('damage_number_prefix', 'DMG', 'string', 'بادئة رقم التالف'),
('return_number_prefix', 'RET', 'string', 'بادئة رقم المرتجع');


-- =============================================
-- INDEXES FOR PERFORMANCE
-- =============================================

-- Composite indexes for common queries
CREATE INDEX idx_inventory_branch_item_qty ON inventory(branch_id, item_id, quantity);
CREATE INDEX idx_supplies_supplier_date ON supplies(supplier_id, received_at DESC);
CREATE INDEX idx_orders_branch_date_status ON orders(branch_id, created_at DESC, status);
CREATE INDEX idx_inv_trans_branch_item_date ON inventory_transactions(branch_id, item_id, created_at DESC);

-- Partial indexes for active records
CREATE INDEX idx_items_active ON items(id) WHERE status = 'active';
CREATE INDEX idx_suppliers_active ON suppliers(id) WHERE status = 'active';
CREATE INDEX idx_users_active ON users(id) WHERE status = 'active';

-- Full text search indexes (if needed)
CREATE INDEX idx_items_name_search ON items USING gin(to_tsvector('arabic', name_ar));
CREATE INDEX idx_suppliers_name_search ON suppliers USING gin(to_tsvector('arabic', COALESCE(name_ar, name)));

-- =============================================
-- GRANTS & PERMISSIONS (Example)
-- =============================================

-- Create application role
-- CREATE ROLE restaurant_app WITH LOGIN PASSWORD 'secure_password';

-- Grant permissions
-- GRANT USAGE ON SCHEMA public TO restaurant_app;
-- GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO restaurant_app;
-- GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO restaurant_app;
-- GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO restaurant_app;

-- =============================================
-- COMMENTS FOR DOCUMENTATION
-- =============================================

COMMENT ON TABLE roles IS 'أدوار المستخدمين وصلاحياتهم';
COMMENT ON TABLE users IS 'بيانات المستخدمين';
COMMENT ON TABLE branches IS 'الفروع والمخزن الرئيسي';
COMMENT ON TABLE categories IS 'فئات الأصناف';
COMMENT ON TABLE items IS 'الأصناف في المخزون';
COMMENT ON TABLE suppliers IS 'بيانات الموردين';
COMMENT ON TABLE supplier_items IS 'ربط الموردين بالأصناف';
COMMENT ON TABLE inventory IS 'المخزون الحالي لكل فرع';
COMMENT ON TABLE inventory_batches IS 'دفعات المخزون لتتبع الصلاحية';
COMMENT ON TABLE supplies IS 'التوريدات من الموردين';
COMMENT ON TABLE supply_items IS 'تفاصيل التوريدات';
COMMENT ON TABLE supplier_payments IS 'مدفوعات الموردين';
COMMENT ON TABLE transfers IS 'تحويلات المخزون بين الفروع';
COMMENT ON TABLE transfer_items IS 'تفاصيل التحويلات';
COMMENT ON TABLE damage_reasons IS 'أسباب التلف';
COMMENT ON TABLE damages IS 'سجل التالف';
COMMENT ON TABLE supplier_returns IS 'مرتجعات الموردين';
COMMENT ON TABLE menu_categories IS 'فئات المنيو';
COMMENT ON TABLE menu_items IS 'أصناف المنيو للبيع';
COMMENT ON TABLE menu_item_ingredients IS 'مكونات أصناف المنيو';
COMMENT ON TABLE orders IS 'الأوردرات';
COMMENT ON TABLE order_items IS 'تفاصيل الأوردرات';
COMMENT ON TABLE inventory_transactions IS 'سجل حركات المخزون';
COMMENT ON TABLE daily_inventory_counts IS 'الجرد اليومي';
COMMENT ON TABLE daily_inventory_count_items IS 'تفاصيل الجرد اليومي';
COMMENT ON TABLE notifications IS 'الإشعارات';
COMMENT ON TABLE alert_settings IS 'إعدادات التنبيهات';
COMMENT ON TABLE audit_logs IS 'سجل المراجعة';
COMMENT ON TABLE user_sessions IS 'جلسات المستخدمين';
COMMENT ON TABLE system_settings IS 'إعدادات النظام';
COMMENT ON TABLE branch_settings IS 'إعدادات الفروع';

-- =============================================
-- END OF SCHEMA
-- =============================================
