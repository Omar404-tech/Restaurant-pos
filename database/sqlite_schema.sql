-- =============================================
-- Restaurant Management System Database Schema
-- SQLite Version (PostgreSQL Compatible)
-- =============================================

-- Enable foreign keys
PRAGMA foreign_keys = ON;

-- =============================================
-- LOOKUP TABLES (بدل ENUMs)
-- =============================================

-- ---------------------------------------------
-- User Status Lookup
-- ---------------------------------------------
CREATE TABLE IF NOT EXISTS lookup_user_status (
    id INTEGER PRIMARY KEY,
    code TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL,
    name_ar TEXT NOT NULL
);

INSERT INTO lookup_user_status (id, code, name, name_ar) VALUES
(1, 'active', 'Active', 'نشط'),
(2, 'inactive', 'Inactive', 'غير نشط'),
(3, 'suspended', 'Suspended', 'موقوف');

-- ---------------------------------------------
-- Supplier Status Lookup
-- ---------------------------------------------
CREATE TABLE IF NOT EXISTS lookup_supplier_status (
    id INTEGER PRIMARY KEY,
    code TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL,
    name_ar TEXT NOT NULL
);

INSERT INTO lookup_supplier_status (id, code, name, name_ar) VALUES
(1, 'active', 'Active', 'نشط'),
(2, 'inactive', 'Inactive', 'غير نشط');

-- ---------------------------------------------
-- Payment Method Lookup (Suppliers)
-- ---------------------------------------------
CREATE TABLE IF NOT EXISTS lookup_supplier_payment_method (
    id INTEGER PRIMARY KEY,
    code TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL,
    name_ar TEXT NOT NULL
);

INSERT INTO lookup_supplier_payment_method (id, code, name, name_ar) VALUES
(1, 'cash', 'Cash', 'كاش'),
(2, 'credit', 'Credit', 'آجل');


-- ---------------------------------------------
-- Payment Status Lookup
-- ---------------------------------------------
CREATE TABLE IF NOT EXISTS lookup_payment_status (
    id INTEGER PRIMARY KEY,
    code TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL,
    name_ar TEXT NOT NULL
);

INSERT INTO lookup_payment_status (id, code, name, name_ar) VALUES
(1, 'paid', 'Paid', 'مدفوع'),
(2, 'pending', 'Pending', 'معلق'),
(3, 'partial', 'Partial', 'جزئي');

-- ---------------------------------------------
-- Transfer Status Lookup
-- ---------------------------------------------
CREATE TABLE IF NOT EXISTS lookup_transfer_status (
    id INTEGER PRIMARY KEY,
    code TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL,
    name_ar TEXT NOT NULL
);

INSERT INTO lookup_transfer_status (id, code, name, name_ar) VALUES
(1, 'pending', 'Pending', 'معلق'),
(2, 'approved', 'Approved', 'موافق عليه'),
(3, 'rejected', 'Rejected', 'مرفوض'),
(4, 'received', 'Received', 'مستلم'),
(5, 'cancelled', 'Cancelled', 'ملغي');

-- ---------------------------------------------
-- Damage Status Lookup
-- ---------------------------------------------
CREATE TABLE IF NOT EXISTS lookup_damage_status (
    id INTEGER PRIMARY KEY,
    code TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL,
    name_ar TEXT NOT NULL
);

INSERT INTO lookup_damage_status (id, code, name, name_ar) VALUES
(1, 'pending', 'Pending', 'معلق'),
(2, 'approved', 'Approved', 'موافق عليه'),
(3, 'rejected', 'Rejected', 'مرفوض');

-- ---------------------------------------------
-- Return Status Lookup
-- ---------------------------------------------
CREATE TABLE IF NOT EXISTS lookup_return_status (
    id INTEGER PRIMARY KEY,
    code TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL,
    name_ar TEXT NOT NULL
);

INSERT INTO lookup_return_status (id, code, name, name_ar) VALUES
(1, 'pending', 'Pending', 'معلق'),
(2, 'approved', 'Approved', 'موافق عليه'),
(3, 'rejected', 'Rejected', 'مرفوض'),
(4, 'received', 'Received', 'مستلم');

-- ---------------------------------------------
-- Order Status Lookup
-- ---------------------------------------------
CREATE TABLE IF NOT EXISTS lookup_order_status (
    id INTEGER PRIMARY KEY,
    code TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL,
    name_ar TEXT NOT NULL
);

INSERT INTO lookup_order_status (id, code, name, name_ar) VALUES
(1, 'new', 'New', 'جديد'),
(2, 'pending_payment', 'Pending Payment', 'في انتظار الدفع'),
(3, 'paid', 'Paid', 'مدفوع'),
(4, 'in_kitchen', 'In Kitchen', 'في المطبخ'),
(5, 'preparing', 'Preparing', 'قيد التحضير'),
(6, 'ready', 'Ready', 'جاهز'),
(7, 'delivered', 'Delivered', 'تم التسليم'),
(8, 'cancelled', 'Cancelled', 'ملغي');

-- ---------------------------------------------
-- Order Payment Method Lookup
-- ---------------------------------------------
CREATE TABLE IF NOT EXISTS lookup_order_payment_method (
    id INTEGER PRIMARY KEY,
    code TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL,
    name_ar TEXT NOT NULL
);

INSERT INTO lookup_order_payment_method (id, code, name, name_ar) VALUES
(1, 'cash', 'Cash', 'كاش'),
(2, 'visa', 'Visa/Card', 'فيزا'),
(3, 'instapay', 'InstaPay', 'إنستا باي'),
(4, 'wallet', 'E-Wallet', 'محفظة إلكترونية');


-- ---------------------------------------------
-- Inventory Operation Type Lookup
-- ---------------------------------------------
CREATE TABLE IF NOT EXISTS lookup_inventory_operation (
    id INTEGER PRIMARY KEY,
    code TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL,
    name_ar TEXT NOT NULL
);

INSERT INTO lookup_inventory_operation (id, code, name, name_ar) VALUES
(1, 'supply', 'Supply', 'توريد'),
(2, 'transfer_out', 'Transfer Out', 'تحويل صادر'),
(3, 'transfer_in', 'Transfer In', 'تحويل وارد'),
(4, 'consumption', 'Consumption', 'استهلاك'),
(5, 'damage', 'Damage', 'تالف'),
(6, 'return', 'Return', 'مرتجع'),
(7, 'adjustment', 'Adjustment', 'تسوية');

-- ---------------------------------------------
-- Branch Status Lookup
-- ---------------------------------------------
CREATE TABLE IF NOT EXISTS lookup_branch_status (
    id INTEGER PRIMARY KEY,
    code TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL,
    name_ar TEXT NOT NULL
);

INSERT INTO lookup_branch_status (id, code, name, name_ar) VALUES
(1, 'active', 'Active', 'نشط'),
(2, 'inactive', 'Inactive', 'غير نشط'),
(3, 'maintenance', 'Maintenance', 'صيانة');

