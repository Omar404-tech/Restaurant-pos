-- =====================================================
-- DEEP TEST COMPLETE - All Flows & Scenarios
-- Restaurant Management System
-- =====================================================
-- This file tests ALL business flows and edge cases
-- Run this against a clean database with seed data
-- =====================================================

-- =====================================================
-- CLEANUP: Reset test data (optional)
-- =====================================================
-- DELETE FROM audit_logs WHERE created_at > CURRENT_DATE - INTERVAL '1 day';
-- DELETE FROM notifications WHERE created_at > CURRENT_DATE - INTERVAL '1 day';
-- DELETE FROM inventory_transactions WHERE created_at > CURRENT_DATE - INTERVAL '1 day';

-- =====================================================
-- SECTION 1: AUTHENTICATION & USER MANAGEMENT
-- =====================================================

-- 1.1: Create test users for all roles
INSERT INTO users (employee_code, username, email, password_hash, full_name, full_name_ar, phone, role_id, branch_id, status)
SELECT 'TEST001', 'test_admin', 'test_admin@test.com', 'hashed_password', 'Test Admin', 'مدير اختبار', '01000000100',
       r.id, b.id, 'active'
FROM roles r, branches b WHERE r.name = 'admin' AND b.code = 'MAIN'
ON CONFLICT (username) DO NOTHING;

INSERT INTO users (employee_code, username, email, password_hash, full_name, full_name_ar, phone, role_id, branch_id, status)
SELECT 'TEST002', 'test_warehouse', 'test_warehouse@test.com', 'hashed_password', 'Test Warehouse', 'مخزن اختبار', '01000000101',
       r.id, b.id, 'active'
FROM roles r, branches b WHERE r.name = 'warehouse_manager' AND b.code = 'MAIN'
ON CONFLICT (username) DO NOTHING;

INSERT INTO users (employee_code, username, email, password_hash, full_name, full_name_ar, phone, role_id, branch_id, status)
SELECT 'TEST003', 'test_branch_sup', 'test_branch@test.com', 'hashed_password', 'Test Branch Sup', 'مشرف فرع اختبار', '01000000102',
       r.id, b.id, 'active'
FROM roles r, branches b WHERE r.name = 'branch_supervisor' AND b.code = 'BR001'
ON CONFLICT (username) DO NOTHING;

INSERT INTO users (employee_code, username, email, password_hash, full_name, full_name_ar, phone, role_id, branch_id, status)
SELECT 'TEST004', 'test_cashier', 'test_cashier@test.com', 'hashed_password', 'Test Cashier', 'كاشير اختبار', '01000000103',
       r.id, b.id, 'active'
FROM roles r, branches b WHERE r.name = 'cashier' AND b.code = 'BR001'
ON CONFLICT (username) DO NOTHING;

INSERT INTO users (employee_code, username, email, password_hash, full_name, full_name_ar, phone, role_id, branch_id, status)
SELECT 'TEST005', 'test_chef', 'test_chef@test.com', 'hashed_password', 'Test Chef', 'شيف اختبار', '01000000104',
       r.id, b.id, 'active'
FROM roles r, branches b WHERE r.name = 'chef' AND b.code = 'BR001'
ON CONFLICT (username) DO NOTHING;

INSERT INTO users (employee_code, username, email, password_hash, full_name, full_name_ar, phone, role_id, branch_id, status)
SELECT 'TEST006', 'test_purchase', 'test_purchase@test.com', 'hashed_password', 'Test Purchase', 'مشتريات اختبار', '01000000105',
       r.id, b.id, 'active'
FROM roles r, branches b WHERE r.name = 'purchase_manager' AND b.code = 'MAIN'
ON CONFLICT (username) DO NOTHING;

-- 1.2: Test user status changes
UPDATE users SET status = 'inactive' WHERE username = 'test_chef';
UPDATE users SET status = 'active' WHERE username = 'test_chef';

-- 1.3: Test user role assignment
-- Verify user can only access their branch data

-- =====================================================
-- SECTION 2: BRANCH MANAGEMENT
-- =====================================================

-- 2.1: Create new branch
INSERT INTO branches (code, name, name_ar, address, phone, email, status, is_main_warehouse)
VALUES ('TEST01', 'Test Branch', 'فرع اختبار', 'Test Address', '01000000200', 'test@branch.com', 'active', FALSE)
ON CONFLICT (code) DO NOTHING;

-- 2.2: Update branch status
UPDATE branches SET status = 'maintenance' WHERE code = 'TEST01';
UPDATE branches SET status = 'active' WHERE code = 'TEST01';

-- 2.3: Test branch settings
INSERT INTO branch_settings (branch_id, key, value)
SELECT id, 'opening_time', '08:00' FROM branches WHERE code = 'TEST01'
ON CONFLICT DO NOTHING;

INSERT INTO branch_settings (branch_id, key, value)
SELECT id, 'closing_time', '23:00' FROM branches WHERE code = 'TEST01'
ON CONFLICT DO NOTHING;

-- =====================================================
-- SECTION 3: SUPPLIER MANAGEMENT - COMPLETE FLOW
-- =====================================================

-- 3.1: Create new supplier with credit terms
INSERT INTO suppliers (code, name, name_ar, contact_person, phone, email, address, payment_terms, credit_limit, credit_period_days, status, created_by)
SELECT 'TSUP001', 'Test Supplier 1', 'مورد اختبار 1', 'Test Contact', '01000000300', 'test@supplier.com', 
       'Test Address', 'credit', 50000.00, 30, 'active', u.id
FROM users u WHERE u.username = 'test_admin'
ON CONFLICT (code) DO NOTHING;

-- 3.2: Create supplier with cash terms
INSERT INTO suppliers (code, name, name_ar, contact_person, phone, email, address, payment_terms, credit_limit, status, created_by)
SELECT 'TSUP002', 'Test Supplier 2', 'مورد اختبار 2', 'Test Contact 2', '01000000301', 'test2@supplier.com', 
       'Test Address 2', 'cash', 0, 'active', u.id
FROM users u WHERE u.username = 'test_admin'
ON CONFLICT (code) DO NOTHING;

-- 3.3: Link supplier to items
INSERT INTO supplier_items (supplier_id, item_id, supplier_item_code, unit_price, min_order_quantity, lead_time_days, is_preferred)
SELECT s.id, i.id, 'TSUP-ITM001', 75.00, 10, 1, TRUE
FROM suppliers s, items i WHERE s.code = 'TSUP001' AND i.code = 'ITM001'
ON CONFLICT ON CONSTRAINT uk_supplier_item DO NOTHING;

INSERT INTO supplier_items (supplier_id, item_id, supplier_item_code, unit_price, min_order_quantity, lead_time_days, is_preferred)
SELECT s.id, i.id, 'TSUP-ITM002', 240.00, 5, 2, TRUE
FROM suppliers s, items i WHERE s.code = 'TSUP001' AND i.code = 'ITM002'
ON CONFLICT ON CONSTRAINT uk_supplier_item DO NOTHING;

-- 3.4: Update supplier status
UPDATE suppliers SET status = 'inactive' WHERE code = 'TSUP002';
UPDATE suppliers SET status = 'active' WHERE code = 'TSUP002';

-- =====================================================
-- SECTION 4: SUPPLY FLOW - COMPLETE SCENARIOS
-- =====================================================

-- 4.1: Create credit supply (partial payment)
INSERT INTO supplies (supply_number, supplier_id, branch_id, invoice_number, invoice_date, subtotal, tax_amount, total_amount, payment_method, payment_status, paid_amount, received_by, received_at)
SELECT 'TSUP-2024-001', s.id, b.id, 'TINV-001', CURRENT_DATE, 5000.00, 700.00, 5700.00, 'credit', 'partial', 2000.00, u.id, CURRENT_TIMESTAMP
FROM suppliers s, branches b, users u
WHERE s.code = 'TSUP001' AND b.code = 'MAIN' AND u.username = 'test_warehouse'
ON CONFLICT (supply_number) DO NOTHING;

-- 4.2: Add supply items
INSERT INTO supply_items (supply_id, item_id, quantity, received_quantity, unit_price, tax_percent, total_price, batch_number, expiry_date)
SELECT sup.id, i.id, 50, 50, 75.00, 14, 4275.00, 'TBATCH-001', CURRENT_DATE + INTERVAL '7 days'
FROM supplies sup, items i WHERE sup.supply_number = 'TSUP-2024-001' AND i.code = 'ITM001'
ON CONFLICT DO NOTHING;

