-- =====================================================
-- DEEP TEST V2 - Complete System Testing
-- All Flows and Scenarios
-- =====================================================

-- =====================================================
-- SCENARIO 1: NEW SUPPLIER + FULL SUPPLY FLOW
-- =====================================================

-- 1.1: Add new supplier
INSERT INTO suppliers (code, name, contact_person, phone, email, address, payment_terms, credit_limit, status, created_by)
SELECT 'SUP005', 'Spices World', 'Hassan Ibrahim', '01555000001', 'spices@world.com', 
       'Spices Market, Cairo', 30, 25000.00, 'active', u.id
FROM users u WHERE u.username = 'admin'
ON CONFLICT (code) DO NOTHING;

-- 1.2: Create new supply from SUP005
INSERT INTO supplies (supply_number, supplier_id, branch_id, invoice_number, invoice_date, subtotal, tax_amount, total_amount, payment_method, payment_status, received_by, received_at)
SELECT 'SUP-2024-005', s.id, b.id, 'INV-SP-001', CURRENT_DATE, 3500.00, 490.00, 3990.00, 'credit', 'pending', u.id, CURRENT_TIMESTAMP
FROM suppliers s, branches b, users u
WHERE s.code = 'SUP005' AND b.code = 'MAIN' AND u.username = 'warehouse_mgr'
ON CONFLICT (supply_number) DO NOTHING;

-- 1.3: Add supply items (using existing items)
INSERT INTO supply_items (supply_id, item_id, quantity, received_quantity, unit_price, tax_percent, total_price, batch_number, expiry_date)
SELECT sup.id, i.id, 100, 100, 35.00, 14, 3990.00, 'BATCH-SP-001', CURRENT_DATE + INTERVAL '180 days'
FROM supplies sup, items i WHERE sup.supply_number = 'SUP-2024-005' AND i.code = 'ITM006'
ON CONFLICT DO NOTHING;

-- 1.4: Update supplier balance
UPDATE suppliers SET current_balance = current_balance + 3990.00 WHERE code = 'SUP005';

-- 1.5: Update inventory
UPDATE inventory SET quantity = quantity + 100, incoming_quantity = incoming_quantity + 100
WHERE branch_id = (SELECT id FROM branches WHERE code = 'MAIN') 
AND item_id = (SELECT id FROM items WHERE code = 'ITM006');

-- 1.6: Record transaction
INSERT INTO inventory_transactions (branch_id, item_id, operation_type, quantity, quantity_before, quantity_after, unit_cost, reference_type, created_by)
SELECT b.id, i.id, 'supply', 100, 148, 248, 35.00, 'supply', u.id
FROM branches b, items i, users u WHERE b.code = 'MAIN' AND i.code = 'ITM006' AND u.username = 'warehouse_mgr';

-- =====================================================
-- SCENARIO 2: TRANSFER FROM MAIN TO BRANCH WITH FULL FLOW
-- =====================================================

-- 2.1: Create transfer request
INSERT INTO transfers (transfer_number, from_branch_id, to_branch_id, status, priority, notes, requested_by, requested_at)
SELECT 'TRF-2024-003', b1.id, b2.id, 'pending', 1, 'Weekly stock replenishment for Branch 1', u.id, CURRENT_TIMESTAMP
FROM branches b1, branches b2, users u
WHERE b1.code = 'MAIN' AND b2.code = 'BR001' AND u.username = 'branch1_sup'
ON CONFLICT (transfer_number) DO NOTHING;

-- 2.2: Add transfer items
INSERT INTO transfer_items (transfer_id, item_id, requested_quantity, notes)
SELECT t.id, i.id, 20, 'Running low'
FROM transfers t, items i WHERE t.transfer_number = 'TRF-2024-003' AND i.code = 'ITM001'
ON CONFLICT DO NOTHING;

INSERT INTO transfer_items (transfer_id, item_id, requested_quantity, notes)
SELECT t.id, i.id, 10, 'Weekend prep'
FROM transfers t, items i WHERE t.transfer_number = 'TRF-2024-003' AND i.code = 'ITM002'
ON CONFLICT DO NOTHING;