-- ---------------------------------------------
-- Item Status Lookup
-- ---------------------------------------------
CREATE TABLE IF NOT EXISTS lookup_item_status (
    id INTEGER PRIMARY KEY,
    code TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL,
    name_ar TEXT NOT NULL
);

INSERT INTO lookup_item_status (id, code, name, name_ar) VALUES
(1, 'active', 'Active', 'نشط'),
(2, 'inactive', 'Inactive', 'غير نشط');

-- =============================================
-- CORE TABLES
-- =============================================

-- ---------------------------------------------
-- 1. ROLES (الأدوار)
-- ---------------------------------------------
CREATE TABLE IF NOT EXISTS roles (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL UNIQUE,
    name_ar TEXT NOT NULL,
    description TEXT,
    permissions TEXT DEFAULT '{}', -- JSON stored as TEXT
    is_system_role INTEGER DEFAULT 0,
    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_roles_name ON roles(name);

-- ---------------------------------------------
-- 2. BRANCHES (الفروع)
-- ---------------------------------------------
CREATE TABLE IF NOT EXISTS branches (
    id TEXT PRIMARY KEY,
    code TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL,
    name_ar TEXT NOT NULL,
    address TEXT,
    phone TEXT,
    email TEXT,
    status_id INTEGER DEFAULT 1 REFERENCES lookup_branch_status(id),
    is_main_warehouse INTEGER DEFAULT 0,
    opening_time TEXT,
    closing_time TEXT,
    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_branches_status ON branches(status_id);
CREATE INDEX IF NOT EXISTS idx_branches_is_main ON branches(is_main_warehouse);


-- ---------------------------------------------
-- 3. USERS (المستخدمين)
-- ---------------------------------------------
CREATE TABLE IF NOT EXISTS users (
    id TEXT PRIMARY KEY,
    employee_code TEXT NOT NULL UNIQUE,
    username TEXT NOT NULL UNIQUE,
    email TEXT NOT NULL UNIQUE,
    password_hash TEXT NOT NULL,
    full_name TEXT NOT NULL,
    full_name_ar TEXT,
    phone TEXT,
    role_id TEXT NOT NULL REFERENCES roles(id) ON DELETE RESTRICT,
    branch_id TEXT REFERENCES branches(id) ON DELETE SET NULL,
    status_id INTEGER DEFAULT 1 REFERENCES lookup_user_status(id),
    last_login TEXT,
    password_changed_at TEXT,
    failed_login_attempts INTEGER DEFAULT 0,
    locked_until TEXT,
    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now')),
    created_by TEXT REFERENCES users(id)
);

CREATE INDEX IF NOT EXISTS idx_users_role ON users(role_id);
CREATE INDEX IF NOT EXISTS idx_users_branch ON users(branch_id);
CREATE INDEX IF NOT EXISTS idx_users_status ON users(status_id);
CREATE INDEX IF NOT EXISTS idx_users_username ON users(username);
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);

-- ---------------------------------------------
-- 4. CATEGORIES (فئات الأصناف)
-- ---------------------------------------------
CREATE TABLE IF NOT EXISTS categories (
    id TEXT PRIMARY KEY,
    code TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL,
    name_ar TEXT NOT NULL,
    description TEXT,
    parent_id TEXT REFERENCES categories(id) ON DELETE SET NULL,
    sort_order INTEGER DEFAULT 0,
    is_active INTEGER DEFAULT 1,
    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_categories_parent ON categories(parent_id);
CREATE INDEX IF NOT EXISTS idx_categories_active ON categories(is_active);

-- ---------------------------------------------
-- 5. UNITS (وحدات القياس)
-- ---------------------------------------------
CREATE TABLE IF NOT EXISTS units (
    id TEXT PRIMARY KEY,
    code TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL,
    name_ar TEXT NOT NULL,
    is_active INTEGER DEFAULT 1,
    created_at TEXT DEFAULT (datetime('now'))
);

-- ---------------------------------------------
-- 6. ITEMS (الأصناف)
-- ---------------------------------------------
CREATE TABLE IF NOT EXISTS items (
    id TEXT PRIMARY KEY,
    code TEXT NOT NULL UNIQUE,
    barcode TEXT UNIQUE,
    name TEXT NOT NULL,
    name_ar TEXT NOT NULL,
    description TEXT,
    category_id TEXT REFERENCES categories(id) ON DELETE SET NULL,
    unit_id TEXT NOT NULL REFERENCES units(id) ON DELETE RESTRICT,
    purchase_price REAL DEFAULT 0,
    selling_price REAL DEFAULT 0,
    min_stock_level REAL DEFAULT 0,
    max_stock_level REAL,
    reorder_level REAL,
    is_perishable INTEGER DEFAULT 0,
    shelf_life_days INTEGER,
    storage_conditions TEXT,
    status_id INTEGER DEFAULT 1 REFERENCES lookup_item_status(id),
    image_url TEXT,
    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now')),
    created_by TEXT REFERENCES users(id),
    
    CHECK (purchase_price >= 0),
    CHECK (selling_price >= 0),
    CHECK (min_stock_level >= 0)
);

CREATE INDEX IF NOT EXISTS idx_items_category ON items(category_id);
CREATE INDEX IF NOT EXISTS idx_items_status ON items(status_id);
CREATE INDEX IF NOT EXISTS idx_items_code ON items(code);
CREATE INDEX IF NOT EXISTS idx_items_barcode ON items(barcode);


-- ---------------------------------------------
-- 7. SUPPLIERS (الموردين)
-- ---------------------------------------------
CREATE TABLE IF NOT EXISTS suppliers (
    id TEXT PRIMARY KEY,
    code TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL,
    name_ar TEXT,
    contact_person TEXT,
    phone TEXT NOT NULL,
    phone_alt TEXT,
    email TEXT,
    address TEXT,
    city TEXT,
    tax_number TEXT,
    commercial_register TEXT,
    payment_terms_id INTEGER DEFAULT 1 REFERENCES lookup_supplier_payment_method(id),
    credit_limit REAL DEFAULT 0,
    credit_period_days INTEGER DEFAULT 0,
    current_balance REAL DEFAULT 0,
    status_id INTEGER DEFAULT 1 REFERENCES lookup_supplier_status(id),
    notes TEXT,
    rating INTEGER CHECK (rating >= 1 AND rating <= 5),
    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now')),
    created_by TEXT REFERENCES users(id),
    
    CHECK (current_balance >= 0),
    CHECK (credit_limit >= 0)
);

CREATE INDEX IF NOT EXISTS idx_suppliers_status ON suppliers(status_id);
CREATE INDEX IF NOT EXISTS idx_suppliers_code ON suppliers(code);

-- ---------------------------------------------
-- 8. SUPPLIER_ITEMS (أصناف الموردين)
-- ---------------------------------------------
CREATE TABLE IF NOT EXISTS supplier_items (
    id TEXT PRIMARY KEY,
    supplier_id TEXT NOT NULL REFERENCES suppliers(id) ON DELETE CASCADE,
    item_id TEXT NOT NULL REFERENCES items(id) ON DELETE CASCADE,
    supplier_item_code TEXT,
    unit_price REAL,
    min_order_quantity REAL,
    lead_time_days INTEGER,
    is_preferred INTEGER DEFAULT 0,
    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now')),
    
    UNIQUE (supplier_id, item_id)
);

CREATE INDEX IF NOT EXISTS idx_supplier_items_supplier ON supplier_items(supplier_id);
CREATE INDEX IF NOT EXISTS idx_supplier_items_item ON supplier_items(item_id);

-- =============================================
-- INVENTORY TABLES
-- =============================================

-- ---------------------------------------------
-- 9. INVENTORY (المخزون)
-- ---------------------------------------------
CREATE TABLE IF NOT EXISTS inventory (
    id TEXT PRIMARY KEY,
    branch_id TEXT NOT NULL REFERENCES branches(id) ON DELETE RESTRICT,
    item_id TEXT NOT NULL REFERENCES items(id) ON DELETE RESTRICT,
    quantity REAL NOT NULL DEFAULT 0,
    reserved_quantity REAL DEFAULT 0,
    min_quantity REAL DEFAULT 0,
    last_restock_date TEXT,
    last_count_date TEXT,
    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now')),
    
    UNIQUE (branch_id, item_id),
    CHECK (quantity >= 0),
    CHECK (reserved_quantity >= 0),
    CHECK (reserved_quantity <= quantity)
);

CREATE INDEX IF NOT EXISTS idx_inventory_branch ON inventory(branch_id);
CREATE INDEX IF NOT EXISTS idx_inventory_item ON inventory(item_id);

-- ---------------------------------------------
-- 10. INVENTORY_BATCHES (دفعات المخزون)
-- ---------------------------------------------
CREATE TABLE IF NOT EXISTS inventory_batches (
    id TEXT PRIMARY KEY,
    inventory_id TEXT NOT NULL REFERENCES inventory(id) ON DELETE CASCADE,
    batch_number TEXT,
    quantity REAL NOT NULL,
    remaining_quantity REAL NOT NULL,
    purchase_price REAL,
    production_date TEXT,
    expiry_date TEXT,
    received_date TEXT NOT NULL DEFAULT (date('now')),
    supply_id TEXT,
    created_at TEXT DEFAULT (datetime('now')),
    
    CHECK (quantity > 0),
    CHECK (remaining_quantity >= 0),
    CHECK (remaining_quantity <= quantity)
);

CREATE INDEX IF NOT EXISTS idx_batches_inventory ON inventory_batches(inventory_id);
CREATE INDEX IF NOT EXISTS idx_batches_expiry ON inventory_batches(expiry_date);


-- =============================================
-- SUPPLY TABLES (التوريدات)
-- =============================================

-- ---------------------------------------------
-- 11. SUPPLIES (التوريدات)
-- ---------------------------------------------
CREATE TABLE IF NOT EXISTS supplies (
    id TEXT PRIMARY KEY,
    supply_number TEXT NOT NULL UNIQUE,
    supplier_id TEXT NOT NULL REFERENCES suppliers(id) ON DELETE RESTRICT,
    branch_id TEXT NOT NULL REFERENCES branches(id) ON DELETE RESTRICT,
    invoice_number TEXT,
    invoice_date TEXT,
    subtotal REAL NOT NULL DEFAULT 0,
    tax_amount REAL DEFAULT 0,
    discount_amount REAL DEFAULT 0,
    total_amount REAL NOT NULL DEFAULT 0,
    payment_method_id INTEGER NOT NULL REFERENCES lookup_supplier_payment_method(id),
    payment_status_id INTEGER DEFAULT 2 REFERENCES lookup_payment_status(id),
    paid_amount REAL DEFAULT 0,
    due_date TEXT,
    notes TEXT,
    received_by TEXT NOT NULL REFERENCES users(id),
    received_at TEXT DEFAULT (datetime('now')),
    approved_by TEXT REFERENCES users(id),
    approved_at TEXT,
    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now')),
    
    CHECK (subtotal >= 0),
    CHECK (tax_amount >= 0),
    CHECK (discount_amount >= 0),
    CHECK (total_amount >= 0),
    CHECK (paid_amount >= 0),
    CHECK (paid_amount <= total_amount)
);

CREATE INDEX IF NOT EXISTS idx_supplies_supplier ON supplies(supplier_id);
CREATE INDEX IF NOT EXISTS idx_supplies_branch ON supplies(branch_id);
CREATE INDEX IF NOT EXISTS idx_supplies_date ON supplies(received_at);
CREATE INDEX IF NOT EXISTS idx_supplies_payment_status ON supplies(payment_status_id);

-- ---------------------------------------------
-- 12. SUPPLY_ITEMS (تفاصيل التوريدات)
-- ---------------------------------------------
CREATE TABLE IF NOT EXISTS supply_items (
    id TEXT PRIMARY KEY,
    supply_id TEXT NOT NULL REFERENCES supplies(id) ON DELETE CASCADE,
    item_id TEXT NOT NULL REFERENCES items(id) ON DELETE RESTRICT,
    quantity REAL NOT NULL,
    received_quantity REAL NOT NULL,
    unit_price REAL NOT NULL,
    discount_percent REAL DEFAULT 0,
    tax_percent REAL DEFAULT 0,
    total_price REAL NOT NULL,
    batch_number TEXT,
    production_date TEXT,
    expiry_date TEXT,
    notes TEXT,
    created_at TEXT DEFAULT (datetime('now')),
    
    CHECK (quantity > 0),
    CHECK (received_quantity >= 0),
    CHECK (unit_price >= 0),
    CHECK (total_price >= 0),
    CHECK (discount_percent >= 0 AND discount_percent <= 100)
);

CREATE INDEX IF NOT EXISTS idx_supply_items_supply ON supply_items(supply_id);
CREATE INDEX IF NOT EXISTS idx_supply_items_item ON supply_items(item_id);

-- Add FK to inventory_batches after supplies table exists
-- (SQLite doesn't support ALTER TABLE ADD CONSTRAINT, so we handle this in app logic)

-- ---------------------------------------------
-- 13. SUPPLIER_PAYMENTS (مدفوعات الموردين)
-- ---------------------------------------------
CREATE TABLE IF NOT EXISTS supplier_payments (
    id TEXT PRIMARY KEY,
    payment_number TEXT NOT NULL UNIQUE,
    supplier_id TEXT NOT NULL REFERENCES suppliers(id) ON DELETE RESTRICT,
    supply_id TEXT REFERENCES supplies(id) ON DELETE SET NULL,
    amount REAL NOT NULL,
    payment_method TEXT NOT NULL,
    reference_number TEXT,
    bank_name TEXT,
    payment_date TEXT NOT NULL DEFAULT (date('now')),
    notes TEXT,
    created_by TEXT NOT NULL REFERENCES users(id),
    created_at TEXT DEFAULT (datetime('now')),
    
    CHECK (amount > 0)
);

CREATE INDEX IF NOT EXISTS idx_supplier_payments_supplier ON supplier_payments(supplier_id);
CREATE INDEX IF NOT EXISTS idx_supplier_payments_supply ON supplier_payments(supply_id);
CREATE INDEX IF NOT EXISTS idx_supplier_payments_date ON supplier_payments(payment_date);


-- =============================================
-- TRANSFER TABLES (التحويلات)
-- =============================================

-- ---------------------------------------------
-- 14. TRANSFERS (تحويلات المخزون)
-- ---------------------------------------------
CREATE TABLE IF NOT EXISTS transfers (
    id TEXT PRIMARY KEY,
    transfer_number TEXT NOT NULL UNIQUE,
    from_branch_id TEXT NOT NULL REFERENCES branches(id) ON DELETE RESTRICT,
    to_branch_id TEXT NOT NULL REFERENCES branches(id) ON DELETE RESTRICT,
    status_id INTEGER DEFAULT 1 REFERENCES lookup_transfer_status(id),
    priority INTEGER DEFAULT 0,
    notes TEXT,
    requested_by TEXT NOT NULL REFERENCES users(id),
    requested_at TEXT DEFAULT (datetime('now')),
    approved_by TEXT REFERENCES users(id),
    approved_at TEXT,
    rejected_by TEXT REFERENCES users(id),
    rejected_at TEXT,
    rejection_reason TEXT,
    shipped_at TEXT,
    received_by TEXT REFERENCES users(id),
    received_at TEXT,
    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now')),
    
    CHECK (from_branch_id != to_branch_id)
);

CREATE INDEX IF NOT EXISTS idx_transfers_from_branch ON transfers(from_branch_id);
CREATE INDEX IF NOT EXISTS idx_transfers_to_branch ON transfers(to_branch_id);
CREATE INDEX IF NOT EXISTS idx_transfers_status ON transfers(status_id);
CREATE INDEX IF NOT EXISTS idx_transfers_date ON transfers(requested_at);

-- ---------------------------------------------
-- 15. TRANSFER_ITEMS (تفاصيل التحويلات)
-- ---------------------------------------------
CREATE TABLE IF NOT EXISTS transfer_items (
    id TEXT PRIMARY KEY,
    transfer_id TEXT NOT NULL REFERENCES transfers(id) ON DELETE CASCADE,
    item_id TEXT NOT NULL REFERENCES items(id) ON DELETE RESTRICT,
    requested_quantity REAL NOT NULL,
    approved_quantity REAL,
    shipped_quantity REAL,
    received_quantity REAL,
    notes TEXT,
    created_at TEXT DEFAULT (datetime('now')),
    
    CHECK (requested_quantity > 0)
);

CREATE INDEX IF NOT EXISTS idx_transfer_items_transfer ON transfer_items(transfer_id);
CREATE INDEX IF NOT EXISTS idx_transfer_items_item ON transfer_items(item_id);

-- =============================================
-- DAMAGE TABLES (التالف)
-- =============================================

-- ---------------------------------------------
-- 16. DAMAGE_REASONS (أسباب التلف)
-- ---------------------------------------------
CREATE TABLE IF NOT EXISTS damage_reasons (
    id TEXT PRIMARY KEY,
    code TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL,
    name_ar TEXT NOT NULL,
    description TEXT,
    is_active INTEGER DEFAULT 1,
    sort_order INTEGER DEFAULT 0,
    created_at TEXT DEFAULT (datetime('now'))
);

-- ---------------------------------------------
-- 17. DAMAGES (التالف)
-- ---------------------------------------------
CREATE TABLE IF NOT EXISTS damages (
    id TEXT PRIMARY KEY,
    damage_number TEXT NOT NULL UNIQUE,
    branch_id TEXT NOT NULL REFERENCES branches(id) ON DELETE RESTRICT,
    item_id TEXT NOT NULL REFERENCES items(id) ON DELETE RESTRICT,
    quantity REAL NOT NULL,
    unit_cost REAL,
    total_cost REAL,
    reason_id TEXT NOT NULL REFERENCES damage_reasons(id) ON DELETE RESTRICT,
    description TEXT,
    image_url TEXT,
    batch_id TEXT REFERENCES inventory_batches(id) ON DELETE SET NULL,
    status_id INTEGER DEFAULT 1 REFERENCES lookup_damage_status(id),
    registered_by TEXT NOT NULL REFERENCES users(id),
    registered_at TEXT DEFAULT (datetime('now')),
    approved_by TEXT REFERENCES users(id),
    approved_at TEXT,
    rejected_by TEXT REFERENCES users(id),
    rejected_at TEXT,
    rejection_reason TEXT,
    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now')),
    
    CHECK (quantity > 0)
);

CREATE INDEX IF NOT EXISTS idx_damages_branch ON damages(branch_id);
CREATE INDEX IF NOT EXISTS idx_damages_item ON damages(item_id);
CREATE INDEX IF NOT EXISTS idx_damages_status ON damages(status_id);
CREATE INDEX IF NOT EXISTS idx_damages_reason ON damages(reason_id);
CREATE INDEX IF NOT EXISTS idx_damages_date ON damages(registered_at);


-- =============================================
-- SUPPLIER RETURNS (مرتجعات الموردين)
-- =============================================

-- ---------------------------------------------
-- 18. SUPPLIER_RETURNS (مرتجعات الموردين)
-- ---------------------------------------------
CREATE TABLE IF NOT EXISTS supplier_returns (
    id TEXT PRIMARY KEY,
    return_number TEXT NOT NULL UNIQUE,
    supply_id TEXT NOT NULL REFERENCES supplies(id) ON DELETE RESTRICT,
    supplier_id TEXT NOT NULL REFERENCES suppliers(id) ON DELETE RESTRICT,
    item_id TEXT NOT NULL REFERENCES items(id) ON DELETE RESTRICT,
    quantity REAL NOT NULL,
    unit_price REAL NOT NULL,
    total_amount REAL NOT NULL,
    reason TEXT NOT NULL,
    description TEXT,
    image_url TEXT,
    status_id INTEGER DEFAULT 1 REFERENCES lookup_return_status(id),
    registered_by TEXT NOT NULL REFERENCES users(id),
    registered_at TEXT DEFAULT (datetime('now')),
    approved_by TEXT REFERENCES users(id),
    approved_at TEXT,
    rejected_by TEXT REFERENCES users(id),
    rejected_at TEXT,
    rejection_reason TEXT,
    received_by_supplier_at TEXT,
    credit_note_number TEXT,
    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now')),
    
    CHECK (quantity > 0),
    CHECK (total_amount >= 0)
);

CREATE INDEX IF NOT EXISTS idx_returns_supply ON supplier_returns(supply_id);
CREATE INDEX IF NOT EXISTS idx_returns_supplier ON supplier_returns(supplier_id);
CREATE INDEX IF NOT EXISTS idx_returns_status ON supplier_returns(status_id);
CREATE INDEX IF NOT EXISTS idx_returns_date ON supplier_returns(registered_at);

-- =============================================
-- ORDER TABLES (الأوردرات)
-- =============================================

-- ---------------------------------------------
-- 19. MENU_CATEGORIES (فئات المنيو)
-- ---------------------------------------------
CREATE TABLE IF NOT EXISTS menu_categories (
    id TEXT PRIMARY KEY,
    code TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL,
    name_ar TEXT NOT NULL,
    description TEXT,
    image_url TEXT,
    parent_id TEXT REFERENCES menu_categories(id) ON DELETE SET NULL,
    sort_order INTEGER DEFAULT 0,
    is_active INTEGER DEFAULT 1,
    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_menu_categories_parent ON menu_categories(parent_id);
CREATE INDEX IF NOT EXISTS idx_menu_categories_active ON menu_categories(is_active);

-- ---------------------------------------------
-- 20. MENU_ITEMS (أصناف المنيو)
-- ---------------------------------------------
CREATE TABLE IF NOT EXISTS menu_items (
    id TEXT PRIMARY KEY,
    code TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL,
    name_ar TEXT NOT NULL,
    description TEXT,
    description_ar TEXT,
    category_id TEXT REFERENCES menu_categories(id) ON DELETE SET NULL,
    price REAL NOT NULL,
    cost REAL DEFAULT 0,
    tax_percent REAL DEFAULT 0,
    image_url TEXT,
    preparation_time_minutes INTEGER,
    calories INTEGER,
    is_available INTEGER DEFAULT 1,
    is_active INTEGER DEFAULT 1,
    sort_order INTEGER DEFAULT 0,
    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now')),
    
    CHECK (price >= 0),
    CHECK (cost >= 0)
);

CREATE INDEX IF NOT EXISTS idx_menu_items_category ON menu_items(category_id);
CREATE INDEX IF NOT EXISTS idx_menu_items_available ON menu_items(is_available, is_active);

-- ---------------------------------------------
-- 21. MENU_ITEM_INGREDIENTS (مكونات المنتج)
-- ---------------------------------------------
CREATE TABLE IF NOT EXISTS menu_item_ingredients (
    id TEXT PRIMARY KEY,
    menu_item_id TEXT NOT NULL REFERENCES menu_items(id) ON DELETE CASCADE,
    item_id TEXT NOT NULL REFERENCES items(id) ON DELETE RESTRICT,
    quantity REAL NOT NULL,
    unit_id TEXT NOT NULL REFERENCES units(id) ON DELETE RESTRICT,
    is_optional INTEGER DEFAULT 0,
    created_at TEXT DEFAULT (datetime('now')),
    
    UNIQUE (menu_item_id, item_id),
    CHECK (quantity > 0)
);

CREATE INDEX IF NOT EXISTS idx_menu_ingredients_menu ON menu_item_ingredients(menu_item_id);
CREATE INDEX IF NOT EXISTS idx_menu_ingredients_item ON menu_item_ingredients(item_id);


-- ---------------------------------------------
-- 22. ORDERS (الأوردرات)
-- ---------------------------------------------
CREATE TABLE IF NOT EXISTS orders (
    id TEXT PRIMARY KEY,
    order_number TEXT NOT NULL UNIQUE,
    branch_id TEXT NOT NULL REFERENCES branches(id) ON DELETE RESTRICT,
    order_type TEXT DEFAULT 'takeaway',
    customer_name TEXT,
    customer_phone TEXT,
    subtotal REAL NOT NULL DEFAULT 0,
    tax_amount REAL DEFAULT 0,
    discount_amount REAL DEFAULT 0,
    discount_reason TEXT,
    total_amount REAL NOT NULL DEFAULT 0,
    payment_method_id INTEGER REFERENCES lookup_order_payment_method(id),
    payment_reference TEXT,
    status_id INTEGER DEFAULT 1 REFERENCES lookup_order_status(id),
    notes TEXT,
    kitchen_notes TEXT,
    cashier_id TEXT NOT NULL REFERENCES users(id),
    chef_id TEXT REFERENCES users(id),
    created_at TEXT DEFAULT (datetime('now')),
    paid_at TEXT,
    sent_to_kitchen_at TEXT,
    preparation_started_at TEXT,
    ready_at TEXT,
    delivered_at TEXT,
    cancelled_at TEXT,
    cancelled_by TEXT REFERENCES users(id),
    cancellation_reason TEXT,
    updated_at TEXT DEFAULT (datetime('now')),
    
    CHECK (subtotal >= 0),
    CHECK (tax_amount >= 0),
    CHECK (discount_amount >= 0),
    CHECK (total_amount >= 0)
);

CREATE INDEX IF NOT EXISTS idx_orders_branch ON orders(branch_id);
CREATE INDEX IF NOT EXISTS idx_orders_status ON orders(status_id);
CREATE INDEX IF NOT EXISTS idx_orders_date ON orders(created_at);
CREATE INDEX IF NOT EXISTS idx_orders_cashier ON orders(cashier_id);
CREATE INDEX IF NOT EXISTS idx_orders_number ON orders(order_number);

-- ---------------------------------------------
-- 23. ORDER_ITEMS (تفاصيل الأوردر)
-- ---------------------------------------------
CREATE TABLE IF NOT EXISTS order_items (
    id TEXT PRIMARY KEY,
    order_id TEXT NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    menu_item_id TEXT NOT NULL REFERENCES menu_items(id) ON DELETE RESTRICT,
    quantity INTEGER NOT NULL,
    unit_price REAL NOT NULL,
    discount_amount REAL DEFAULT 0,
    total_price REAL NOT NULL,
    notes TEXT,
    status TEXT DEFAULT 'pending',
    created_at TEXT DEFAULT (datetime('now')),
    
    CHECK (quantity > 0),
    CHECK (unit_price >= 0),
    CHECK (total_price >= 0)
);

CREATE INDEX IF NOT EXISTS idx_order_items_order ON order_items(order_id);
CREATE INDEX IF NOT EXISTS idx_order_items_menu ON order_items(menu_item_id);

-- =============================================
-- INVENTORY TRACKING TABLES
-- =============================================

-- ---------------------------------------------
-- 24. INVENTORY_TRANSACTIONS (حركات المخزون)
-- ---------------------------------------------
CREATE TABLE IF NOT EXISTS inventory_transactions (
    id TEXT PRIMARY KEY,
    branch_id TEXT NOT NULL REFERENCES branches(id) ON DELETE RESTRICT,
    item_id TEXT NOT NULL REFERENCES items(id) ON DELETE RESTRICT,
    operation_type_id INTEGER NOT NULL REFERENCES lookup_inventory_operation(id),
    quantity REAL NOT NULL,
    quantity_before REAL NOT NULL,
    quantity_after REAL NOT NULL,
    unit_cost REAL,
    reference_type TEXT,
    reference_id TEXT,
    batch_id TEXT REFERENCES inventory_batches(id) ON DELETE SET NULL,
    notes TEXT,
    created_by TEXT NOT NULL REFERENCES users(id),
    created_at TEXT DEFAULT (datetime('now')),
    
    CHECK (quantity != 0)
);

CREATE INDEX IF NOT EXISTS idx_inv_trans_branch ON inventory_transactions(branch_id);
CREATE INDEX IF NOT EXISTS idx_inv_trans_item ON inventory_transactions(item_id);
CREATE INDEX IF NOT EXISTS idx_inv_trans_type ON inventory_transactions(operation_type_id);
CREATE INDEX IF NOT EXISTS idx_inv_trans_date ON inventory_transactions(created_at);
CREATE INDEX IF NOT EXISTS idx_inv_trans_ref ON inventory_transactions(reference_type, reference_id);


-- ---------------------------------------------
-- 25. DAILY_INVENTORY_COUNTS (الجرد اليومي)
-- ---------------------------------------------
CREATE TABLE IF NOT EXISTS daily_inventory_counts (
    id TEXT PRIMARY KEY,
    branch_id TEXT NOT NULL REFERENCES branches(id) ON DELETE RESTRICT,
    count_date TEXT NOT NULL,
    count_type TEXT NOT NULL,
    status TEXT DEFAULT 'draft',
    notes TEXT,
    counted_by TEXT NOT NULL REFERENCES users(id),
    submitted_at TEXT,
    approved_by TEXT REFERENCES users(id),
    approved_at TEXT,
    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now')),
    
    UNIQUE (branch_id, count_date, count_type)
);

CREATE INDEX IF NOT EXISTS idx_daily_counts_branch_date ON daily_inventory_counts(branch_id, count_date);

-- ---------------------------------------------
-- 26. DAILY_INVENTORY_COUNT_ITEMS (تفاصيل الجرد)
-- ---------------------------------------------
CREATE TABLE IF NOT EXISTS daily_inventory_count_items (
    id TEXT PRIMARY KEY,
    count_id TEXT NOT NULL REFERENCES daily_inventory_counts(id) ON DELETE CASCADE,
    item_id TEXT NOT NULL REFERENCES items(id) ON DELETE RESTRICT,
    system_quantity REAL NOT NULL,
    actual_quantity REAL NOT NULL,
    variance_reason TEXT,
    created_at TEXT DEFAULT (datetime('now')),
    
    UNIQUE (count_id, item_id)
);

CREATE INDEX IF NOT EXISTS idx_count_items_count ON daily_inventory_count_items(count_id);

-- =============================================
-- NOTIFICATION & ALERT TABLES
-- =============================================

-- ---------------------------------------------
-- 27. NOTIFICATIONS (الإشعارات)
-- ---------------------------------------------
CREATE TABLE IF NOT EXISTS notifications (
    id TEXT PRIMARY KEY,
    user_id TEXT REFERENCES users(id) ON DELETE CASCADE,
    branch_id TEXT REFERENCES branches(id) ON DELETE CASCADE,
    type TEXT NOT NULL,
    title TEXT NOT NULL,
    message TEXT NOT NULL,
    priority TEXT DEFAULT 'normal',
    reference_type TEXT,
    reference_id TEXT,
    is_read INTEGER DEFAULT 0,
    read_at TEXT,
    created_at TEXT DEFAULT (datetime('now')),
    expires_at TEXT
);

CREATE INDEX IF NOT EXISTS idx_notifications_user ON notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_branch ON notifications(branch_id);
CREATE INDEX IF NOT EXISTS idx_notifications_unread ON notifications(user_id, is_read);
CREATE INDEX IF NOT EXISTS idx_notifications_type ON notifications(type);

-- ---------------------------------------------
-- 28. ALERT_SETTINGS (إعدادات التنبيهات)
-- ---------------------------------------------
CREATE TABLE IF NOT EXISTS alert_settings (
    id TEXT PRIMARY KEY,
    branch_id TEXT REFERENCES branches(id) ON DELETE CASCADE,
    alert_type TEXT NOT NULL,
    is_enabled INTEGER DEFAULT 1,
    threshold_value REAL,
    threshold_days INTEGER,
    notify_roles TEXT,
    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now')),
    
    UNIQUE (branch_id, alert_type)
);

-- =============================================
-- AUDIT & LOG TABLES
-- =============================================

-- ---------------------------------------------
-- 29. AUDIT_LOGS (سجل المراجعة)
-- ---------------------------------------------
CREATE TABLE IF NOT EXISTS audit_logs (
    id TEXT PRIMARY KEY,
    user_id TEXT REFERENCES users(id) ON DELETE SET NULL,
    action TEXT NOT NULL,
    table_name TEXT,
    record_id TEXT,
    old_values TEXT,
    new_values TEXT,
    ip_address TEXT,
    user_agent TEXT,
    created_at TEXT DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_audit_user ON audit_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_audit_table ON audit_logs(table_name);
CREATE INDEX IF NOT EXISTS idx_audit_date ON audit_logs(created_at);
CREATE INDEX IF NOT EXISTS idx_audit_action ON audit_logs(action);

-- ---------------------------------------------
-- 30. USER_SESSIONS (جلسات المستخدمين)
-- ---------------------------------------------
CREATE TABLE IF NOT EXISTS user_sessions (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token_hash TEXT NOT NULL,
    device_info TEXT,
    ip_address TEXT,
    is_active INTEGER DEFAULT 1,
    created_at TEXT DEFAULT (datetime('now')),
    expires_at TEXT NOT NULL,
    last_activity_at TEXT DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_sessions_user ON user_sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_sessions_active ON user_sessions(user_id, is_active);
CREATE INDEX IF NOT EXISTS idx_sessions_token ON user_sessions(token_hash);


-- =============================================
-- SETTINGS & CONFIGURATION TABLES
-- =============================================

-- ---------------------------------------------
-- 31. SYSTEM_SETTINGS (إعدادات النظام)
-- ---------------------------------------------
CREATE TABLE IF NOT EXISTS system_settings (
    id TEXT PRIMARY KEY,
    key TEXT NOT NULL UNIQUE,
    value TEXT,
    value_type TEXT DEFAULT 'string',
    description TEXT,
    is_public INTEGER DEFAULT 0,
    updated_by TEXT REFERENCES users(id),
    updated_at TEXT DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_settings_key ON system_settings(key);

-- ---------------------------------------------
-- 32. BRANCH_SETTINGS (إعدادات الفروع)
-- ---------------------------------------------
CREATE TABLE IF NOT EXISTS branch_settings (
    id TEXT PRIMARY KEY,
    branch_id TEXT NOT NULL REFERENCES branches(id) ON DELETE CASCADE,
    key TEXT NOT NULL,
    value TEXT,
    updated_by TEXT REFERENCES users(id),
    updated_at TEXT DEFAULT (datetime('now')),
    
    UNIQUE (branch_id, key)
);

CREATE INDEX IF NOT EXISTS idx_branch_settings_branch ON branch_settings(branch_id);

-- =============================================
-- INITIAL DATA (Seed Data)
-- =============================================

-- Generate UUIDs using hex(randomblob(16)) for SQLite
-- In production, use proper UUID generation in application layer

-- Insert default roles
INSERT INTO roles (id, name, name_ar, description, permissions, is_system_role) VALUES
(lower(hex(randomblob(16))), 'admin', 'مدير النظام', 'Full system access', '{"all": true}', 1),
(lower(hex(randomblob(16))), 'warehouse_manager', 'مدير المخزن', 'Warehouse and supplier management', 
 '{"suppliers": true, "inventory": true, "transfers": true, "damages": true, "returns": true, "reports": true}', 1),
(lower(hex(randomblob(16))), 'branch_supervisor', 'مشرف الفرع', 'Branch operations management',
 '{"branch_inventory": true, "daily_count": true, "transfer_request": true, "damage_register": true, "branch_reports": true}', 1),
(lower(hex(randomblob(16))), 'chef', 'طباخ', 'Kitchen operations',
 '{"kitchen_pos": true, "order_status": true}', 1),
(lower(hex(randomblob(16))), 'cashier', 'كاشير', 'POS and order management',
 '{"cashier_pos": true, "create_order": true, "payment": true}', 1);

-- Insert default units
INSERT INTO units (id, code, name, name_ar) VALUES
(lower(hex(randomblob(16))), 'KG', 'Kilogram', 'كيلوجرام'),
(lower(hex(randomblob(16))), 'G', 'Gram', 'جرام'),
(lower(hex(randomblob(16))), 'L', 'Liter', 'لتر'),
(lower(hex(randomblob(16))), 'ML', 'Milliliter', 'مللي لتر'),
(lower(hex(randomblob(16))), 'PC', 'Piece', 'قطعة'),
(lower(hex(randomblob(16))), 'BOX', 'Box', 'علبة'),
(lower(hex(randomblob(16))), 'PKT', 'Packet', 'باكت'),
(lower(hex(randomblob(16))), 'BTL', 'Bottle', 'زجاجة'),
(lower(hex(randomblob(16))), 'CAN', 'Can', 'علبة معدنية'),
(lower(hex(randomblob(16))), 'BAG', 'Bag', 'كيس'),
(lower(hex(randomblob(16))), 'CTN', 'Carton', 'كرتونة'),
(lower(hex(randomblob(16))), 'DOZ', 'Dozen', 'درزن');

-- Insert default damage reasons
INSERT INTO damage_reasons (id, code, name, name_ar, sort_order) VALUES
(lower(hex(randomblob(16))), 'EXPIRED', 'Expired', 'انتهاء الصلاحية', 1),
(lower(hex(randomblob(16))), 'STORAGE', 'Poor Storage', 'سوء التخزين', 2),
(lower(hex(randomblob(16))), 'TRANSPORT', 'Transport Damage', 'تلف أثناء النقل', 3),
(lower(hex(randomblob(16))), 'CONTAMINATION', 'Contamination', 'تلوث أو حشرات', 4),
(lower(hex(randomblob(16))), 'MOISTURE', 'Moisture/Leak', 'تسرب أو رطوبة', 5),
(lower(hex(randomblob(16))), 'HEAT', 'Heat/Fire', 'حريق أو حرارة', 6),
(lower(hex(randomblob(16))), 'OTHER', 'Other', 'أخرى', 99);

-- Insert main warehouse as default branch
INSERT INTO branches (id, code, name, name_ar, is_main_warehouse, status_id) VALUES
(lower(hex(randomblob(16))), 'MAIN', 'Main Warehouse', 'المخزن الرئيسي', 1, 1);


-- Insert default system settings
INSERT INTO system_settings (id, key, value, value_type, description) VALUES
(lower(hex(randomblob(16))), 'company_name', 'Restaurant Name', 'string', 'اسم المطعم'),
(lower(hex(randomblob(16))), 'company_name_ar', 'اسم المطعم', 'string', 'اسم المطعم بالعربي'),
(lower(hex(randomblob(16))), 'currency', 'EGP', 'string', 'العملة'),
(lower(hex(randomblob(16))), 'tax_rate', '14', 'number', 'نسبة الضريبة'),
(lower(hex(randomblob(16))), 'low_stock_threshold_days', '7', 'number', 'عدد أيام التنبيه قبل نفاد المخزون'),
(lower(hex(randomblob(16))), 'expiry_warning_days', '30', 'number', 'عدد أيام التنبيه قبل انتهاء الصلاحية'),
(lower(hex(randomblob(16))), 'session_timeout_minutes', '30', 'number', 'مدة انتهاء الجلسة بالدقائق'),
(lower(hex(randomblob(16))), 'max_login_attempts', '5', 'number', 'الحد الأقصى لمحاولات تسجيل الدخول'),
(lower(hex(randomblob(16))), 'order_number_prefix', 'ORD', 'string', 'بادئة رقم الأوردر'),
(lower(hex(randomblob(16))), 'supply_number_prefix', 'SUP', 'string', 'بادئة رقم التوريد'),
(lower(hex(randomblob(16))), 'transfer_number_prefix', 'TRF', 'string', 'بادئة رقم التحويل'),
(lower(hex(randomblob(16))), 'damage_number_prefix', 'DMG', 'string', 'بادئة رقم التالف'),
(lower(hex(randomblob(16))), 'return_number_prefix', 'RET', 'string', 'بادئة رقم المرتجع');

-- =============================================
-- VIEWS (Compatible with both SQLite and PostgreSQL)
-- =============================================

-- ---------------------------------------------
-- View: Current Inventory Status
-- ---------------------------------------------
CREATE VIEW IF NOT EXISTS v_inventory_status AS
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
    (i.quantity - i.reserved_quantity) AS available_quantity,
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
JOIN lookup_item_status lis ON it.status_id = lis.id
WHERE lis.code = 'active';

-- ---------------------------------------------
-- View: Supplier Balances
-- ---------------------------------------------
CREATE VIEW IF NOT EXISTS v_supplier_balances AS
SELECT 
    s.id,
    s.code,
    s.name,
    s.phone,
    lpm.code AS payment_terms,
    s.credit_limit,
    s.current_balance,
    lss.code AS status,
    COUNT(DISTINCT sup.id) AS total_supplies,
    COALESCE(SUM(CASE WHEN lps.code != 'paid' THEN (sup.total_amount - sup.paid_amount) ELSE 0 END), 0) AS pending_amount,
    MAX(sup.received_at) AS last_supply_date
FROM suppliers s
LEFT JOIN lookup_supplier_payment_method lpm ON s.payment_terms_id = lpm.id
LEFT JOIN lookup_supplier_status lss ON s.status_id = lss.id
LEFT JOIN supplies sup ON s.id = sup.supplier_id
LEFT JOIN lookup_payment_status lps ON sup.payment_status_id = lps.id
GROUP BY s.id, s.code, s.name, s.phone, lpm.code, s.credit_limit, s.current_balance, lss.code;

-- ---------------------------------------------
-- View: Daily Sales Summary
-- ---------------------------------------------
CREATE VIEW IF NOT EXISTS v_daily_sales AS
SELECT 
    o.branch_id,
    b.name AS branch_name,
    date(o.created_at) AS sale_date,
    COUNT(*) AS total_orders,
    SUM(CASE WHEN los.code = 'delivered' THEN 1 ELSE 0 END) AS completed_orders,
    SUM(CASE WHEN los.code = 'cancelled' THEN 1 ELSE 0 END) AS cancelled_orders,
    SUM(CASE WHEN los.code = 'delivered' THEN o.total_amount ELSE 0 END) AS total_sales,
    SUM(CASE WHEN los.code = 'delivered' THEN o.discount_amount ELSE 0 END) AS total_discounts,
    SUM(CASE WHEN los.code = 'delivered' THEN o.tax_amount ELSE 0 END) AS total_tax
FROM orders o
JOIN branches b ON o.branch_id = b.id
JOIN lookup_order_status los ON o.status_id = los.id
GROUP BY o.branch_id, b.name, date(o.created_at);


-- ---------------------------------------------
-- View: Pending Approvals
-- ---------------------------------------------
CREATE VIEW IF NOT EXISTS v_pending_approvals AS
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
JOIN lookup_transfer_status lts ON t.status_id = lts.id
WHERE lts.code = 'pending'

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
JOIN lookup_damage_status lds ON d.status_id = lds.id
WHERE lds.code = 'pending'

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
JOIN lookup_return_status lrs ON sr.status_id = lrs.id
WHERE lrs.code = 'pending';

-- ---------------------------------------------
-- View: Expiring Items
-- ---------------------------------------------
CREATE VIEW IF NOT EXISTS v_expiring_items AS
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
    julianday(ib.expiry_date) - julianday('now') AS days_until_expiry,
    CASE 
        WHEN date(ib.expiry_date) <= date('now') THEN 'expired'
        WHEN date(ib.expiry_date) <= date('now', '+7 days') THEN 'critical'
        WHEN date(ib.expiry_date) <= date('now', '+30 days') THEN 'warning'
        ELSE 'ok'
    END AS expiry_status
FROM inventory_batches ib
JOIN inventory i ON ib.inventory_id = i.id
JOIN branches b ON i.branch_id = b.id
JOIN items it ON i.item_id = it.id
WHERE ib.remaining_quantity > 0
  AND ib.expiry_date IS NOT NULL
  AND date(ib.expiry_date) <= date('now', '+30 days')
ORDER BY ib.expiry_date;

-- =============================================
-- TRIGGERS (SQLite Compatible)
-- =============================================

-- ---------------------------------------------
-- Trigger: Update timestamp on roles
-- ---------------------------------------------
CREATE TRIGGER IF NOT EXISTS trg_roles_updated_at
AFTER UPDATE ON roles
FOR EACH ROW
BEGIN
    UPDATE roles SET updated_at = datetime('now') WHERE id = NEW.id;
END;

-- ---------------------------------------------
-- Trigger: Update timestamp on branches
-- ---------------------------------------------
CREATE TRIGGER IF NOT EXISTS trg_branches_updated_at
AFTER UPDATE ON branches
FOR EACH ROW
BEGIN
    UPDATE branches SET updated_at = datetime('now') WHERE id = NEW.id;
END;

-- ---------------------------------------------
-- Trigger: Update timestamp on users
-- ---------------------------------------------
CREATE TRIGGER IF NOT EXISTS trg_users_updated_at
AFTER UPDATE ON users
FOR EACH ROW
BEGIN
    UPDATE users SET updated_at = datetime('now') WHERE id = NEW.id;
END;

-- ---------------------------------------------
-- Trigger: Update timestamp on items
-- ---------------------------------------------
CREATE TRIGGER IF NOT EXISTS trg_items_updated_at
AFTER UPDATE ON items
FOR EACH ROW
BEGIN
    UPDATE items SET updated_at = datetime('now') WHERE id = NEW.id;
END;

-- ---------------------------------------------
-- Trigger: Update timestamp on suppliers
-- ---------------------------------------------
CREATE TRIGGER IF NOT EXISTS trg_suppliers_updated_at
AFTER UPDATE ON suppliers
FOR EACH ROW
BEGIN
    UPDATE suppliers SET updated_at = datetime('now') WHERE id = NEW.id;
END;

-- ---------------------------------------------
-- Trigger: Update timestamp on inventory
-- ---------------------------------------------
CREATE TRIGGER IF NOT EXISTS trg_inventory_updated_at
AFTER UPDATE ON inventory
FOR EACH ROW
BEGIN
    UPDATE inventory SET updated_at = datetime('now') WHERE id = NEW.id;
END;

-- ---------------------------------------------
-- Trigger: Update timestamp on supplies
-- ---------------------------------------------
CREATE TRIGGER IF NOT EXISTS trg_supplies_updated_at
AFTER UPDATE ON supplies
FOR EACH ROW
BEGIN
    UPDATE supplies SET updated_at = datetime('now') WHERE id = NEW.id;
END;

-- ---------------------------------------------
-- Trigger: Update timestamp on transfers
-- ---------------------------------------------
CREATE TRIGGER IF NOT EXISTS trg_transfers_updated_at
AFTER UPDATE ON transfers
FOR EACH ROW
BEGIN
    UPDATE transfers SET updated_at = datetime('now') WHERE id = NEW.id;
END;

-- ---------------------------------------------
-- Trigger: Update timestamp on damages
-- ---------------------------------------------
CREATE TRIGGER IF NOT EXISTS trg_damages_updated_at
AFTER UPDATE ON damages
FOR EACH ROW
BEGIN
    UPDATE damages SET updated_at = datetime('now') WHERE id = NEW.id;
END;

-- ---------------------------------------------
-- Trigger: Update timestamp on orders
-- ---------------------------------------------
CREATE TRIGGER IF NOT EXISTS trg_orders_updated_at
AFTER UPDATE ON orders
FOR EACH ROW
BEGIN
    UPDATE orders SET updated_at = datetime('now') WHERE id = NEW.id;
END;

-- =============================================
-- END OF SCHEMA
-- =============================================