INSERT INTO supply_items (supply_id, item_id, quantity, received_quantity, unit_price, tax_percent, total_price, batch_number, expiry_date)
SELECT sup.id, i.id, 10, 10, 240.00, 14, 2736.00, 'TBATCH-002', CURRENT_DATE + INTERVAL '5 days'
FROM supplies sup, items i WHERE sup.supply_number = 'TSUP-2024-001' AND i.code = 'ITM002'
ON CONFLICT DO NOTHING;

-- 4.3: Update supplier balance (credit amount = total - paid)
UPDATE suppliers SET current_balance = current_balance + 3700.00 WHERE code = 'TSUP001';

-- 4.4: Update inventory from supply
UPDATE inventory SET quantity = quantity + 50, incoming_quantity = incoming_quantity + 50, last_restock_date = CURRENT_TIMESTAMP
WHERE branch_id = (SELECT id FROM branches WHERE code = 'MAIN') 
AND item_id = (SELECT id FROM items WHERE code = 'ITM001');

UPDATE inventory SET quantity = quantity + 10, incoming_quantity = incoming_quantity + 10, last_restock_date = CURRENT_TIMESTAMP
WHERE branch_id = (SELECT id FROM branches WHERE code = 'MAIN') 
AND item_id = (SELECT id FROM items WHERE code = 'ITM002');

-- 4.5: Record inventory transactions
INSERT INTO inventory_transactions (branch_id, item_id, operation_type, quantity, quantity_before, quantity_after, unit_cost, reference_type, created_by)
SELECT b.id, i.id, 'supply', 50, 
       (SELECT quantity - 50 FROM inventory WHERE branch_id = b.id AND item_id = i.id),
       (SELECT quantity FROM inventory WHERE branch_id = b.id AND item_id = i.id),
       75.00, 'supply', u.id
FROM branches b, items i, users u WHERE b.code = 'MAIN' AND i.code = 'ITM001' AND u.username = 'test_warehouse';

-- 4.6: Create cash supply (fully paid)
INSERT INTO supplies (supply_number, supplier_id, branch_id, invoice_number, invoice_date, subtotal, tax_amount, total_amount, payment_method, payment_status, paid_amount, received_by, received_at)
SELECT 'TSUP-2024-002', s.id, b.id, 'TINV-002', CURRENT_DATE, 1000.00, 140.00, 1140.00, 'cash', 'paid', 1140.00, u.id, CURRENT_TIMESTAMP
FROM suppliers s, branches b, users u
WHERE s.code = 'TSUP002' AND b.code = 'MAIN' AND u.username = 'test_warehouse'
ON CONFLICT (supply_number) DO NOTHING;

-- 4.7: Partial quantity received scenario
INSERT INTO supplies (supply_number, supplier_id, branch_id, invoice_number, invoice_date, subtotal, tax_amount, total_amount, payment_method, payment_status, received_by, received_at)
SELECT 'TSUP-2024-003', s.id, b.id, 'TINV-003', CURRENT_DATE, 2000.00, 280.00, 2280.00, 'credit', 'pending', u.id, CURRENT_TIMESTAMP
FROM suppliers s, branches b, users u
WHERE s.code = 'TSUP001' AND b.code = 'MAIN' AND u.username = 'test_warehouse'
ON CONFLICT (supply_number) DO NOTHING;

-- Ordered 30, received only 25
INSERT INTO supply_items (supply_id, item_id, quantity, received_quantity, unit_price, tax_percent, total_price, batch_number, expiry_date)
SELECT sup.id, i.id, 30, 25, 75.00, 14, 2137.50, 'TBATCH-003', CURRENT_DATE + INTERVAL '7 days'
FROM supplies sup, items i WHERE sup.supply_number = 'TSUP-2024-003' AND i.code = 'ITM001'
ON CONFLICT DO NOTHING;

-- =====================================================
-- SECTION 5: SUPPLIER PAYMENT FLOW
-- =====================================================

-- 5.1: Make partial payment
INSERT INTO supplier_payments (payment_number, supplier_id, amount, payment_method, reference_number, bank_name, payment_date, notes, created_by)
SELECT 'TPAY-2024-001', s.id, 1500.00, 'bank_transfer', 'TRX-TEST-001', 'Test Bank', CURRENT_DATE, 'Partial payment for TSUP-2024-001', u.id
FROM suppliers s, users u WHERE s.code = 'TSUP001' AND u.username = 'test_admin'
ON CONFLICT (payment_number) DO NOTHING;

-- 5.2: Update supplier balance
UPDATE suppliers SET current_balance = current_balance - 1500.00 WHERE code = 'TSUP001';

-- 5.3: Make full payment
INSERT INTO supplier_payments (payment_number, supplier_id, amount, payment_method, reference_number, payment_date, notes, created_by)
SELECT 'TPAY-2024-002', s.id, 2200.00, 'cash', NULL, CURRENT_DATE, 'Full payment', u.id
FROM suppliers s, users u WHERE s.code = 'TSUP001' AND u.username = 'test_admin'
ON CONFLICT (payment_number) DO NOTHING;

UPDATE suppliers SET current_balance = current_balance - 2200.00 WHERE code = 'TSUP001';

-- 5.4: Update supply payment status
UPDATE supplies SET payment_status = 'paid', paid_amount = total_amount WHERE supply_number = 'TSUP-2024-001';

-- =====================================================
-- SECTION 6: SUPPLIER RETURN FLOW
-- =====================================================

-- 6.1: Create supplier return (defective items)
INSERT INTO supplier_returns (return_number, supply_id, supplier_id, item_id, quantity, unit_price, total_amount, reason, description, status, registered_by, registered_at)
SELECT 'TRET-2024-001', sup.id, s.id, i.id, 5, 75.00, 375.00, 'Defective', 'Items were damaged on arrival', 'pending', u.id, CURRENT_TIMESTAMP
FROM supplies sup, suppliers s, items i, users u
WHERE sup.supply_number = 'TSUP-2024-001' AND s.code = 'TSUP001' AND i.code = 'ITM001' AND u.username = 'test_warehouse'
ON CONFLICT (return_number) DO NOTHING;

-- 6.2: Approve return
UPDATE supplier_returns SET 
    status = 'approved',
    approved_by = (SELECT id FROM users WHERE username = 'test_admin'),
    approved_at = CURRENT_TIMESTAMP
WHERE return_number = 'TRET-2024-001';

-- 6.3: Deduct from inventory
UPDATE inventory SET quantity = quantity - 5 
WHERE branch_id = (SELECT id FROM branches WHERE code = 'MAIN') 
AND item_id = (SELECT id FROM items WHERE code = 'ITM001');

-- 6.4: Update supplier balance (credit back)
UPDATE suppliers SET current_balance = current_balance - 375.00 WHERE code = 'TSUP001';

-- 6.5: Record transaction
INSERT INTO inventory_transactions (branch_id, item_id, operation_type, quantity, quantity_before, quantity_after, unit_cost, reference_type, created_by)
SELECT b.id, i.id, 'return', 5, 
       (SELECT quantity + 5 FROM inventory WHERE branch_id = b.id AND item_id = i.id),
       (SELECT quantity FROM inventory WHERE branch_id = b.id AND item_id = i.id),
       75.00, 'supplier_return', u.id
FROM branches b, items i, users u WHERE b.code = 'MAIN' AND i.code = 'ITM001' AND u.username = 'test_warehouse';

-- 6.6: Reject return scenario
INSERT INTO supplier_returns (return_number, supply_id, supplier_id, item_id, quantity, unit_price, total_amount, reason, description, status, registered_by, registered_at)
SELECT 'TRET-2024-002', sup.id, s.id, i.id, 2, 240.00, 480.00, 'Wrong item', 'Received wrong product', 'pending', u.id, CURRENT_TIMESTAMP
FROM supplies sup, suppliers s, items i, users u
WHERE sup.supply_number = 'TSUP-2024-001' AND s.code = 'TSUP001' AND i.code = 'ITM002' AND u.username = 'test_warehouse'
ON CONFLICT (return_number) DO NOTHING;

UPDATE supplier_returns SET 
    status = 'rejected',
    rejected_by = (SELECT id FROM users WHERE username = 'test_admin'),
    rejected_at = CURRENT_TIMESTAMP,
    rejection_reason = 'Items were correct, user error'
WHERE return_number = 'TRET-2024-002';



-- =====================================================
-- SECTION 7: TRANSFER FLOW - COMPLETE SCENARIOS
-- =====================================================