INSERT INTO transfer_items (transfer_id, item_id, requested_quantity, notes)
SELECT t.id, i.id, 50, 'High demand'
FROM transfers t, items i WHERE t.transfer_number = 'TRF-2024-003' AND i.code = 'ITM006'
ON CONFLICT DO NOTHING;

-- 2.3: Approve transfer
UPDATE transfers SET 
    status = 'approved',
    approved_by = (SELECT id FROM users WHERE username = 'warehouse_mgr'),
    approved_at = CURRENT_TIMESTAMP
WHERE transfer_number = 'TRF-2024-003';

-- 2.4: Set approved quantities
UPDATE transfer_items SET approved_quantity = 20, shipped_quantity = 20
WHERE transfer_id = (SELECT id FROM transfers WHERE transfer_number = 'TRF-2024-003')
AND item_id = (SELECT id FROM items WHERE code = 'ITM001');

UPDATE transfer_items SET approved_quantity = 10, shipped_quantity = 10
WHERE transfer_id = (SELECT id FROM transfers WHERE transfer_number = 'TRF-2024-003')
AND item_id = (SELECT id FROM items WHERE code = 'ITM002');

UPDATE transfer_items SET approved_quantity = 40, shipped_quantity = 40
WHERE transfer_id = (SELECT id FROM transfers WHERE transfer_number = 'TRF-2024-003')
AND item_id = (SELECT id FROM items WHERE code = 'ITM006');

-- 2.5: Receive transfer at branch
UPDATE transfers SET 
    status = 'received',
    received_by = (SELECT id FROM users WHERE username = 'branch1_sup'),
    received_at = CURRENT_TIMESTAMP
WHERE transfer_number = 'TRF-2024-003';

UPDATE transfer_items SET received_quantity = approved_quantity
WHERE transfer_id = (SELECT id FROM transfers WHERE transfer_number = 'TRF-2024-003');

-- 2.6: Update inventories (deduct from MAIN, add to BR001)
UPDATE inventory SET quantity = quantity - 20 
WHERE branch_id = (SELECT id FROM branches WHERE code = 'MAIN') 
AND item_id = (SELECT id FROM items WHERE code = 'ITM001');

UPDATE inventory SET quantity = quantity - 10 
WHERE branch_id = (SELECT id FROM branches WHERE code = 'MAIN') 
AND item_id = (SELECT id FROM items WHERE code = 'ITM002');

UPDATE inventory SET quantity = quantity - 40 
WHERE branch_id = (SELECT id FROM branches WHERE code = 'MAIN') 
AND item_id = (SELECT id FROM items WHERE code = 'ITM006');

UPDATE inventory SET quantity = quantity + 20 
WHERE branch_id = (SELECT id FROM branches WHERE code = 'BR001') 
AND item_id = (SELECT id FROM items WHERE code = 'ITM001');

UPDATE inventory SET quantity = quantity + 10 
WHERE branch_id = (SELECT id FROM branches WHERE code = 'BR001') 
AND item_id = (SELECT id FROM items WHERE code = 'ITM002');

-- Add ITM006 to BR001 if not exists
INSERT INTO inventory (branch_id, item_id, quantity, min_quantity)
SELECT b.id, i.id, 40, 20 FROM branches b, items i WHERE b.code = 'BR001' AND i.code = 'ITM006'
ON CONFLICT ON CONSTRAINT uk_inventory_branch_item DO UPDATE SET quantity = inventory.quantity + 40;

-- 2.7: Record transactions
INSERT INTO inventory_transactions (branch_id, item_id, operation_type, quantity, quantity_before, quantity_after, reference_type, created_by)
SELECT b.id, i.id, 'transfer_out', 20, 85, 65, 'transfer', u.id
FROM branches b, items i, users u WHERE b.code = 'MAIN' AND i.code = 'ITM001' AND u.username = 'warehouse_mgr';

INSERT INTO inventory_transactions (branch_id, item_id, operation_type, quantity, quantity_before, quantity_after, reference_type, created_by)
SELECT b.id, i.id, 'transfer_in', 20, 10, 30, 'transfer', u.id
FROM branches b, items i, users u WHERE b.code = 'BR001' AND i.code = 'ITM001' AND u.username = 'branch1_sup';


