-- Restaurant Management System Database Schema
-- PostgreSQL Version - Clean (No Arabic Comments)

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ENUM TYPES
CREATE TYPE user_status AS ENUM ('active', 'inactive', 'suspended');
CREATE TYPE supplier_status AS ENUM ('active', 'inactive');
CREATE TYPE supplier_payment_method AS ENUM ('cash', 'credit');
CREATE TYPE payment_status AS ENUM ('paid', 'pending', 'partial');
CREATE TYPE transfer_status AS ENUM ('pending', 'approved', 'rejected', 'received', 'cancelled');
CREATE TYPE damage_status AS ENUM ('pending', 'approved', 'rejected');
CREATE TYPE return_status AS ENUM ('pending', 'approved', 'rejected', 'received');
CREATE TYPE order_status AS ENUM ('new', 'pending_payment', 'paid', 'in_kitchen', 'preparing', 'ready', 'delivered', 'cancelled');
CREATE TYPE order_payment_method AS ENUM ('cash', 'visa', 'instapay', 'wallet');
CREATE TYPE inventory_operation AS ENUM ('supply', 'transfer_out', 'transfer_in', 'consumption', 'damage', 'return', 'adjustment');
CREATE TYPE branch_status AS ENUM ('active', 'inactive', 'maintenance');
CREATE TYPE item_status AS ENUM ('active', 'inactive');

-- 1. ROLES
CREATE TABLE roles (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(50) NOT NULL UNIQUE,
    name_ar VARCHAR(50) NOT NULL,
    description TEXT,
    permissions JSONB DEFAULT '{}',
    is_system_role BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX idx_roles_name ON roles(name);

-- 2. BRANCHES
CREATE TABLE branches (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    code VARCHAR(20) NOT NULL UNIQUE,
    name VARCHAR(100) NOT NULL,
    name_ar VARCHAR(100) NOT NULL,
    address TEXT,
    phone VARCHAR(20),
    email VARCHAR(100),
    status branch_status DEFAULT 'active',
    is_main_warehouse BOOLEAN DEFAULT FALSE,
    opening_time TIME,
    closing_time TIME,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX idx_branches_status ON branches(status);
CREATE INDEX idx_branches_is_main ON branches(is_main_warehouse);


-- 3. USERS
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    employee_code VARCHAR(20) NOT NULL UNIQUE,
    username VARCHAR(50) NOT NULL UNIQUE,
    email VARCHAR(100) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    full_name VARCHAR(100) NOT NULL,
    full_name_ar VARCHAR(100),
    phone VARCHAR(20),
    role_id UUID NOT NULL REFERENCES roles(id) ON DELETE RESTRICT,
    branch_id UUID REFERENCES branches(id) ON DELETE SET NULL,
    status user_status DEFAULT 'active',
    last_login TIMESTAMP WITH TIME ZONE,
    password_changed_at TIMESTAMP WITH TIME ZONE,
    failed_login_attempts INTEGER DEFAULT 0,
    locked_until TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    created_by UUID REFERENCES users(id)
);
CREATE INDEX idx_users_role ON users(role_id);
CREATE INDEX idx_users_branch ON users(branch_id);
CREATE INDEX idx_users_status ON users(status);

-- 4. CATEGORIES
CREATE TABLE categories (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    code VARCHAR(20) NOT NULL UNIQUE,
    name VARCHAR(100) NOT NULL,
    name_ar VARCHAR(100) NOT NULL,
    description TEXT,
    parent_id UUID REFERENCES categories(id) ON DELETE SET NULL,
    sort_order INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX idx_categories_parent ON categories(parent_id);

-- 5. UNITS
CREATE TABLE units (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    code VARCHAR(10) NOT NULL UNIQUE,
    name VARCHAR(50) NOT NULL,
    name_ar VARCHAR(50) NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 6. ITEMS
CREATE TABLE items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    code VARCHAR(50) NOT NULL UNIQUE,
    barcode VARCHAR(50) UNIQUE,
    name VARCHAR(150) NOT NULL,
    name_ar VARCHAR(150) NOT NULL,
    description TEXT,
    category_id UUID REFERENCES categories(id) ON DELETE SET NULL,
    unit_id UUID NOT NULL REFERENCES units(id) ON DELETE RESTRICT,
    purchase_price DECIMAL(12, 2) DEFAULT 0,
    selling_price DECIMAL(12, 2) DEFAULT 0,
    min_stock_level DECIMAL(12, 3) DEFAULT 0,
    max_stock_level DECIMAL(12, 3),
    reorder_level DECIMAL(12, 3),
    is_perishable BOOLEAN DEFAULT FALSE,
    shelf_life_days INTEGER,
    storage_conditions TEXT,
    status item_status DEFAULT 'active',
    image_url TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    created_by UUID REFERENCES users(id),
    CONSTRAINT chk_item_prices CHECK (purchase_price >= 0 AND selling_price >= 0)
);
CREATE INDEX idx_items_category ON items(category_id);
CREATE INDEX idx_items_status ON items(status);
CREATE INDEX idx_items_code ON items(code);

-- 7. SUPPLIERS
CREATE TABLE suppliers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    code VARCHAR(20) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    name_ar VARCHAR(150),
    contact_person VARCHAR(100),
    phone VARCHAR(20) NOT NULL,
    phone_alt VARCHAR(20),
    email VARCHAR(100),
    address TEXT,
    city VARCHAR(50),
    tax_number VARCHAR(50),
    commercial_register VARCHAR(50),
    payment_terms supplier_payment_method DEFAULT 'cash',
    credit_limit DECIMAL(12, 2) DEFAULT 0,
    credit_period_days INTEGER DEFAULT 0,
    current_balance DECIMAL(12, 2) DEFAULT 0,
    status supplier_status DEFAULT 'active',
    notes TEXT,
    rating INTEGER CHECK (rating >= 1 AND rating <= 5),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    created_by UUID REFERENCES users(id),
    CONSTRAINT chk_supplier_balance CHECK (current_balance >= 0)
);
CREATE INDEX idx_suppliers_status ON suppliers(status);
CREATE INDEX idx_suppliers_code ON suppliers(code);

-- 8. SUPPLIER_ITEMS
CREATE TABLE supplier_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    supplier_id UUID NOT NULL REFERENCES suppliers(id) ON DELETE CASCADE,
    item_id UUID NOT NULL REFERENCES items(id) ON DELETE CASCADE,
    supplier_item_code VARCHAR(50),
    unit_price DECIMAL(12, 2),
    min_order_quantity DECIMAL(12, 3),
    lead_time_days INTEGER,
    is_preferred BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uk_supplier_item UNIQUE (supplier_id, item_id)
);
CREATE INDEX idx_supplier_items_supplier ON supplier_items(supplier_id);
CREATE INDEX idx_supplier_items_item ON supplier_items(item_id);