-- 7.1: Create transfer request (Main to Branch)
INSERT INTO transfers (transfer_number, from_branch_id, to_branch_id, status, priority, notes, requested_by, requested_at)
SELECT 'TTRF-2024-001', b1.id, b2.id, 'pending', 1, 'Weekly stock replenishment', u.id, CURRENT_TIMESTAMP
FROM branches b1, branches b2, users u
WHERE b1.code = 'MAIN' AND b2.code = 'BR001' AND u.username = 'test_branch_sup'
ON CONFLICT (transfer_number) DO NOTHING;

-- 7.2: Add transfer items
INSERT INTO transfer_items (transfer_id, item_id, requested_quantity, notes)
SELECT t.id, i.id, 15, 'Running low'
FROM transfers t, items i WHERE t.transfer_number = 'TTRF-2024-001' AND i.code = 'ITM001'
ON CONFLICT DO NOTHING;

INSERT INTO transfer_items (transfer_id, item_id, requested_quantity, notes)
SELECT t.id, i.id, 5, 'Weekend prep'
FROM transfers t, items i WHERE t.transfer_number = 'TTRF-2024-001' AND i.code = 'ITM002'
ON CONFLICT DO NOTHING;

-- 7.3: Approve transfer with different quantities
UPDATE transfers SET 
    status = 'approved',
    approved_by = (SELECT id FROM users WHERE username = 'test_warehouse'),
    approved_at = CURRENT_TIMESTAMP
WHERE transfer_number = 'TTRF-2024-001';

UPDATE transfer_items SET approved_quantity = 15, shipped_quantity = 15
WHERE transfer_id = (SELECT id FROM transfers WHERE transfer_number = 'TTRF-2024-001')
AND item_id = (SELECT id FROM items WHERE code = 'ITM001');

UPDATE transfer_items SET approved_quantity = 4, shipped_quantity = 4  -- Approved less than requested
WHERE transfer_id = (SELECT id FROM transfers WHERE transfer_number = 'TTRF-2024-001')
AND item_id = (SELECT id FROM items WHERE code = 'ITM002');

-- 7.4: Receive transfer
UPDATE transfers SET 
    status = 'received',
    received_by = (SELECT id FROM users WHERE username = 'test_branch_sup'),
    received_at = CURRENT_TIMESTAMP,
    shipped_at = CURRENT_TIMESTAMP
WHERE transfer_number = 'TTRF-2024-001';

UPDATE transfer_items SET received_quantity = shipped_quantity
WHERE transfer_id = (SELECT id FROM transfers WHERE transfer_number = 'TTRF-2024-001');

-- 7.5: Update inventories
UPDATE inventory SET quantity = quantity - 15 
WHERE branch_id = (SELECT id FROM branches WHERE code = 'MAIN') 
AND item_id = (SELECT id FROM items WHERE code = 'ITM001');

UPDATE inventory SET quantity = quantity - 4 
WHERE branch_id = (SELECT id FROM branches WHERE code = 'MAIN') 
AND item_id = (SELECT id FROM items WHERE code = 'ITM002');

-- Add to branch (create if not exists)
INSERT INTO inventory (branch_id, item_id, quantity, min_quantity)
SELECT b.id, i.id, 15, 10 FROM branches b, items i WHERE b.code = 'BR001' AND i.code = 'ITM001'
ON CONFLICT ON CONSTRAINT uk_inventory_branch_item DO UPDATE SET quantity = inventory.quantity + 15;

INSERT INTO inventory (branch_id, item_id, quantity, min_quantity)
SELECT b.id, i.id, 4, 5 FROM branches b, items i WHERE b.code = 'BR001' AND i.code = 'ITM002'
ON CONFLICT ON CONSTRAINT uk_inventory_branch_item DO UPDATE SET quantity = inventory.quantity + 4;

-- 7.6: Record transfer transactions
INSERT INTO inventory_transactions (branch_id, item_id, operation_type, quantity, quantity_before, quantity_after, reference_type, created_by)
SELECT b.id, i.id, 'transfer_out', 15, 
       (SELECT quantity + 15 FROM inventory WHERE branch_id = b.id AND item_id = i.id),
       (SELECT quantity FROM inventory WHERE branch_id = b.id AND item_id = i.id),
       'transfer', u.id
FROM branches b, items i, users u WHERE b.code = 'MAIN' AND i.code = 'ITM001' AND u.username = 'test_warehouse';

INSERT INTO inventory_transactions (branch_id, item_id, operation_type, quantity, quantity_before, quantity_after, reference_type, created_by)
SELECT b.id, i.id, 'transfer_in', 15, 
       (SELECT quantity - 15 FROM inventory WHERE branch_id = b.id AND item_id = i.id),
       (SELECT quantity FROM inventory WHERE branch_id = b.id AND item_id = i.id),
       'transfer', u.id
FROM branches b, items i, users u WHERE b.code = 'BR001' AND i.code = 'ITM001' AND u.username = 'test_branch_sup';

-- 7.7: Rejected transfer scenario
INSERT INTO transfers (transfer_number, from_branch_id, to_branch_id, status, priority, notes, requested_by, requested_at)
SELECT 'TTRF-2024-002', b1.id, b2.id, 'pending', 2, 'Urgent request', u.id, CURRENT_TIMESTAMP
FROM branches b1, branches b2, users u
WHERE b1.code = 'MAIN' AND b2.code = 'BR001' AND u.username = 'test_branch_sup'
ON CONFLICT (transfer_number) DO NOTHING;

INSERT INTO transfer_items (transfer_id, item_id, requested_quantity, notes)
SELECT t.id, i.id, 100, 'Large quantity needed'
FROM transfers t, items i WHERE t.transfer_number = 'TTRF-2024-002' AND i.code = 'ITM001'
ON CONFLICT DO NOTHING;

UPDATE transfers SET 
    status = 'rejected',
    notes = 'Insufficient stock in warehouse'
WHERE transfer_number = 'TTRF-2024-002';

-- 7.8: Cancelled transfer scenario
INSERT INTO transfers (transfer_number, from_branch_id, to_branch_id, status, priority, notes, requested_by, requested_at)
SELECT 'TTRF-2024-003', b1.id, b2.id, 'pending', 1, 'Test cancellation', u.id, CURRENT_TIMESTAMP
FROM branches b1, branches b2, users u
WHERE b1.code = 'MAIN' AND b2.code = 'BR001' AND u.username = 'test_branch_sup'
ON CONFLICT (transfer_number) DO NOTHING;

UPDATE transfers SET status = 'cancelled' WHERE transfer_number = 'TTRF-2024-003';

-- 7.9: Partial receive scenario
INSERT INTO transfers (transfer_number, from_branch_id, to_branch_id, status, priority, notes, requested_by, requested_at)
SELECT 'TTRF-2024-004', b1.id, b2.id, 'pending', 1, 'Partial receive test', u.id, CURRENT_TIMESTAMP
FROM branches b1, branches b2, users u
WHERE b1.code = 'MAIN' AND b2.code = 'BR001' AND u.username = 'test_branch_sup'
ON CONFLICT (transfer_number) DO NOTHING;

INSERT INTO transfer_items (transfer_id, item_id, requested_quantity, notes)
SELECT t.id, i.id, 20, NULL
FROM transfers t, items i WHERE t.transfer_number = 'TTRF-2024-004' AND i.code = 'ITM001'
ON CONFLICT DO NOTHING;

UPDATE transfers SET status = 'approved', approved_by = (SELECT id FROM users WHERE username = 'test_warehouse'), approved_at = CURRENT_TIMESTAMP
WHERE transfer_number = 'TTRF-2024-004';

UPDATE transfer_items SET approved_quantity = 20, shipped_quantity = 20
WHERE transfer_id = (SELECT id FROM transfers WHERE transfer_number = 'TTRF-2024-004');

-- Received only 18 (2 damaged in transit)
UPDATE transfers SET status = 'received', received_by = (SELECT id FROM users WHERE username = 'test_branch_sup'), received_at = CURRENT_TIMESTAMP
WHERE transfer_number = 'TTRF-2024-004';

UPDATE transfer_items SET received_quantity = 18
WHERE transfer_id = (SELECT id FROM transfers WHERE transfer_number = 'TTRF-2024-004');

-- =====================================================
-- SECTION 8: BRANCH RETURN FLOW
-- =====================================================