-- =====================================================
-- SCENARIO 3: NEW DAMAGE WITH APPROVAL FLOW
-- =====================================================

-- 3.1: Register new damage at Branch 2
INSERT INTO damages (damage_number, branch_id, item_id, quantity, unit_cost, total_cost, reason_id, description, status, registered_by, registered_at)
SELECT 'DMG-2024-006', b.id, i.id, 8, 78.00, 624.00, dr.id, 'Chicken found spoiled in storage', 'pending', u.id, CURRENT_TIMESTAMP
FROM branches b, items i, damage_reasons dr, users u
WHERE b.code = 'BR002' AND i.code = 'ITM001' AND dr.code = 'STORAGE' AND u.username = 'branch2_sup'
ON CONFLICT (damage_number) DO NOTHING;

-- 3.2: Approve damage
UPDATE damages SET 
    status = 'approved',
    approved_by = (SELECT id FROM users WHERE username = 'admin'),
    approved_at = CURRENT_TIMESTAMP
WHERE damage_number = 'DMG-2024-006';

-- 3.3: Deduct from inventory
UPDATE inventory SET quantity = quantity - 8 
WHERE branch_id = (SELECT id FROM branches WHERE code = 'BR002') 
AND item_id = (SELECT id FROM items WHERE code = 'ITM001');

-- 3.4: Record transaction
INSERT INTO inventory_transactions (branch_id, item_id, operation_type, quantity, quantity_before, quantity_after, unit_cost, reference_type, created_by)
SELECT b.id, i.id, 'damage', 8, 10, 2, 78.00, 'damage', u.id
FROM branches b, items i, users u WHERE b.code = 'BR002' AND i.code = 'ITM001' AND u.username = 'branch2_sup';

-- =====================================================
-- SCENARIO 4: BRANCH RETURN - COMPLETE FLOW
-- =====================================================

-- 4.1: Create branch return from BR001 to MAIN
INSERT INTO branch_returns (return_number, return_date, from_branch_id, to_branch_id, status, return_reason, notes, requested_by, requested_at)
SELECT 'BRT-2024-12-0006', CURRENT_DATE, fb.id, tb.id, 'pending', 
       'Near expiry items need to be returned',
       'Items expiring within 5 days',
       u.id, CURRENT_TIMESTAMP
FROM branches fb, branches tb, users u
WHERE fb.code = 'BR001' AND tb.code = 'MAIN' AND u.username = 'branch1_sup'
ON CONFLICT (return_number) DO NOTHING;

-- 4.2: Add return items
INSERT INTO branch_return_items (return_id, item_id, requested_quantity, unit_cost, total_value, item_reason)
SELECT br.id, i.id, 5, 245.00, 1225.00, 'Near expiry - 3 days left'
FROM branch_returns br, items i 
WHERE br.return_number = 'BRT-2024-12-0006' AND i.code = 'ITM002'
ON CONFLICT ON CONSTRAINT uk_return_item DO NOTHING;

-- 4.3: Approve return
UPDATE branch_returns SET 
    status = 'approved',
    approved_by = (SELECT id FROM users WHERE username = 'warehouse_mgr'),
    approved_at = CURRENT_TIMESTAMP
WHERE return_number = 'BRT-2024-12-0006';

UPDATE branch_return_items SET approved_quantity = requested_quantity
WHERE return_id = (SELECT id FROM branch_returns WHERE return_number = 'BRT-2024-12-0006');

-- 4.4: Ship return
UPDATE branch_returns SET 
    status = 'in_transit',
    shipped_at = CURRENT_TIMESTAMP
WHERE return_number = 'BRT-2024-12-0006';

UPDATE branch_return_items SET shipped_quantity = approved_quantity
WHERE return_id = (SELECT id FROM branch_returns WHERE return_number = 'BRT-2024-12-0006');

-- 4.5: Receive return at main warehouse
UPDATE branch_returns SET 
    status = 'received',
    received_by = (SELECT id FROM users WHERE username = 'warehouse_mgr'),
    received_at = CURRENT_TIMESTAMP
WHERE return_number = 'BRT-2024-12-0006';

UPDATE branch_return_items SET received_quantity = shipped_quantity
WHERE return_id = (SELECT id FROM branch_returns WHERE return_number = 'BRT-2024-12-0006');