-- 9. INVENTORY
CREATE TABLE inventory (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    branch_id UUID NOT NULL REFERENCES branches(id) ON DELETE RESTRICT,
    item_id UUID NOT NULL REFERENCES items(id) ON DELETE RESTRICT,
    quantity DECIMAL(12, 3) NOT NULL DEFAULT 0,
    reserved_quantity DECIMAL(12, 3) DEFAULT 0,
    min_quantity DECIMAL(12, 3) DEFAULT 0,
    last_restock_date TIMESTAMP WITH TIME ZONE,
    last_count_date TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uk_inventory_branch_item UNIQUE (branch_id, item_id),
    CONSTRAINT chk_inventory_quantity CHECK (quantity >= 0)
);
CREATE INDEX idx_inventory_branch ON inventory(branch_id);
CREATE INDEX idx_inventory_item ON inventory(item_id);

-- 10. INVENTORY_BATCHES
CREATE TABLE inventory_batches (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    inventory_id UUID NOT NULL REFERENCES inventory(id) ON DELETE CASCADE,
    batch_number VARCHAR(50),
    quantity DECIMAL(12, 3) NOT NULL,
    remaining_quantity DECIMAL(12, 3) NOT NULL,
    purchase_price DECIMAL(12, 2),
    production_date DATE,
    expiry_date DATE,
    received_date DATE NOT NULL DEFAULT CURRENT_DATE,
    supply_id UUID,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_batch_quantity CHECK (quantity > 0),
    CONSTRAINT chk_batch_remaining CHECK (remaining_quantity >= 0)
);
CREATE INDEX idx_batches_inventory ON inventory_batches(inventory_id);
CREATE INDEX idx_batches_expiry ON inventory_batches(expiry_date);