-- 8.1: Create branch return (near expiry items)
INSERT INTO branch_returns (return_number, return_date, from_branch_id, to_branch_id, status, return_reason, notes, requested_by, requested_at)
SELECT 'TBRT-2024-001', CURRENT_DATE, fb.id, tb.id, 'pending', 
       'Near expiry items',
       'Items expiring within 3 days',
       u.id, CURRENT_TIMESTAMP
FROM branches fb, branches tb, users u
WHERE fb.code = 'BR001' AND tb.code = 'MAIN' AND u.username = 'test_branch_sup'
ON CONFLICT (return_number) DO NOTHING;

-- 8.2: Add return items
INSERT INTO branch_return_items (return_id, item_id, requested_quantity, unit_cost, total_value, item_reason)
SELECT br.id, i.id, 3, 240.00, 720.00, 'Expiring in 2 days'
FROM branch_returns br, items i 
WHERE br.return_number = 'TBRT-2024-001' AND i.code = 'ITM002'
ON CONFLICT ON CONSTRAINT uk_return_item DO NOTHING;

-- 8.3: Approve return
UPDATE branch_returns SET 
    status = 'approved',
    approved_by = (SELECT id FROM users WHERE username = 'test_warehouse'),
    approved_at = CURRENT_TIMESTAMP
WHERE return_number = 'TBRT-2024-001';

UPDATE branch_return_items SET approved_quantity = requested_quantity
WHERE return_id = (SELECT id FROM branch_returns WHERE return_number = 'TBRT-2024-001');

-- 8.4: Ship return
UPDATE branch_returns SET 
    status = 'in_transit',
    shipped_at = CURRENT_TIMESTAMP
WHERE return_number = 'TBRT-2024-001';

UPDATE branch_return_items SET shipped_quantity = approved_quantity
WHERE return_id = (SELECT id FROM branch_returns WHERE return_number = 'TBRT-2024-001');

-- 8.5: Receive return
UPDATE branch_returns SET 
    status = 'received',
    received_by = (SELECT id FROM users WHERE username = 'test_warehouse'),
    received_at = CURRENT_TIMESTAMP
WHERE return_number = 'TBRT-2024-001';

UPDATE branch_return_items SET received_quantity = shipped_quantity
WHERE return_id = (SELECT id FROM branch_returns WHERE return_number = 'TBRT-2024-001');

-- 8.6: Update inventories
UPDATE inventory SET quantity = quantity - 3 
WHERE branch_id = (SELECT id FROM branches WHERE code = 'BR001') 
AND item_id = (SELECT id FROM items WHERE code = 'ITM002');

UPDATE inventory SET quantity = quantity + 3 
WHERE branch_id = (SELECT id FROM branches WHERE code = 'MAIN') 
AND item_id = (SELECT id FROM items WHERE code = 'ITM002');

-- 8.7: Rejected branch return
INSERT INTO branch_returns (return_number, return_date, from_branch_id, to_branch_id, status, return_reason, notes, requested_by, requested_at)
SELECT 'TBRT-2024-002', CURRENT_DATE, fb.id, tb.id, 'pending', 
       'Excess stock',
       'Too much inventory',
       u.id, CURRENT_TIMESTAMP
FROM branches fb, branches tb, users u
WHERE fb.code = 'BR001' AND tb.code = 'MAIN' AND u.username = 'test_branch_sup'
ON CONFLICT (return_number) DO NOTHING;

UPDATE branch_returns SET 
    status = 'rejected',
    rejected_by = (SELECT id FROM users WHERE username = 'test_warehouse'),
    rejected_at = CURRENT_TIMESTAMP,
    rejection_reason = 'Warehouse at full capacity'
WHERE return_number = 'TBRT-2024-002';

-- =====================================================
-- SECTION 9: DAMAGE FLOW - COMPLETE SCENARIOS
-- =====================================================

-- 9.1: Register damage (expired)
INSERT INTO damages (damage_number, branch_id, item_id, quantity, unit_cost, total_cost, reason_id, description, status, registered_by, registered_at)
SELECT 'TDMG-2024-001', b.id, i.id, 3, 240.00, 720.00, dr.id, 'Found expired during morning check', 'pending', u.id, CURRENT_TIMESTAMP
FROM branches b, items i, damage_reasons dr, users u
WHERE b.code = 'BR001' AND i.code = 'ITM002' AND dr.code = 'EXPIRED' AND u.username = 'test_branch_sup'
ON CONFLICT (damage_number) DO NOTHING;

-- 9.2: Approve damage
UPDATE damages SET 
    status = 'approved',
    approved_by = (SELECT id FROM users WHERE username = 'test_admin'),
    approved_at = CURRENT_TIMESTAMP
WHERE damage_number = 'TDMG-2024-001';

-- 9.3: Deduct from inventory
UPDATE inventory SET quantity = quantity - 3 
WHERE branch_id = (SELECT id FROM branches WHERE code = 'BR001') 
AND item_id = (SELECT id FROM items WHERE code = 'ITM002');

-- 9.4: Record transaction
INSERT INTO inventory_transactions (branch_id, item_id, operation_type, quantity, quantity_before, quantity_after, unit_cost, reference_type, created_by)
SELECT b.id, i.id, 'damage', 3, 
       (SELECT quantity + 3 FROM inventory WHERE branch_id = b.id AND item_id = i.id),
       (SELECT quantity FROM inventory WHERE branch_id = b.id AND item_id = i.id),
       240.00, 'damage', u.id
FROM branches b, items i, users u WHERE b.code = 'BR001' AND i.code = 'ITM002' AND u.username = 'test_branch_sup';

-- 9.5: Register damage (storage issue)
INSERT INTO damages (damage_number, branch_id, item_id, quantity, unit_cost, total_cost, reason_id, description, status, registered_by, registered_at)
SELECT 'TDMG-2024-002', b.id, i.id, 5, 75.00, 375.00, dr.id, 'Refrigerator malfunction overnight', 'pending', u.id, CURRENT_TIMESTAMP
FROM branches b, items i, damage_reasons dr, users u
WHERE b.code = 'BR001' AND i.code = 'ITM001' AND dr.code = 'STORAGE' AND u.username = 'test_branch_sup'
ON CONFLICT (damage_number) DO NOTHING;

-- 9.6: Rejected damage
INSERT INTO damages (damage_number, branch_id, item_id, quantity, unit_cost, total_cost, reason_id, description, status, registered_by, registered_at)
SELECT 'TDMG-2024-003', b.id, i.id, 10, 75.00, 750.00, dr.id, 'Claimed spoiled', 'pending', u.id, CURRENT_TIMESTAMP
FROM branches b, items i, damage_reasons dr, users u
WHERE b.code = 'BR001' AND i.code = 'ITM001' AND dr.code = 'SPOILED' AND u.username = 'test_branch_sup'
ON CONFLICT (damage_number) DO NOTHING;

UPDATE damages SET 
    status = 'rejected',
    rejected_by = (SELECT id FROM users WHERE username = 'test_admin'),
    rejected_at = CURRENT_TIMESTAMP,
    rejection_reason = 'Items inspected and found to be in good condition'
WHERE damage_number = 'TDMG-2024-003';

-- 9.7: Damage with image
INSERT INTO damages (damage_number, branch_id, item_id, quantity, unit_cost, total_cost, reason_id, description, image_url, status, registered_by, registered_at)
SELECT 'TDMG-2024-004', b.id, i.id, 2, 75.00, 150.00, dr.id, 'Physical damage during handling', 'https://storage.example.com/damages/tdmg-2024-004.jpg', 'pending', u.id, CURRENT_TIMESTAMP
FROM branches b, items i, damage_reasons dr, users u
WHERE b.code = 'MAIN' AND i.code = 'ITM001' AND dr.code = 'HANDLING' AND u.username = 'test_warehouse'
ON CONFLICT (damage_number) DO NOTHING;



-- =====================================================
-- SECTION 10: POS ORDER FLOW - COMPLETE SCENARIOS
-- =====================================================

-- 10.1: Create new order (dine-in)
INSERT INTO orders (order_number, branch_id, order_type, customer_name, customer_phone, subtotal, tax_amount, total_amount, status, cashier_id, created_at)
SELECT 'TORD-2024-001', b.id, 'dine_in', 'Test Customer 1', '01000000400', 200.00, 28.00, 228.00, 'new', u.id, CURRENT_TIMESTAMP
FROM branches b, users u WHERE b.code = 'BR001' AND u.username = 'test_cashier'
ON CONFLICT (order_number) DO NOTHING;

