-- =====================================================
-- Test Data for Purchase Manager System
-- =====================================================

-- 1. Create Purchase Manager User
INSERT INTO users (employee_code, username, email, password_hash, full_name, full_name_ar, phone, role_id, branch_id, status)
SELECT 'EMP009', 'purchase_mgr', 'purchase@restaurant.com', 'hashed_password_123', 'Omar Mahmoud', 'Omar Mahmoud', '01000000009',
       r.id, b.id, 'active'
FROM roles r, branches b
WHERE r.name = 'purchase_manager' AND b.code = 'MAIN'
ON CONFLICT (username) DO NOTHING;

-- 2. Create Purchase Request 1 (Pending Approval)
INSERT INTO purchase_requests (request_number, request_date, branch_id, status, priority, notes, requested_by)
SELECT 'PR-2024-12-0001', CURRENT_DATE, b.id, 'pending', 1, 'Weekly stock replenishment', u.id
FROM branches b, users u
WHERE b.code = 'MAIN' AND u.username = 'purchase_mgr'
ON CONFLICT (request_number) DO NOTHING;

-- 2.1 Add Items to Request 1
INSERT INTO purchase_request_items (request_id, item_id, supplier_id, requested_quantity, estimated_unit_price, estimated_total, notes)
SELECT pr.id, i.id, s.id, 100, 78.00, 7800.00, 'Urgent - low stock'
FROM purchase_requests pr, items i, suppliers s
WHERE pr.request_number = 'PR-2024-12-0001' AND i.code = 'ITM001' AND s.code = 'SUP001';

INSERT INTO purchase_request_items (request_id, item_id, supplier_id, requested_quantity, estimated_unit_price, estimated_total, notes)
SELECT pr.id, i.id, s.id, 50, 245.00, 12250.00, NULL
FROM purchase_requests pr, items i, suppliers s
WHERE pr.request_number = 'PR-2024-12-0001' AND i.code = 'ITM002' AND s.code = 'SUP001';

INSERT INTO purchase_request_items (request_id, item_id, supplier_id, requested_quantity, estimated_unit_price, estimated_total, notes)
SELECT pr.id, i.id, s.id, 200, 15.00, 3000.00, 'For salads'
FROM purchase_requests pr, items i, suppliers s
WHERE pr.request_number = 'PR-2024-12-0001' AND i.code = 'ITM003' AND s.code = 'SUP002';

-- 3. Create Purchase Request 2 (Approved)
INSERT INTO purchase_requests (request_number, request_date, branch_id, status, priority, notes, requested_by, approved_by, approved_at)
SELECT 'PR-2024-12-0002', CURRENT_DATE - INTERVAL '2 days', b.id, 'approved', 2, 'Dairy products needed', u.id,
       (SELECT id FROM users WHERE username = 'admin'), CURRENT_TIMESTAMP - INTERVAL '1 day'
FROM branches b, users u
WHERE b.code = 'MAIN' AND u.username = 'purchase_mgr'
ON CONFLICT (request_number) DO NOTHING;

-- 3.1 Add Items to Request 2
INSERT INTO purchase_request_items (request_id, item_id, supplier_id, requested_quantity, approved_quantity, estimated_unit_price, estimated_total, notes)
SELECT pr.id, i.id, s.id, 30, 30, 120.00, 3600.00, 'For pizza'
FROM purchase_requests pr, items i, suppliers s
WHERE pr.request_number = 'PR-2024-12-0002' AND i.code = 'ITM007' AND s.code = 'SUP003';

-- 4. Create Purchase Request 3 (Draft - Branch 1)
INSERT INTO purchase_requests (request_number, request_date, branch_id, status, priority, notes, requested_by)
SELECT 'PR-2024-12-0003', CURRENT_DATE, b.id, 'draft', 0, 'Branch 1 weekly needs', u.id
FROM branches b, users u
WHERE b.code = 'BR001' AND u.username = 'branch1_sup'
ON CONFLICT (request_number) DO NOTHING;