-- 11. SUPPLIES
CREATE TABLE supplies (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    supply_number VARCHAR(30) NOT NULL UNIQUE,
    supplier_id UUID NOT NULL REFERENCES suppliers(id) ON DELETE RESTRICT,
    branch_id UUID NOT NULL REFERENCES branches(id) ON DELETE RESTRICT,
    invoice_number VARCHAR(50),
    invoice_date DATE,
    subtotal DECIMAL(12, 2) NOT NULL DEFAULT 0,
    tax_amount DECIMAL(12, 2) DEFAULT 0,
    discount_amount DECIMAL(12, 2) DEFAULT 0,
    total_amount DECIMAL(12, 2) NOT NULL DEFAULT 0,
    payment_method supplier_payment_method NOT NULL,
    payment_status payment_status DEFAULT 'pending',
    paid_amount DECIMAL(12, 2) DEFAULT 0,
    due_date DATE,
    notes TEXT,
    received_by UUID NOT NULL REFERENCES users(id),
    received_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    approved_by UUID REFERENCES users(id),
    approved_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_supply_amounts CHECK (total_amount >= 0 AND paid_amount >= 0)
);
CREATE INDEX idx_supplies_supplier ON supplies(supplier_id);
CREATE INDEX idx_supplies_branch ON supplies(branch_id);
CREATE INDEX idx_supplies_date ON supplies(received_at);

-- 12. SUPPLY_ITEMS
CREATE TABLE supply_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    supply_id UUID NOT NULL REFERENCES supplies(id) ON DELETE CASCADE,
    item_id UUID NOT NULL REFERENCES items(id) ON DELETE RESTRICT,
    quantity DECIMAL(12, 3) NOT NULL,
    received_quantity DECIMAL(12, 3) NOT NULL,
    unit_price DECIMAL(12, 2) NOT NULL,
    discount_percent DECIMAL(5, 2) DEFAULT 0,
    tax_percent DECIMAL(5, 2) DEFAULT 0,
    total_price DECIMAL(12, 2) NOT NULL,
    batch_number VARCHAR(50),
    production_date DATE,
    expiry_date DATE,
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_supply_item_qty CHECK (quantity > 0)
);
CREATE INDEX idx_supply_items_supply ON supply_items(supply_id);
CREATE INDEX idx_supply_items_item ON supply_items(item_id);

-- Add FK to inventory_batches
ALTER TABLE inventory_batches ADD CONSTRAINT fk_batch_supply 
    FOREIGN KEY (supply_id) REFERENCES supplies(id) ON DELETE SET NULL;

-- 13. SUPPLIER_PAYMENTS
CREATE TABLE supplier_payments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    payment_number VARCHAR(30) NOT NULL UNIQUE,
    supplier_id UUID NOT NULL REFERENCES suppliers(id) ON DELETE RESTRICT,
    supply_id UUID REFERENCES supplies(id) ON DELETE SET NULL,
    amount DECIMAL(12, 2) NOT NULL,
    payment_method VARCHAR(50) NOT NULL,
    reference_number VARCHAR(50),
    bank_name VARCHAR(100),
    payment_date DATE NOT NULL DEFAULT CURRENT_DATE,
    notes TEXT,
    created_by UUID NOT NULL REFERENCES users(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_payment_amount CHECK (amount > 0)
);
CREATE INDEX idx_supplier_payments_supplier ON supplier_payments(supplier_id);
CREATE INDEX idx_supplier_payments_date ON supplier_payments(payment_date);


-- 14. TRANSFERS
CREATE TABLE transfers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    transfer_number VARCHAR(30) NOT NULL UNIQUE,
    from_branch_id UUID NOT NULL REFERENCES branches(id) ON DELETE RESTRICT,
    to_branch_id UUID NOT NULL REFERENCES branches(id) ON DELETE RESTRICT,
    status transfer_status DEFAULT 'pending',
    priority INTEGER DEFAULT 0,
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
CREATE INDEX idx_transfers_from_branch ON transfers(from_branch_id);
CREATE INDEX idx_transfers_to_branch ON transfers(to_branch_id);
CREATE INDEX idx_transfers_status ON transfers(status);

-- 15. TRANSFER_ITEMS
CREATE TABLE transfer_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    transfer_id UUID NOT NULL REFERENCES transfers(id) ON DELETE CASCADE,
    item_id UUID NOT NULL REFERENCES items(id) ON DELETE RESTRICT,
    requested_quantity DECIMAL(12, 3) NOT NULL,
    approved_quantity DECIMAL(12, 3),
    shipped_quantity DECIMAL(12, 3),
    received_quantity DECIMAL(12, 3),
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_transfer_item_qty CHECK (requested_quantity > 0)
);
CREATE INDEX idx_transfer_items_transfer ON transfer_items(transfer_id);
CREATE INDEX idx_transfer_items_item ON transfer_items(item_id);