-- 10.2: Add order items
INSERT INTO order_items (order_id, menu_item_id, quantity, unit_price, total_price, status, notes)
SELECT o.id, mi.id, 2, 85.00, 170.00, 'pending', 'Extra spicy'
FROM orders o, menu_items mi WHERE o.order_number = 'TORD-2024-001' AND mi.code = 'MENU001'
ON CONFLICT DO NOTHING;

INSERT INTO order_items (order_id, menu_item_id, quantity, unit_price, total_price, status, notes)
SELECT o.id, mi.id, 2, 15.00, 30.00, 'pending', NULL
FROM orders o, menu_items mi WHERE o.order_number = 'TORD-2024-001' AND mi.code = 'MENU004'
ON CONFLICT DO NOTHING;

-- 10.3: Process payment (cash)
UPDATE orders SET 
    payment_method = 'cash',
    status = 'paid',
    paid_at = CURRENT_TIMESTAMP
WHERE order_number = 'TORD-2024-001';

-- 10.4: Send to kitchen
UPDATE orders SET 
    status = 'in_kitchen',
    sent_to_kitchen_at = CURRENT_TIMESTAMP,
    chef_id = (SELECT id FROM users WHERE username = 'test_chef')
WHERE order_number = 'TORD-2024-001';

UPDATE order_items SET status = 'in_kitchen'
WHERE order_id = (SELECT id FROM orders WHERE order_number = 'TORD-2024-001');

-- 10.5: Start preparation
UPDATE orders SET 
    status = 'preparing',
    preparation_started_at = CURRENT_TIMESTAMP
WHERE order_number = 'TORD-2024-001';

UPDATE order_items SET status = 'preparing'
WHERE order_id = (SELECT id FROM orders WHERE order_number = 'TORD-2024-001');

-- 10.6: Ready
UPDATE orders SET 
    status = 'ready',
    ready_at = CURRENT_TIMESTAMP
WHERE order_number = 'TORD-2024-001';

UPDATE order_items SET status = 'ready'
WHERE order_id = (SELECT id FROM orders WHERE order_number = 'TORD-2024-001');

-- 10.7: Delivered
UPDATE orders SET 
    status = 'delivered',
    delivered_at = CURRENT_TIMESTAMP
WHERE order_number = 'TORD-2024-001';

UPDATE order_items SET status = 'delivered'
WHERE order_id = (SELECT id FROM orders WHERE order_number = 'TORD-2024-001');

-- 10.8: Record consumption
INSERT INTO inventory_transactions (branch_id, item_id, operation_type, quantity, quantity_before, quantity_after, reference_type, created_by)
SELECT b.id, i.id, 'consumption', 0.5, 
       (SELECT quantity + 0.5 FROM inventory WHERE branch_id = b.id AND item_id = i.id),
       (SELECT quantity FROM inventory WHERE branch_id = b.id AND item_id = i.id),
       'order', u.id
FROM branches b, items i, users u WHERE b.code = 'BR001' AND i.code = 'ITM001' AND u.username = 'test_cashier';

-- 10.9: Takeaway order with visa payment
INSERT INTO orders (order_number, branch_id, order_type, customer_name, customer_phone, subtotal, tax_amount, total_amount, status, cashier_id, created_at)
SELECT 'TORD-2024-002', b.id, 'takeaway', 'Test Customer 2', '01000000401', 120.00, 16.80, 136.80, 'new', u.id, CURRENT_TIMESTAMP
FROM branches b, users u WHERE b.code = 'BR001' AND u.username = 'test_cashier'
ON CONFLICT (order_number) DO NOTHING;

INSERT INTO order_items (order_id, menu_item_id, quantity, unit_price, total_price, status)
SELECT o.id, mi.id, 1, 120.00, 120.00, 'pending'
FROM orders o, menu_items mi WHERE o.order_number = 'TORD-2024-002' AND mi.code = 'MENU002'
ON CONFLICT DO NOTHING;

UPDATE orders SET payment_method = 'visa', status = 'paid', paid_at = CURRENT_TIMESTAMP WHERE order_number = 'TORD-2024-002';
UPDATE orders SET status = 'in_kitchen', sent_to_kitchen_at = CURRENT_TIMESTAMP WHERE order_number = 'TORD-2024-002';
UPDATE orders SET status = 'preparing', preparation_started_at = CURRENT_TIMESTAMP WHERE order_number = 'TORD-2024-002';
UPDATE orders SET status = 'ready', ready_at = CURRENT_TIMESTAMP WHERE order_number = 'TORD-2024-002';
UPDATE orders SET status = 'delivered', delivered_at = CURRENT_TIMESTAMP WHERE order_number = 'TORD-2024-002';

-- 10.10: Cancelled order
INSERT INTO orders (order_number, branch_id, order_type, customer_name, subtotal, tax_amount, total_amount, status, cashier_id, created_at)
SELECT 'TORD-2024-003', b.id, 'dine_in', 'Test Customer 3', 85.00, 11.90, 96.90, 'new', u.id, CURRENT_TIMESTAMP
FROM branches b, users u WHERE b.code = 'BR001' AND u.username = 'test_cashier'
ON CONFLICT (order_number) DO NOTHING;

INSERT INTO order_items (order_id, menu_item_id, quantity, unit_price, total_price, status)
SELECT o.id, mi.id, 1, 85.00, 85.00, 'pending'
FROM orders o, menu_items mi WHERE o.order_number = 'TORD-2024-003' AND mi.code = 'MENU001'
ON CONFLICT DO NOTHING;

UPDATE orders SET status = 'cancelled' WHERE order_number = 'TORD-2024-003';

-- 10.11: Order with discount
INSERT INTO orders (order_number, branch_id, order_type, customer_name, subtotal, discount_amount, tax_amount, total_amount, status, cashier_id, created_at)
SELECT 'TORD-2024-004', b.id, 'dine_in', 'VIP Customer', 300.00, 30.00, 37.80, 307.80, 'new', u.id, CURRENT_TIMESTAMP
FROM branches b, users u WHERE b.code = 'BR001' AND u.username = 'test_cashier'
ON CONFLICT (order_number) DO NOTHING;

-- 10.12: Delivery order
INSERT INTO orders (order_number, branch_id, order_type, customer_name, customer_phone, customer_address, subtotal, delivery_fee, tax_amount, total_amount, status, cashier_id, created_at)
SELECT 'TORD-2024-005', b.id, 'delivery', 'Delivery Customer', '01000000402', '123 Test Street, Cairo', 200.00, 20.00, 30.80, 250.80, 'new', u.id, CURRENT_TIMESTAMP
FROM branches b, users u WHERE b.code = 'BR001' AND u.username = 'test_cashier'
ON CONFLICT (order_number) DO NOTHING;

-- 10.13: Instapay payment
INSERT INTO orders (order_number, branch_id, order_type, customer_name, subtotal, tax_amount, total_amount, status, cashier_id, created_at)
SELECT 'TORD-2024-006', b.id, 'dine_in', 'Instapay Customer', 150.00, 21.00, 171.00, 'new', u.id, CURRENT_TIMESTAMP
FROM branches b, users u WHERE b.code = 'BR001' AND u.username = 'test_cashier'
ON CONFLICT (order_number) DO NOTHING;

UPDATE orders SET payment_method = 'instapay', status = 'paid', paid_at = CURRENT_TIMESTAMP WHERE order_number = 'TORD-2024-006';

-- =====================================================
-- SECTION 11: DAILY INVENTORY COUNT FLOW
-- =====================================================

-- 11.1: Create opening count
INSERT INTO daily_inventory_counts (branch_id, count_date, count_type, status, notes, counted_by, submitted_at)
SELECT b.id, CURRENT_DATE, 'opening', 'submitted', 'Morning inventory count', u.id, CURRENT_TIMESTAMP
FROM branches b, users u
WHERE b.code = 'BR001' AND u.username = 'test_branch_sup'
ON CONFLICT DO NOTHING;

-- 11.2: Add count items
INSERT INTO daily_inventory_count_items (count_id, item_id, system_quantity, actual_quantity, variance_reason)
SELECT dic.id, i.id, 
       (SELECT COALESCE(quantity, 0) FROM inventory WHERE branch_id = dic.branch_id AND item_id = i.id),
       (SELECT COALESCE(quantity, 0) FROM inventory WHERE branch_id = dic.branch_id AND item_id = i.id),
       NULL