-- 4.6: Update inventories
UPDATE inventory SET quantity = quantity - 5 
WHERE branch_id = (SELECT id FROM branches WHERE code = 'BR001') 
AND item_id = (SELECT id FROM items WHERE code = 'ITM002');

UPDATE inventory SET quantity = quantity + 5 
WHERE branch_id = (SELECT id FROM branches WHERE code = 'MAIN') 
AND item_id = (SELECT id FROM items WHERE code = 'ITM002');

-- 4.7: Record transactions
INSERT INTO inventory_transactions (branch_id, item_id, operation_type, quantity, quantity_before, quantity_after, unit_cost, notes, reference_type, created_by)
SELECT b.id, i.id, 'transfer_out', 5, 15, 10, 245.00, 'Branch return BRT-2024-12-0006', 'branch_return', u.id
FROM branches b, items i, users u WHERE b.code = 'BR001' AND i.code = 'ITM002' AND u.username = 'branch1_sup';

INSERT INTO inventory_transactions (branch_id, item_id, operation_type, quantity, quantity_before, quantity_after, unit_cost, notes, reference_type, created_by)
SELECT b.id, i.id, 'transfer_in', 5, 30, 35, 245.00, 'Branch return BRT-2024-12-0006', 'branch_return', u.id
FROM branches b, items i, users u WHERE b.code = 'MAIN' AND i.code = 'ITM002' AND u.username = 'warehouse_mgr';

-- =====================================================
-- SCENARIO 5: SUPPLIER RETURN FLOW
-- =====================================================

-- 5.1: Create supplier return
INSERT INTO supplier_returns (return_number, supply_id, supplier_id, item_id, quantity, unit_price, total_amount, reason, description, status, registered_by, registered_at)
SELECT 'RET-2024-004', sup.id, s.id, i.id, 20, 35.00, 700.00, 'Damaged packaging', 'Rice bags were torn', 'pending', u.id, CURRENT_TIMESTAMP
FROM supplies sup, suppliers s, items i, users u
WHERE sup.supply_number = 'SUP-2024-005' AND s.code = 'SUP005' AND i.code = 'ITM006' AND u.username = 'warehouse_mgr'
ON CONFLICT (return_number) DO NOTHING;

-- 5.2: Approve return
UPDATE supplier_returns SET 
    status = 'approved',
    approved_by = (SELECT id FROM users WHERE username = 'admin'),
    approved_at = CURRENT_TIMESTAMP
WHERE return_number = 'RET-2024-004';

-- 5.3: Update inventory and supplier balance
UPDATE inventory SET quantity = quantity - 20 
WHERE branch_id = (SELECT id FROM branches WHERE code = 'MAIN') 
AND item_id = (SELECT id FROM items WHERE code = 'ITM006');

UPDATE suppliers SET current_balance = current_balance - 700.00 WHERE code = 'SUP005';

-- 5.4: Record transaction
INSERT INTO inventory_transactions (branch_id, item_id, operation_type, quantity, quantity_before, quantity_after, unit_cost, reference_type, created_by)
SELECT b.id, i.id, 'return', 20, 248, 228, 35.00, 'supplier_return', u.id
FROM branches b, items i, users u WHERE b.code = 'MAIN' AND i.code = 'ITM006' AND u.username = 'warehouse_mgr';

-- =====================================================
-- SCENARIO 6: PURCHASE REQUEST FULL FLOW
-- =====================================================

-- 6.1: Create purchase request
INSERT INTO purchase_requests (request_number, request_date, branch_id, status, priority, notes, requested_by, requested_at)
SELECT 'PR-2024-12-0005', CURRENT_DATE, b.id, 'draft', 2, 'Urgent items needed for next week', u.id, CURRENT_TIMESTAMP
FROM branches b, users u
WHERE b.code = 'MAIN' AND u.username = 'purchase_mgr'
ON CONFLICT (request_number) DO NOTHING;

-- 6.2: Add request items
INSERT INTO purchase_request_items (request_id, item_id, requested_quantity, estimated_unit_price, supplier_id, notes)
SELECT pr.id, i.id, 100, 78.00, s.id, 'Weekly chicken order'
FROM purchase_requests pr, items i, suppliers s
WHERE pr.request_number = 'PR-2024-12-0005' AND i.code = 'ITM001' AND s.code = 'SUP001'
ON CONFLICT DO NOTHING;