-- 16. DAMAGE_REASONS
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

-- 17. DAMAGES
CREATE TABLE damages (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    damage_number VARCHAR(30) NOT NULL UNIQUE,
    branch_id UUID NOT NULL REFERENCES branches(id) ON DELETE RESTRICT,
    item_id UUID NOT NULL REFERENCES items(id) ON DELETE RESTRICT,
    quantity DECIMAL(12, 3) NOT NULL,
    unit_cost DECIMAL(12, 2),
    total_cost DECIMAL(12, 2),
    reason_id UUID NOT NULL REFERENCES damage_reasons(id) ON DELETE RESTRICT,
    description TEXT,
    image_url TEXT,
    batch_id UUID REFERENCES inventory_batches(id) ON DELETE SET NULL,
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
    CONSTRAINT chk_damage_quantity CHECK (quantity > 0)
);
CREATE INDEX idx_damages_branch ON damages(branch_id);
CREATE INDEX idx_damages_item ON damages(item_id);
CREATE INDEX idx_damages_status ON damages(status);

-- 18. SUPPLIER_RETURNS
CREATE TABLE supplier_returns (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    return_number VARCHAR(30) NOT NULL UNIQUE,
    supply_id UUID NOT NULL REFERENCES supplies(id) ON DELETE RESTRICT,
    supplier_id UUID NOT NULL REFERENCES suppliers(id) ON DELETE RESTRICT,
    item_id UUID NOT NULL REFERENCES items(id) ON DELETE RESTRICT,
    quantity DECIMAL(12, 3) NOT NULL,
    unit_price DECIMAL(12, 2) NOT NULL,
    total_amount DECIMAL(12, 2) NOT NULL,
    reason TEXT NOT NULL,
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
    received_by_supplier_at TIMESTAMP WITH TIME ZONE,
    credit_note_number VARCHAR(50),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_return_quantity CHECK (quantity > 0)
);
CREATE INDEX idx_returns_supply ON supplier_returns(supply_id);
CREATE INDEX idx_returns_supplier ON supplier_returns(supplier_id);
CREATE INDEX idx_returns_status ON supplier_returns(status);


-- 19. MENU_CATEGORIES
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
CREATE INDEX idx_menu_categories_parent ON menu_categories(parent_id);

-- 20. MENU_ITEMS
CREATE TABLE menu_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    name_ar VARCHAR(150) NOT NULL,
    description TEXT,
    description_ar TEXT,
    category_id UUID REFERENCES menu_categories(id) ON DELETE SET NULL,
    price DECIMAL(12, 2) NOT NULL,
    cost DECIMAL(12, 2) DEFAULT 0,
    tax_percent DECIMAL(5, 2) DEFAULT 0,
    image_url TEXT,
    preparation_time_minutes INTEGER,
    calories INTEGER,
    is_available BOOLEAN DEFAULT TRUE,
    is_active BOOLEAN DEFAULT TRUE,
    sort_order INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_menu_item_price CHECK (price >= 0)
);
CREATE INDEX idx_menu_items_category ON menu_items(category_id);

-- 21. MENU_ITEM_INGREDIENTS
CREATE TABLE menu_item_ingredients (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    menu_item_id UUID NOT NULL REFERENCES menu_items(id) ON DELETE CASCADE,
    item_id UUID NOT NULL REFERENCES items(id) ON DELETE RESTRICT,
    quantity DECIMAL(12, 4) NOT NULL,
    unit_id UUID NOT NULL REFERENCES units(id) ON DELETE RESTRICT,
    is_optional BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uk_menu_ingredient UNIQUE (menu_item_id, item_id),
    CONSTRAINT chk_ingredient_qty CHECK (quantity > 0)
);
CREATE INDEX idx_menu_ingredients_menu ON menu_item_ingredients(menu_item_id);
CREATE INDEX idx_menu_ingredients_item ON menu_item_ingredients(item_id);