FROM daily_inventory_counts dic, items i, branches b
WHERE dic.branch_id = b.id AND b.code = 'BR001' AND dic.count_type = 'opening' AND dic.count_date = CURRENT_DATE AND i.code = 'ITM001'
ON CONFLICT DO NOTHING;

INSERT INTO daily_inventory_count_items (count_id, item_id, system_quantity, actual_quantity, variance_reason)
SELECT dic.id, i.id, 
       (SELECT COALESCE(quantity, 0) FROM inventory WHERE branch_id = dic.branch_id AND item_id = i.id),
       (SELECT COALESCE(quantity, 0) FROM inventory WHERE branch_id = dic.branch_id AND item_id = i.id) - 0.5,
       'Minor variance - possible measurement error'
FROM daily_inventory_counts dic, items i, branches b
WHERE dic.branch_id = b.id AND b.code = 'BR001' AND dic.count_type = 'opening' AND dic.count_date = CURRENT_DATE AND i.code = 'ITM002'
ON CONFLICT DO NOTHING;

-- 11.3: Create closing count
INSERT INTO daily_inventory_counts (branch_id, count_date, count_type, status, notes, counted_by, submitted_at)
SELECT b.id, CURRENT_DATE, 'closing', 'submitted', 'End of day count', u.id, CURRENT_TIMESTAMP
FROM branches b, users u
WHERE b.code = 'BR001' AND u.username = 'test_branch_sup'
ON CONFLICT DO NOTHING;