INSERT INTO purchase_request_items (request_id, item_id, requested_quantity, estimated_unit_price, supplier_id, notes)
SELECT pr.id, i.id, 50, 245.00, s.id, 'Beef for weekend'
FROM purchase_requests pr, items i, suppliers s
WHERE pr.request_number = 'PR-2024-12-0005' AND i.code = 'ITM002' AND s.code = 'SUP001'
ON CONFLICT DO NOTHING;

-- 6.3: Submit request
UPDATE purchase_requests SET status = 'pending' WHERE request_number = 'PR-2024-12-0005';

-- 6.4: Approve request
UPDATE purchase_requests SET 
    status = 'approved',
    approved_by = (SELECT id FROM users WHERE username = 'admin'),
    approved_at = CURRENT_TIMESTAMP
WHERE request_number = 'PR-2024-12-0005';

-- =====================================================
-- SCENARIO 7: POS ORDER FLOW
-- =====================================================

-- 7.1: Create new order at Branch 2
INSERT INTO orders (order_number, branch_id, order_type, customer_name, customer_phone, subtotal, tax_amount, total_amount, status, cashier_id, created_at)
SELECT 'ORD-2024-007', b.id, 'dine_in', 'Ahmed Mahmoud', '01100000007', 255.00, 35.70, 290.70, 'new', u.id, CURRENT_TIMESTAMP
FROM branches b, users u WHERE b.code = 'BR002' AND u.username = 'cashier2'
ON CONFLICT (order_number) DO NOTHING;

-- 7.2: Add order items
INSERT INTO order_items (order_id, menu_item_id, quantity, unit_price, total_price, status, notes)
SELECT o.id, mi.id, 3, 85.00, 255.00, 'pending', 'Extra spicy'
FROM orders o, menu_items mi WHERE o.order_number = 'ORD-2024-007' AND mi.code = 'MENU001'
ON CONFLICT DO NOTHING;

-- 7.3: Process payment
UPDATE orders SET 
    payment_method = 'visa',
    status = 'paid',
    paid_at = CURRENT_TIMESTAMP
WHERE order_number = 'ORD-2024-007';

-- 7.4: Send to kitchen
UPDATE orders SET 
    status = 'in_kitchen',
    sent_to_kitchen_at = CURRENT_TIMESTAMP,
    chef_id = (SELECT id FROM users WHERE username = 'chef2')
WHERE order_number = 'ORD-2024-007';

UPDATE order_items SET status = 'in_kitchen'
WHERE order_id = (SELECT id FROM orders WHERE order_number = 'ORD-2024-007');

-- 7.5: Start preparation
UPDATE orders SET 
    status = 'preparing',
    preparation_started_at = CURRENT_TIMESTAMP
WHERE order_number = 'ORD-2024-007';

UPDATE order_items SET status = 'preparing'
WHERE order_id = (SELECT id FROM orders WHERE order_number = 'ORD-2024-007');

-- 7.6: Ready
UPDATE orders SET 
    status = 'ready',
    ready_at = CURRENT_TIMESTAMP
WHERE order_number = 'ORD-2024-007';

UPDATE order_items SET status = 'ready'
WHERE order_id = (SELECT id FROM orders WHERE order_number = 'ORD-2024-007');

-- 7.7: Delivered
UPDATE orders SET 
    status = 'delivered',
    delivered_at = CURRENT_TIMESTAMP
WHERE order_number = 'ORD-2024-007';

UPDATE order_items SET status = 'delivered'
WHERE order_id = (SELECT id FROM orders WHERE order_number = 'ORD-2024-007');

-- 7.8: Record consumption
INSERT INTO inventory_transactions (branch_id, item_id, operation_type, quantity, quantity_before, quantity_after, reference_type, created_by)
SELECT b.id, i.id, 'consumption', 0.75, 2, 1.25, 'order', u.id
FROM branches b, items i, users u WHERE b.code = 'BR002' AND i.code = 'ITM001' AND u.username = 'cashier2';