-- 4.1 Add Items to Request 3
INSERT INTO purchase_request_items (request_id, item_id, supplier_id, requested_quantity, estimated_unit_price, estimated_total, notes)
SELECT pr.id, i.id, NULL, 20, 78.00, 1560.00, 'Running low'
FROM purchase_requests pr, items i
WHERE pr.request_number = 'PR-2024-12-0003' AND i.code = 'ITM001';

INSERT INTO purchase_request_items (request_id, item_id, supplier_id, requested_quantity, estimated_unit_price, estimated_total, notes)
SELECT pr.id, i.id, NULL, 100, 8.00, 800.00, 'Weekend rush expected'
FROM purchase_requests pr, items i
WHERE pr.request_number = 'PR-2024-12-0003' AND i.code = 'ITM008';

-- 5. Create Purchase Request 4 (Completed)
INSERT INTO purchase_requests (request_number, request_date, branch_id, status, priority, notes, requested_by, approved_by, approved_at)
SELECT 'PR-2024-12-0004', CURRENT_DATE - INTERVAL '5 days', b.id, 'completed', 1, 'Oils and grains', u.id,
       (SELECT id FROM users WHERE username = 'admin'), CURRENT_TIMESTAMP - INTERVAL '4 days'
FROM branches b, users u
WHERE b.code = 'MAIN' AND u.username = 'purchase_mgr'
ON CONFLICT (request_number) DO NOTHING;

-- 5.1 Add Items to Request 4
INSERT INTO purchase_request_items (request_id, item_id, supplier_id, requested_quantity, approved_quantity, ordered_quantity, received_quantity, estimated_unit_price, estimated_total, item_status, notes)
SELECT pr.id, i.id, NULL, 50, 50, 50, 50, 45.00, 2250.00, 'received', 'Delivered on time'
FROM purchase_requests pr, items i
WHERE pr.request_number = 'PR-2024-12-0004' AND i.code = 'ITM005';

INSERT INTO purchase_request_items (request_id, item_id, supplier_id, requested_quantity, approved_quantity, ordered_quantity, received_quantity, estimated_unit_price, estimated_total, item_status, notes)
SELECT pr.id, i.id, NULL, 200, 200, 200, 200, 35.00, 7000.00, 'received', NULL
FROM purchase_requests pr, items i
WHERE pr.request_number = 'PR-2024-12-0004' AND i.code = 'ITM006';

-- 6. Create Purchase Order (from approved request)
INSERT INTO purchase_orders (order_number, order_date, request_id, supplier_id, branch_id, subtotal, tax_amount, total_amount, status, expected_delivery_date, notes, created_by)
SELECT 'PO-2024-12-0001', CURRENT_DATE - INTERVAL '1 day', pr.id, s.id, b.id, 3600.00, 504.00, 4104.00, 'pending', CURRENT_DATE + INTERVAL '2 days', 'Dairy order', u.id
FROM purchase_requests pr, suppliers s, branches b, users u
WHERE pr.request_number = 'PR-2024-12-0002' AND s.code = 'SUP003' AND b.code = 'MAIN' AND u.username = 'purchase_mgr'
ON CONFLICT (order_number) DO NOTHING;

-- 6.1 Add Items to Purchase Order
INSERT INTO purchase_order_items (order_id, item_id, request_item_id, quantity, unit_price, tax_percent, total_price, notes)
SELECT po.id, i.id, pri.id, 30, 120.00, 14, 4104.00, 'Cheese for pizza'
FROM purchase_orders po, items i, purchase_request_items pri, purchase_requests pr
WHERE po.order_number = 'PO-2024-12-0001' AND i.code = 'ITM007' 
AND pr.request_number = 'PR-2024-12-0002' AND pri.request_id = pr.id AND pri.item_id = i.id;