-- 22. ORDERS
CREATE TABLE orders (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    order_number VARCHAR(30) NOT NULL UNIQUE,
    branch_id UUID NOT NULL REFERENCES branches(id) ON DELETE RESTRICT,
    order_type VARCHAR(20) DEFAULT 'takeaway',
    customer_name VARCHAR(100),
    customer_phone VARCHAR(20),
    subtotal DECIMAL(12, 2) NOT NULL DEFAULT 0,
    tax_amount DECIMAL(12, 2) DEFAULT 0,
    discount_amount DECIMAL(12, 2) DEFAULT 0,
    discount_reason TEXT,
    total_amount DECIMAL(12, 2) NOT NULL DEFAULT 0,
    payment_method order_payment_method,
    payment_reference VARCHAR(100),
    status order_status DEFAULT 'new',
    notes TEXT,
    kitchen_notes TEXT,
    cashier_id UUID NOT NULL REFERENCES users(id),
    chef_id UUID REFERENCES users(id),
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
    CONSTRAINT chk_order_amounts CHECK (total_amount >= 0)
);
CREATE INDEX idx_orders_branch ON orders(branch_id);
CREATE INDEX idx_orders_status ON orders(status);
CREATE INDEX idx_orders_date ON orders(created_at);
CREATE INDEX idx_orders_cashier ON orders(cashier_id);

-- 23. ORDER_ITEMS
CREATE TABLE order_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    menu_item_id UUID NOT NULL REFERENCES menu_items(id) ON DELETE RESTRICT,
    quantity INTEGER NOT NULL,
    unit_price DECIMAL(12, 2) NOT NULL,
    discount_amount DECIMAL(12, 2) DEFAULT 0,
    total_price DECIMAL(12, 2) NOT NULL,
    notes TEXT,
    status VARCHAR(20) DEFAULT 'pending',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_order_item_qty CHECK (quantity > 0)
);
CREATE INDEX idx_order_items_order ON order_items(order_id);
CREATE INDEX idx_order_items_menu ON order_items(menu_item_id);


-- 24. INVENTORY_TRANSACTIONS
CREATE TABLE inventory_transactions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    branch_id UUID NOT NULL REFERENCES branches(id) ON DELETE RESTRICT,
    item_id UUID NOT NULL REFERENCES items(id) ON DELETE RESTRICT,
    operation_type inventory_operation NOT NULL,
    quantity DECIMAL(12, 3) NOT NULL,
    quantity_before DECIMAL(12, 3) NOT NULL,
    quantity_after DECIMAL(12, 3) NOT NULL,
    unit_cost DECIMAL(12, 2),
    reference_type VARCHAR(50),
    reference_id UUID,
    batch_id UUID REFERENCES inventory_batches(id) ON DELETE SET NULL,
    notes TEXT,
    created_by UUID NOT NULL REFERENCES users(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_transaction_qty CHECK (quantity != 0)
);
CREATE INDEX idx_inv_trans_branch ON inventory_transactions(branch_id);
CREATE INDEX idx_inv_trans_item ON inventory_transactions(item_id);
CREATE INDEX idx_inv_trans_type ON inventory_transactions(operation_type);
CREATE INDEX idx_inv_trans_date ON inventory_transactions(created_at);

-- 25. DAILY_INVENTORY_COUNTS
CREATE TABLE daily_inventory_counts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    branch_id UUID NOT NULL REFERENCES branches(id) ON DELETE RESTRICT,
    count_date DATE NOT NULL,
    count_type VARCHAR(20) NOT NULL,
    status VARCHAR(20) DEFAULT 'draft',
    notes TEXT,
    counted_by UUID NOT NULL REFERENCES users(id),
    submitted_at TIMESTAMP WITH TIME ZONE,
    approved_by UUID REFERENCES users(id),
    approved_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uk_daily_count UNIQUE (branch_id, count_date, count_type)
);
CREATE INDEX idx_daily_counts_branch_date ON daily_inventory_counts(branch_id, count_date);

-- 26. DAILY_INVENTORY_COUNT_ITEMS
CREATE TABLE daily_inventory_count_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    count_id UUID NOT NULL REFERENCES daily_inventory_counts(id) ON DELETE CASCADE,
    item_id UUID NOT NULL REFERENCES items(id) ON DELETE RESTRICT,
    system_quantity DECIMAL(12, 3) NOT NULL,
    actual_quantity DECIMAL(12, 3) NOT NULL,
    variance_reason TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uk_count_item UNIQUE (count_id, item_id)
);
CREATE INDEX idx_count_items_count ON daily_inventory_count_items(count_id);