-- =====================================================
-- SCENARIO 8: SUPPLIER PAYMENT FLOW
-- =====================================================

-- 8.1: Make payment to SUP005
INSERT INTO supplier_payments (payment_number, supplier_id, amount, payment_method, reference_number, bank_name, payment_date, notes, created_by)
SELECT 'PAY-2024-005', s.id, 2000.00, 'bank_transfer', 'TRX-2024-005', 'NBE Bank', CURRENT_DATE, 'Partial payment for SUP-2024-005', u.id
FROM suppliers s, users u WHERE s.code = 'SUP005' AND u.username = 'admin'
ON CONFLICT (payment_number) DO NOTHING;

-- 8.2: Update supplier balance
UPDATE suppliers SET current_balance = current_balance - 2000.00 WHERE code = 'SUP005';

-- =====================================================
-- SCENARIO 9: DAILY INVENTORY COUNT
-- =====================================================

-- 9.1: Create evening count for Branch 2
INSERT INTO daily_inventory_counts (branch_id, count_date, count_type, status, notes, counted_by, submitted_at)
SELECT b.id, CURRENT_DATE, 'evening', 'submitted', 'End of day count - all items verified', u.id, CURRENT_TIMESTAMP
FROM branches b, users u
WHERE b.code = 'BR002' AND u.username = 'branch2_sup'
ON CONFLICT DO NOTHING;

-- 9.2: Add count items with variances
INSERT INTO daily_inventory_count_items (count_id, item_id, system_quantity, actual_quantity, variance_reason)
SELECT dic.id, i.id, 1.25, 1.0, 'Minor variance - possible measurement error'
FROM daily_inventory_counts dic, items i, branches b
WHERE dic.branch_id = b.id AND b.code = 'BR002' AND dic.count_type = 'evening' AND dic.count_date = CURRENT_DATE AND i.code = 'ITM001'
ON CONFLICT DO NOTHING;

INSERT INTO daily_inventory_count_items (count_id, item_id, system_quantity, actual_quantity, variance_reason)
SELECT dic.id, i.id, 10, 10, NULL
FROM daily_inventory_counts dic, items i, branches b
WHERE dic.branch_id = b.id AND b.code = 'BR002' AND dic.count_type = 'evening' AND dic.count_date = CURRENT_DATE AND i.code = 'ITM002'
ON CONFLICT DO NOTHING;

-- =====================================================
-- SCENARIO 10: BRANCH INVENTORY WITH NEW FIELDS
-- =====================================================

-- 10.1: Update branch inventory with new fields
UPDATE inventory SET 
    entry_date = CURRENT_DATE,
    document_number = 'INV-BR001-2024-12-0001',
    partial_quantity = 5,
    content_quantity = 25,
    content_description = 'Chicken breast portions for grilling'
WHERE branch_id = (SELECT id FROM branches WHERE code = 'BR001') 
AND item_id = (SELECT id FROM items WHERE code = 'ITM001');

UPDATE inventory SET 
    entry_date = CURRENT_DATE,
    document_number = 'INV-BR001-2024-12-0002',
    partial_quantity = 2,
    content_quantity = 8,
    content_description = 'Beef cuts for steaks'
WHERE branch_id = (SELECT id FROM branches WHERE code = 'BR001') 
AND item_id = (SELECT id FROM items WHERE code = 'ITM002');

UPDATE inventory SET 
    entry_date = CURRENT_DATE,
    document_number = 'INV-BR002-2024-12-0001',
    partial_quantity = 0.25,
    content_quantity = 1.0,
    content_description = 'Chicken for daily orders'
WHERE branch_id = (SELECT id FROM branches WHERE code = 'BR002') 
AND item_id = (SELECT id FROM items WHERE code = 'ITM001');

-- =====================================================
-- SCENARIO 11: NOTIFICATIONS FOR ALL EVENTS
-- =====================================================

-- 11.1: Low stock notification
INSERT INTO notifications (user_id, branch_id, type, title, message, priority, reference_type, is_read)
SELECT u.id, b.id, 'low_stock', 'Low Stock Alert', 
       'Chicken Breast at Branch 2 is critically low (only 1.25 kg)', 
       'high', 'inventory', FALSE