-- 11.4: Add closing count items (after day's consumption)
INSERT INTO daily_inventory_count_items (count_id, item_id, system_quantity, actual_quantity, variance_reason)
SELECT dic.id, i.id, 
       (SELECT COALESCE(quantity, 0) FROM inventory WHERE branch_id = dic.branch_id AND item_id = i.id),
       (SELECT COALESCE(quantity, 0) FROM inventory WHERE branch_id = dic.branch_id AND item_id = i.id) - 2,
       'Day consumption'
FROM daily_inventory_counts dic, items i, branches b
WHERE dic.branch_id = b.id AND b.code = 'BR001' AND dic.count_type = 'closing' AND dic.count_date = CURRENT_DATE AND i.code = 'ITM001'
ON CONFLICT DO NOTHING;

-- 11.5: Approve count
UPDATE daily_inventory_counts SET 
    status = 'approved',
    approved_by = (SELECT id FROM users WHERE username = 'test_admin'),
    approved_at = CURRENT_TIMESTAMP
WHERE branch_id = (SELECT id FROM branches WHERE code = 'BR001') 
AND count_date = CURRENT_DATE AND count_type = 'opening';

-- =====================================================
-- SECTION 12: PURCHASE REQUEST FLOW
-- =====================================================

-- 12.1: Create purchase request
INSERT INTO purchase_requests (request_number, request_date, branch_id, status, priority, notes, requested_by, requested_at)
SELECT 'TPR-2024-001', CURRENT_DATE, b.id, 'draft', 2, 'Weekly stock replenishment', u.id, CURRENT_TIMESTAMP
FROM branches b, users u
WHERE b.code = 'MAIN' AND u.username = 'test_purchase'
ON CONFLICT (request_number) DO NOTHING;

-- 12.2: Add request items
INSERT INTO purchase_request_items (request_id, item_id, requested_quantity, estimated_unit_price, supplier_id, notes)
SELECT pr.id, i.id, 100, 75.00, s.id, 'Weekly chicken order'
FROM purchase_requests pr, items i, suppliers s
WHERE pr.request_number = 'TPR-2024-001' AND i.code = 'ITM001' AND s.code = 'TSUP001'
ON CONFLICT DO NOTHING;

INSERT INTO purchase_request_items (request_id, item_id, requested_quantity, estimated_unit_price, supplier_id, notes)
SELECT pr.id, i.id, 50, 240.00, s.id, 'Beef for weekend'
FROM purchase_requests pr, items i, suppliers s
WHERE pr.request_number = 'TPR-2024-001' AND i.code = 'ITM002' AND s.code = 'TSUP001'
ON CONFLICT DO NOTHING;

-- 12.3: Update totals
UPDATE purchase_requests SET 
    total_items = 2,
    total_quantity = 150,
    estimated_cost = 19500.00
WHERE request_number = 'TPR-2024-001';

-- 12.4: Submit request
UPDATE purchase_requests SET status = 'pending' WHERE request_number = 'TPR-2024-001';

-- 12.5: Approve request
UPDATE purchase_requests SET 
    status = 'approved',
    approved_by = (SELECT id FROM users WHERE username = 'test_admin'),
    approved_at = CURRENT_TIMESTAMP
WHERE request_number = 'TPR-2024-001';

-- 12.6: Rejected request scenario
INSERT INTO purchase_requests (request_number, request_date, branch_id, status, priority, notes, requested_by, requested_at)
SELECT 'TPR-2024-002', CURRENT_DATE, b.id, 'pending', 1, 'Urgent request', u.id, CURRENT_TIMESTAMP
FROM branches b, users u
WHERE b.code = 'MAIN' AND u.username = 'test_purchase'
ON CONFLICT (request_number) DO NOTHING;

UPDATE purchase_requests SET 
    status = 'rejected',
    notes = 'Budget exceeded for this month'
WHERE request_number = 'TPR-2024-002';

-- =====================================================
-- SECTION 13: PURCHASE ORDER FLOW
-- =====================================================

-- 13.1: Create purchase order from approved request
INSERT INTO purchase_orders (order_number, order_date, supplier_id, branch_id, request_id, status, priority, notes, created_by, created_at)
SELECT 'TPO-2024-001', CURRENT_DATE, s.id, b.id, pr.id, 'draft', 2, 'Order from PR-2024-001', u.id, CURRENT_TIMESTAMP
FROM suppliers s, branches b, purchase_requests pr, users u
WHERE s.code = 'TSUP001' AND b.code = 'MAIN' AND pr.request_number = 'TPR-2024-001' AND u.username = 'test_purchase'
ON CONFLICT (order_number) DO NOTHING;

-- 13.2: Add order items
INSERT INTO purchase_order_items (order_id, item_id, ordered_quantity, unit_price, total_price, notes)
SELECT po.id, i.id, 100, 75.00, 7500.00, 'Chicken breast'
FROM purchase_orders po, items i
WHERE po.order_number = 'TPO-2024-001' AND i.code = 'ITM001'
ON CONFLICT DO NOTHING;

INSERT INTO purchase_order_items (order_id, item_id, ordered_quantity, unit_price, total_price, notes)
SELECT po.id, i.id, 50, 240.00, 12000.00, 'Beef meat'
FROM purchase_orders po, items i
WHERE po.order_number = 'TPO-2024-001' AND i.code = 'ITM002'
ON CONFLICT DO NOTHING;

-- 13.3: Update totals
UPDATE purchase_orders SET 
    total_items = 2,
    total_quantity = 150,
    subtotal = 19500.00,
    tax_amount = 2730.00,
    total_amount = 22230.00
WHERE order_number = 'TPO-2024-001';

-- 13.4: Submit order
UPDATE purchase_orders SET status = 'pending' WHERE order_number = 'TPO-2024-001';

-- 13.5: Approve order
UPDATE purchase_orders SET 
    status = 'approved',
    approved_by = (SELECT id FROM users WHERE username = 'test_admin'),
    approved_at = CURRENT_TIMESTAMP
WHERE order_number = 'TPO-2024-001';

-- 13.6: Send to supplier
UPDATE purchase_orders SET 
    status = 'sent',
    sent_at = CURRENT_TIMESTAMP
WHERE order_number = 'TPO-2024-001';

-- 13.7: Partially received
UPDATE purchase_orders SET status = 'partially_received' WHERE order_number = 'TPO-2024-001';

UPDATE purchase_order_items SET received_quantity = 80  -- Received 80 of 100
WHERE order_id = (SELECT id FROM purchase_orders WHERE order_number = 'TPO-2024-001')
AND item_id = (SELECT id FROM items WHERE code = 'ITM001');

-- 13.8: Fully received
UPDATE purchase_order_items SET received_quantity = 100
WHERE order_id = (SELECT id FROM purchase_orders WHERE order_number = 'TPO-2024-001')
AND item_id = (SELECT id FROM items WHERE code = 'ITM001');

UPDATE purchase_order_items SET received_quantity = 50
WHERE order_id = (SELECT id FROM purchase_orders WHERE order_number = 'TPO-2024-001')
AND item_id = (SELECT id FROM items WHERE code = 'ITM002');

UPDATE purchase_orders SET 
    status = 'completed',
    received_at = CURRENT_TIMESTAMP
WHERE order_number = 'TPO-2024-001';

-- Update purchase request status
UPDATE purchase_requests SET status = 'completed' WHERE request_number = 'TPR-2024-001';



-- =====================================================
-- SECTION 14: INVENTORY MANAGEMENT EDGE CASES
-- =====================================================

-- 14.1: Low stock alert scenario
UPDATE inventory SET quantity = 5, min_quantity = 50 
WHERE branch_id = (SELECT id FROM branches WHERE code = 'BR001') 
AND item_id = (SELECT id FROM items WHERE code = 'ITM001');

-- 14.2: Out of stock scenario
UPDATE inventory SET quantity = 0 
WHERE branch_id = (SELECT id FROM branches WHERE code = 'TEST01') 
AND item_id = (SELECT id FROM items WHERE code = 'ITM001');

-- 14.3: Negative stock prevention (should be handled by app)
-- This tests the constraint
-- UPDATE inventory SET quantity = -5 WHERE ... -- Should fail

-- 14.4: Batch tracking with expiry
INSERT INTO inventory_batches (inventory_id, batch_number, quantity, remaining_quantity, purchase_price, expiry_date, received_date)
SELECT inv.id, 'TBATCH-EXP-001', 20, 15, 75.00, CURRENT_DATE + INTERVAL '2 days', CURRENT_DATE - INTERVAL '5 days'
FROM inventory inv
JOIN branches b ON inv.branch_id = b.id
JOIN items i ON inv.item_id = i.id
WHERE b.code = 'BR001' AND i.code = 'ITM001';

-- 14.5: Multiple batches for same item
INSERT INTO inventory_batches (inventory_id, batch_number, quantity, remaining_quantity, purchase_price, expiry_date, received_date)
SELECT inv.id, 'TBATCH-EXP-002', 30, 30, 78.00, CURRENT_DATE + INTERVAL '10 days', CURRENT_DATE
FROM inventory inv
JOIN branches b ON inv.branch_id = b.id
JOIN items i ON inv.item_id = i.id
WHERE b.code = 'BR001' AND i.code = 'ITM001';

-- 14.6: Inventory adjustment
INSERT INTO inventory_transactions (branch_id, item_id, operation_type, quantity, quantity_before, quantity_after, notes, reference_type, created_by)
SELECT b.id, i.id, 'adjustment', 5, 
       (SELECT quantity FROM inventory WHERE branch_id = b.id AND item_id = i.id),
       (SELECT quantity FROM inventory WHERE branch_id = b.id AND item_id = i.id) + 5,
       'Physical count adjustment', 'adjustment', u.id
FROM branches b, items i, users u WHERE b.code = 'BR001' AND i.code = 'ITM001' AND u.username = 'test_branch_sup';

UPDATE inventory SET quantity = quantity + 5 
WHERE branch_id = (SELECT id FROM branches WHERE code = 'BR001') 
AND item_id = (SELECT id FROM items WHERE code = 'ITM001');

-- =====================================================
-- SECTION 15: NOTIFICATIONS
-- =====================================================

-- 15.1: Low stock notification
INSERT INTO notifications (user_id, branch_id, type, title, message, priority, reference_type, is_read)
SELECT u.id, b.id, 'low_stock', 'تنبيه نقص المخزون', 
       'صدور دجاج في الفرع 1 منخفض جداً (5 كجم فقط)', 
       'high', 'inventory', FALSE
FROM users u, branches b WHERE u.username = 'test_branch_sup' AND b.code = 'BR001';

-- 15.2: Transfer notification
INSERT INTO notifications (user_id, branch_id, type, title, message, priority, reference_type, is_read)
SELECT u.id, b.id, 'transfer_received', 'تم استلام التحويل', 
       'تم استلام التحويل TTRF-2024-001 بنجاح', 
       'normal', 'transfer', FALSE
FROM users u, branches b WHERE u.username = 'test_warehouse' AND b.code = 'MAIN';

-- 15.3: Damage approval notification
INSERT INTO notifications (user_id, branch_id, type, title, message, priority, reference_type, is_read)
SELECT u.id, b.id, 'pending_approval', 'طلب موافقة على تالف', 
       'يوجد طلب تالف جديد TDMG-2024-002 بانتظار الموافقة', 
       'high', 'damage', FALSE
FROM users u, branches b WHERE u.username = 'test_admin' AND b.code = 'MAIN';

-- 15.4: Purchase request notification
INSERT INTO notifications (user_id, branch_id, type, title, message, priority, reference_type, is_read)
SELECT u.id, b.id, 'pending_approval', 'تمت الموافقة على طلب الشراء', 
       'تمت الموافقة على طلب الشراء TPR-2024-001', 
       'normal', 'purchase_request', FALSE
FROM users u, branches b WHERE u.username = 'test_purchase' AND b.code = 'MAIN';

-- 15.5: Order ready notification
INSERT INTO notifications (user_id, branch_id, type, title, message, priority, reference_type, is_read)
SELECT u.id, b.id, 'order_ready', 'الطلب جاهز', 
       'الطلب TORD-2024-001 جاهز للتسليم', 
       'normal', 'order', FALSE
FROM users u, branches b WHERE u.username = 'test_cashier' AND b.code = 'BR001';

-- 15.6: Expiry warning notification
INSERT INTO notifications (user_id, branch_id, type, title, message, priority, reference_type, is_read)
SELECT u.id, b.id, 'expiry_warning', 'تحذير انتهاء صلاحية', 
       'يوجد منتجات ستنتهي صلاحيتها خلال يومين', 
       'high', 'inventory', FALSE
FROM users u, branches b WHERE u.username = 'test_branch_sup' AND b.code = 'BR001';

-- 15.7: Mark notification as read
UPDATE notifications SET is_read = TRUE, read_at = CURRENT_TIMESTAMP
WHERE type = 'transfer_received' AND user_id = (SELECT id FROM users WHERE username = 'test_warehouse');

-- =====================================================
-- SECTION 16: AUDIT LOGS
-- =====================================================

-- 16.1: Supply creation audit
INSERT INTO audit_logs (user_id, action, table_name, new_values, ip_address)
SELECT u.id, 'CREATE', 'supplies',
       '{"supply_number": "TSUP-2024-001", "supplier": "TSUP001", "total": 5700}'::jsonb,
       '192.168.1.100'
FROM users u WHERE u.username = 'test_warehouse';

-- 16.2: Transfer status change audit
INSERT INTO audit_logs (user_id, action, table_name, old_values, new_values, ip_address)
SELECT u.id, 'UPDATE', 'transfers',
       '{"status": "pending"}'::jsonb,
       '{"status": "received", "transfer_number": "TTRF-2024-001"}'::jsonb,
       '192.168.1.100'
FROM users u WHERE u.username = 'test_warehouse';

-- 16.3: Damage approval audit
INSERT INTO audit_logs (user_id, action, table_name, old_values, new_values, ip_address)
SELECT u.id, 'UPDATE', 'damages',
       '{"status": "pending"}'::jsonb,
       '{"status": "approved", "damage_number": "TDMG-2024-001"}'::jsonb,
       '192.168.1.100'
FROM users u WHERE u.username = 'test_admin';

-- 16.4: Order completion audit
INSERT INTO audit_logs (user_id, action, table_name, old_values, new_values, ip_address)
SELECT u.id, 'UPDATE', 'orders',
       '{"status": "ready"}'::jsonb,
       '{"status": "delivered", "order_number": "TORD-2024-001"}'::jsonb,
       '192.168.1.101'
FROM users u WHERE u.username = 'test_cashier';

-- 16.5: Supplier payment audit
INSERT INTO audit_logs (user_id, action, table_name, new_values, ip_address)
SELECT u.id, 'CREATE', 'supplier_payments',
       '{"payment_number": "TPAY-2024-001", "amount": 1500, "supplier": "TSUP001"}'::jsonb,
       '192.168.1.100'
FROM users u WHERE u.username = 'test_admin';

-- 16.6: User login audit
INSERT INTO audit_logs (user_id, action, table_name, new_values, ip_address, user_agent)
SELECT u.id, 'LOGIN', 'users',
       '{"username": "test_admin"}'::jsonb,
       '192.168.1.100',
       'Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/120.0.0.0'
FROM users u WHERE u.username = 'test_admin';

-- =====================================================
-- SECTION 17: REPORTS DATA VERIFICATION
-- =====================================================

-- 17.1: Sales report data
SELECT 
    COUNT(*) as total_orders,
    SUM(total_amount) as total_revenue,
    AVG(total_amount) as avg_order_value,
    COUNT(CASE WHEN status = 'delivered' THEN 1 END) as delivered_orders,
    COUNT(CASE WHEN status = 'cancelled' THEN 1 END) as cancelled_orders
FROM orders
WHERE order_number LIKE 'TORD%';

-- 17.2: Inventory report data
SELECT 
    b.name_ar as branch,
    i.name_ar as item,
    inv.quantity,
    inv.min_quantity,
    CASE WHEN inv.quantity < inv.min_quantity THEN 'Low Stock' ELSE 'OK' END as status
FROM inventory inv
JOIN branches b ON inv.branch_id = b.id
JOIN items i ON inv.item_id = i.id
WHERE b.code IN ('MAIN', 'BR001', 'TEST01')
ORDER BY inv.quantity ASC;

-- 17.3: Supplier balance report
SELECT 
    code,
    name_ar,
    current_balance,
    credit_limit,
    CASE WHEN current_balance > credit_limit THEN 'Over Limit' ELSE 'OK' END as status
FROM suppliers
WHERE code LIKE 'TSUP%';

-- 17.4: Transfer summary
SELECT 
    status,
    COUNT(*) as count
FROM transfers
WHERE transfer_number LIKE 'TTRF%'
GROUP BY status;

-- 17.5: Damage summary
SELECT 
    status,
    COUNT(*) as count,
    SUM(total_cost) as total_value
FROM damages
WHERE damage_number LIKE 'TDMG%'
GROUP BY status;

-- =====================================================
-- SECTION 18: EDGE CASES & ERROR SCENARIOS
-- =====================================================

-- 18.1: Duplicate code prevention (should fail on conflict)
-- INSERT INTO suppliers (code, name, ...) VALUES ('TSUP001', ...) -- Should fail

-- 18.2: Self-transfer prevention (constraint check)
-- INSERT INTO transfers (from_branch_id, to_branch_id, ...) 
-- SELECT b.id, b.id, ... FROM branches b WHERE b.code = 'MAIN' -- Should fail

-- 18.3: Negative quantity prevention
-- UPDATE inventory SET quantity = -10 WHERE ... -- Should fail if constraint exists

-- 18.4: Invalid status transition (app should handle)
-- UPDATE orders SET status = 'delivered' WHERE status = 'new' -- Should be prevented by app

-- 18.5: Payment exceeding balance
-- This should be handled by the application logic

-- =====================================================
-- SECTION 19: CLEANUP QUERIES (Optional)
-- =====================================================

-- To clean up test data, uncomment and run:
/*
DELETE FROM audit_logs WHERE user_id IN (SELECT id FROM users WHERE username LIKE 'test_%');
DELETE FROM notifications WHERE user_id IN (SELECT id FROM users WHERE username LIKE 'test_%');
DELETE FROM inventory_transactions WHERE created_by IN (SELECT id FROM users WHERE username LIKE 'test_%');
DELETE FROM daily_inventory_count_items WHERE count_id IN (SELECT id FROM daily_inventory_counts WHERE counted_by IN (SELECT id FROM users WHERE username LIKE 'test_%'));
DELETE FROM daily_inventory_counts WHERE counted_by IN (SELECT id FROM users WHERE username LIKE 'test_%');
DELETE FROM order_items WHERE order_id IN (SELECT id FROM orders WHERE order_number LIKE 'TORD%');
DELETE FROM orders WHERE order_number LIKE 'TORD%';
DELETE FROM purchase_order_items WHERE order_id IN (SELECT id FROM purchase_orders WHERE order_number LIKE 'TPO%');
DELETE FROM purchase_orders WHERE order_number LIKE 'TPO%';
DELETE FROM purchase_request_items WHERE request_id IN (SELECT id FROM purchase_requests WHERE request_number LIKE 'TPR%');
DELETE FROM purchase_requests WHERE request_number LIKE 'TPR%';
DELETE FROM branch_return_items WHERE return_id IN (SELECT id FROM branch_returns WHERE return_number LIKE 'TBRT%');
DELETE FROM branch_returns WHERE return_number LIKE 'TBRT%';
DELETE FROM damages WHERE damage_number LIKE 'TDMG%';
DELETE FROM supplier_returns WHERE return_number LIKE 'TRET%';
DELETE FROM supplier_payments WHERE payment_number LIKE 'TPAY%';
DELETE FROM supply_items WHERE supply_id IN (SELECT id FROM supplies WHERE supply_number LIKE 'TSUP%');
DELETE FROM supplies WHERE supply_number LIKE 'TSUP%';
DELETE FROM transfer_items WHERE transfer_id IN (SELECT id FROM transfers WHERE transfer_number LIKE 'TTRF%');
DELETE FROM transfers WHERE transfer_number LIKE 'TTRF%';
DELETE FROM inventory_batches WHERE batch_number LIKE 'TBATCH%';
DELETE FROM supplier_items WHERE supplier_id IN (SELECT id FROM suppliers WHERE code LIKE 'TSUP%');
DELETE FROM suppliers WHERE code LIKE 'TSUP%';
DELETE FROM branch_settings WHERE branch_id IN (SELECT id FROM branches WHERE code = 'TEST01');
DELETE FROM branches WHERE code = 'TEST01';
DELETE FROM users WHERE username LIKE 'test_%';
*/

-- =====================================================
-- SECTION 20: VERIFICATION QUERIES
-- =====================================================

-- 20.1: Verify all test data was created
SELECT 'Users' as entity, COUNT(*) as count FROM users WHERE username LIKE 'test_%'
UNION ALL
SELECT 'Suppliers', COUNT(*) FROM suppliers WHERE code LIKE 'TSUP%'
UNION ALL
SELECT 'Supplies', COUNT(*) FROM supplies WHERE supply_number LIKE 'TSUP%'
UNION ALL
SELECT 'Transfers', COUNT(*) FROM transfers WHERE transfer_number LIKE 'TTRF%'
UNION ALL
SELECT 'Damages', COUNT(*) FROM damages WHERE damage_number LIKE 'TDMG%'
UNION ALL
SELECT 'Orders', COUNT(*) FROM orders WHERE order_number LIKE 'TORD%'
UNION ALL
SELECT 'Purchase Requests', COUNT(*) FROM purchase_requests WHERE request_number LIKE 'TPR%'
UNION ALL
SELECT 'Purchase Orders', COUNT(*) FROM purchase_orders WHERE order_number LIKE 'TPO%'
UNION ALL
SELECT 'Branch Returns', COUNT(*) FROM branch_returns WHERE return_number LIKE 'TBRT%'
UNION ALL
SELECT 'Supplier Returns', COUNT(*) FROM supplier_returns WHERE return_number LIKE 'TRET%'
UNION ALL
SELECT 'Payments', COUNT(*) FROM supplier_payments WHERE payment_number LIKE 'TPAY%';

-- 20.2: Verify inventory consistency
SELECT 
    b.name_ar as branch,
    i.name_ar as item,
    inv.quantity as current_qty,
    (SELECT SUM(CASE 
        WHEN operation_type IN ('supply', 'transfer_in', 'adjustment') THEN quantity
        WHEN operation_type IN ('transfer_out', 'damage', 'return', 'consumption') THEN -quantity
        ELSE 0
    END) FROM inventory_transactions WHERE branch_id = inv.branch_id AND item_id = inv.item_id) as calculated_qty
FROM inventory inv
JOIN branches b ON inv.branch_id = b.id
JOIN items i ON inv.item_id = i.id
WHERE b.code IN ('MAIN', 'BR001');

-- 20.3: Verify supplier balance consistency
SELECT 
    s.name_ar,
    s.current_balance,
    (SELECT COALESCE(SUM(total_amount), 0) FROM supplies WHERE supplier_id = s.id AND payment_method = 'credit') -
    (SELECT COALESCE(SUM(paid_amount), 0) FROM supplies WHERE supplier_id = s.id) -
    (SELECT COALESCE(SUM(amount), 0) FROM supplier_payments WHERE supplier_id = s.id) -
    (SELECT COALESCE(SUM(total_amount), 0) FROM supplier_returns WHERE supplier_id = s.id AND status = 'approved') as calculated_balance
FROM suppliers s
WHERE s.code LIKE 'TSUP%';

-- =====================================================
-- END OF DEEP TEST
-- =====================================================