-- 27. NOTIFICATIONS
CREATE TABLE notifications (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    branch_id UUID REFERENCES branches(id) ON DELETE CASCADE,
    type VARCHAR(50) NOT NULL,
    title VARCHAR(200) NOT NULL,
    message TEXT NOT NULL,
    priority VARCHAR(20) DEFAULT 'normal',
    reference_type VARCHAR(50),
    reference_id UUID,
    is_read BOOLEAN DEFAULT FALSE,
    read_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP WITH TIME ZONE
);
CREATE INDEX idx_notifications_user ON notifications(user_id);
CREATE INDEX idx_notifications_branch ON notifications(branch_id);

-- 28. ALERT_SETTINGS
CREATE TABLE alert_settings (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    branch_id UUID REFERENCES branches(id) ON DELETE CASCADE,
    alert_type VARCHAR(50) NOT NULL,
    is_enabled BOOLEAN DEFAULT TRUE,
    threshold_value DECIMAL(12, 3),
    threshold_days INTEGER,
    notify_roles TEXT[],
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uk_alert_setting UNIQUE (branch_id, alert_type)
);

-- 29. AUDIT_LOGS
CREATE TABLE audit_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    action VARCHAR(50) NOT NULL,
    table_name VARCHAR(100),
    record_id UUID,
    old_values JSONB,
    new_values JSONB,
    ip_address INET,
    user_agent TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX idx_audit_user ON audit_logs(user_id);
CREATE INDEX idx_audit_table ON audit_logs(table_name);
CREATE INDEX idx_audit_date ON audit_logs(created_at);

-- 30. USER_SESSIONS
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
CREATE INDEX idx_sessions_user ON user_sessions(user_id);
CREATE INDEX idx_sessions_token ON user_sessions(token_hash);

-- 31. SYSTEM_SETTINGS
CREATE TABLE system_settings (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    key VARCHAR(100) NOT NULL UNIQUE,
    value TEXT,
    value_type VARCHAR(20) DEFAULT 'string',
    description TEXT,
    is_public BOOLEAN DEFAULT FALSE,
    updated_by UUID REFERENCES users(id),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX idx_settings_key ON system_settings(key);

-- 32. BRANCH_SETTINGS
CREATE TABLE branch_settings (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    branch_id UUID NOT NULL REFERENCES branches(id) ON DELETE CASCADE,
    key VARCHAR(100) NOT NULL,
    value TEXT,
    updated_by UUID REFERENCES users(id),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uk_branch_setting UNIQUE (branch_id, key)
);
CREATE INDEX idx_branch_settings_branch ON branch_settings(branch_id);


-- SEED DATA

-- Insert default roles
INSERT INTO roles (name, name_ar, description, permissions, is_system_role) VALUES
('admin', 'مدير النظام', 'Full system access', '{"all": true}', TRUE),
('warehouse_manager', 'مدير المخزن', 'Warehouse and supplier management', '{"suppliers": true, "inventory": true}', TRUE),
('branch_supervisor', 'مشرف الفرع', 'Branch operations management', '{"branch_inventory": true}', TRUE),
('chef', 'طباخ', 'Kitchen operations', '{"kitchen_pos": true}', TRUE),
('cashier', 'كاشير', 'POS and order management', '{"cashier_pos": true}', TRUE);

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
('MAIN', 'Main Warehouse', 'المخزن الرئيسي', TRUE, 'active'),
('BR001', 'Branch 1', 'الفرع الأول', FALSE, 'active'),
('BR002', 'Branch 2', 'الفرع الثاني', FALSE, 'active');

-- Insert default system settings
INSERT INTO system_settings (key, value, value_type, description) VALUES
('company_name', 'Restaurant Name', 'string', 'Company name'),
('company_name_ar', 'اسم المطعم', 'string', 'Company name in Arabic'),
('currency', 'EGP', 'string', 'Currency'),
('tax_rate', '14', 'number', 'Tax rate percentage'),
('low_stock_threshold_days', '7', 'number', 'Days before low stock alert'),
('expiry_warning_days', '30', 'number', 'Days before expiry warning'),
('order_number_prefix', 'ORD', 'string', 'Order number prefix'),
('supply_number_prefix', 'SUP', 'string', 'Supply number prefix'),
('transfer_number_prefix', 'TRF', 'string', 'Transfer number prefix'),
('damage_number_prefix', 'DMG', 'string', 'Damage number prefix'),
('return_number_prefix', 'RET', 'string', 'Return number prefix');

-- Done
SELECT 'Database schema created successfully!' as status;