FROM users u, branches b WHERE u.username = 'branch2_sup' AND b.code = 'BR002';

-- 11.2: Transfer notification
INSERT INTO notifications (user_id, branch_id, type, title, message, priority, reference_type, is_read)
SELECT u.id, b.id, 'transfer_received', 'Transfer Completed', 
       'Transfer TRF-2024-003 has been received successfully', 
       'normal', 'transfer', FALSE
FROM users u, branches b WHERE u.username = 'warehouse_mgr' AND b.code = 'MAIN';

-- 11.3: Branch return notification
INSERT INTO notifications (user_id, branch_id, type, title, message, priority, reference_type, is_read)
SELECT u.id, b.id, 'system', 'Branch Return Received', 
       'Branch return BRT-2024-12-0006 has been received at Main Warehouse', 
       'normal', 'branch_return', FALSE
FROM users u, branches b WHERE u.username = 'branch1_sup' AND b.code = 'BR001';

-- 11.4: Purchase request approved
INSERT INTO notifications (user_id, branch_id, type, title, message, priority, reference_type, is_read)
SELECT u.id, b.id, 'pending_approval', 'Purchase Request Approved', 
       'Your purchase request PR-2024-12-0005 has been approved', 
       'normal', 'purchase_request', FALSE
FROM users u, branches b WHERE u.username = 'purchase_mgr' AND b.code = 'MAIN';

-- =====================================================
-- SCENARIO 12: AUDIT LOGS FOR ALL OPERATIONS
-- =====================================================

-- 12.1: Supply audit
INSERT INTO audit_logs (user_id, action, table_name, new_values, ip_address)
SELECT u.id, 'CREATE', 'supplies',
       '{"supply_number": "SUP-2024-005", "supplier": "SUP005", "total": 3990}'::jsonb,
       '192.168.1.100'
FROM users u WHERE u.username = 'warehouse_mgr';

-- 12.2: Transfer audit
INSERT INTO audit_logs (user_id, action, table_name, old_values, new_values, ip_address)
SELECT u.id, 'UPDATE', 'transfers',
       '{"status": "pending"}'::jsonb,
       '{"status": "received", "transfer_number": "TRF-2024-003"}'::jsonb,
       '192.168.1.100'
FROM users u WHERE u.username = 'warehouse_mgr';

-- 12.3: Damage audit
INSERT INTO audit_logs (user_id, action, table_name, new_values, ip_address)
SELECT u.id, 'CREATE', 'damages',
       '{"damage_number": "DMG-2024-006", "quantity": 8, "reason": "STORAGE"}'::jsonb,
       '192.168.1.102'
FROM users u WHERE u.username = 'branch2_sup';

-- 12.4: Branch return audit
INSERT INTO audit_logs (user_id, action, table_name, old_values, new_values, ip_address)
SELECT u.id, 'UPDATE', 'branch_returns',
       '{"status": "pending"}'::jsonb,
       '{"status": "received", "return_number": "BRT-2024-12-0006"}'::jsonb,
       '192.168.1.100'
FROM users u WHERE u.username = 'warehouse_mgr';

-- 12.5: Supplier return audit
INSERT INTO audit_logs (user_id, action, table_name, new_values, ip_address)
SELECT u.id, 'CREATE', 'supplier_returns',
       '{"return_number": "RET-2024-004", "quantity": 20, "supplier": "SUP005"}'::jsonb,
       '192.168.1.100'
FROM users u WHERE u.username = 'warehouse_mgr';

-- 12.6: Order audit
INSERT INTO audit_logs (user_id, action, table_name, old_values, new_values, ip_address)
SELECT u.id, 'UPDATE', 'orders',
       '{"status": "new"}'::jsonb,
       '{"status": "delivered", "order_number": "ORD-2024-007"}'::jsonb,
       '192.168.1.102'
FROM users u WHERE u.username = 'cashier2';

-- 12.7: Payment audit
INSERT INTO audit_logs (user_id, action, table_name, new_values, ip_address)
SELECT u.id, 'CREATE', 'supplier_payments',
       '{"payment_number": "PAY-2024-005", "amount": 2000, "supplier": "SUP005"}'::jsonb,
       '192.168.1.100'
FROM users u WHERE u.username = 'admin';
