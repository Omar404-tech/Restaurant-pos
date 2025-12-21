-- Clean Test Data (No Arabic to avoid encoding issues)

-- Categories
INSERT INTO categories (code, name, name_ar, description, sort_order) VALUES
('CAT001', 'Meat', 'Meat', 'All types of meat', 1),
('CAT002', 'Vegetables', 'Vegetables', 'Fresh vegetables', 2),
('CAT003', 'Dairy', 'Dairy', 'Dairy products', 3),
('CAT004', 'Beverages', 'Beverages', 'Drinks', 4),
('CAT005', 'Spices', 'Spices', 'Spices and seasonings', 5),
('CAT006', 'Oils', 'Oils', 'Cooking oils', 6),
('CAT007', 'Grains', 'Grains', 'Rice, pasta', 7)
ON CONFLICT (code) DO NOTHING;

-- Items
INSERT INTO items (code, barcode, name, name_ar, category_id, unit_id, purchase_price, min_stock_level, is_perishable, shelf_life_days, status)
SELECT 'ITM001', '1234567890001', 'Chicken Breast', 'Chicken', c.id, u.id, 80.00, 50, TRUE, 5, 'active'
FROM categories c, units u WHERE c.code = 'CAT001' AND u.code = 'KG'
ON CONFLICT (code) DO NOTHING;

INSERT INTO items (code, barcode, name, name_ar, category_id, unit_id, purchase_price, min_stock_level, is_perishable, shelf_life_days, status)
SELECT 'ITM002', '1234567890002', 'Beef Meat', 'Beef', c.id, u.id, 250.00, 30, TRUE, 3, 'active'
FROM categories c, units u WHERE c.code = 'CAT001' AND u.code = 'KG'
ON CONFLICT (code) DO NOTHING;

INSERT INTO items (code, barcode, name, name_ar, category_id, unit_id, purchase_price, min_stock_level, is_perishable, shelf_life_days, status)
SELECT 'ITM003', '1234567890003', 'Tomatoes', 'Tomatoes', c.id, u.id, 15.00, 100, TRUE, 7, 'active'
FROM categories c, units u WHERE c.code = 'CAT002' AND u.code = 'KG'
ON CONFLICT (code) DO NOTHING;

INSERT INTO items (code, barcode, name, name_ar, category_id, unit_id, purchase_price, min_stock_level, is_perishable, shelf_life_days, status)
SELECT 'ITM004', '1234567890004', 'Onions', 'Onions', c.id, u.id, 10.00, 80, TRUE, 14, 'active'
FROM categories c, units u WHERE c.code = 'CAT002' AND u.code = 'KG'
ON CONFLICT (code) DO NOTHING;

INSERT INTO items (code, barcode, name, name_ar, category_id, unit_id, purchase_price, min_stock_level, is_perishable, shelf_life_days, status)
SELECT 'ITM005', '1234567890005', 'Cooking Oil', 'Oil', c.id, u.id, 45.00, 20, FALSE, 365, 'active'
FROM categories c, units u WHERE c.code = 'CAT006' AND u.code = 'L'
ON CONFLICT (code) DO NOTHING;

INSERT INTO items (code, barcode, name, name_ar, category_id, unit_id, purchase_price, min_stock_level, is_perishable, shelf_life_days, status)
SELECT 'ITM006', '1234567890006', 'Rice', 'Rice', c.id, u.id, 35.00, 100, FALSE, 180, 'active'
FROM categories c, units u WHERE c.code = 'CAT007' AND u.code = 'KG'
ON CONFLICT (code) DO NOTHING;

INSERT INTO items (code, barcode, name, name_ar, category_id, unit_id, purchase_price, min_stock_level, is_perishable, shelf_life_days, status)
SELECT 'ITM007', '1234567890007', 'Cheese', 'Cheese', c.id, u.id, 120.00, 20, TRUE, 30, 'active'
FROM categories c, units u WHERE c.code = 'CAT003' AND u.code = 'KG'
ON CONFLICT (code) DO NOTHING;

INSERT INTO items (code, barcode, name, name_ar, category_id, unit_id, purchase_price, min_stock_level, is_perishable, shelf_life_days, status)
SELECT 'ITM008', '1234567890008', 'Pepsi', 'Pepsi', c.id, u.id, 8.00, 200, FALSE, 180, 'active'
FROM categories c, units u WHERE c.code = 'CAT004' AND u.code = 'BTL'
ON CONFLICT (code) DO NOTHING;

-- Supplier Items Links
INSERT INTO supplier_items (supplier_id, item_id, supplier_item_code, unit_price, min_order_quantity, lead_time_days, is_preferred)
SELECT s.id, i.id, 'SM-001', 78.00, 10, 1, TRUE
FROM suppliers s, items i WHERE s.code = 'SUP001' AND i.code = 'ITM001'
ON CONFLICT ON CONSTRAINT uk_supplier_item DO NOTHING;

INSERT INTO supplier_items (supplier_id, item_id, supplier_item_code, unit_price, min_order_quantity, lead_time_days, is_preferred)
SELECT s.id, i.id, 'SM-002', 245.00, 5, 1, TRUE
FROM suppliers s, items i WHERE s.code = 'SUP001' AND i.code = 'ITM002'
ON CONFLICT ON CONSTRAINT uk_supplier_item DO NOTHING;

INSERT INTO supplier_items (supplier_id, item_id, supplier_item_code, unit_price, min_order_quantity, lead_time_days, is_preferred)
SELECT s.id, i.id, 'GF-001', 14.00, 20, 1, TRUE
FROM suppliers s, items i WHERE s.code = 'SUP002' AND i.code = 'ITM003'
ON CONFLICT ON CONSTRAINT uk_supplier_item DO NOTHING;

INSERT INTO supplier_items (supplier_id, item_id, supplier_item_code, unit_price, min_order_quantity, lead_time_days, is_preferred)
SELECT s.id, i.id, 'GF-002', 9.00, 30, 1, TRUE
FROM suppliers s, items i WHERE s.code = 'SUP002' AND i.code = 'ITM004'
ON CONFLICT ON CONSTRAINT uk_supplier_item DO NOTHING;

-- Supply Items
INSERT INTO supply_items (supply_id, item_id, quantity, received_quantity, unit_price, tax_percent, total_price, batch_number, expiry_date)
SELECT sup.id, i.id, 30, 30, 78.00, 14, 2668.80, 'BATCH-001', CURRENT_DATE + INTERVAL '5 days'
FROM supplies sup, items i WHERE sup.supply_number = 'SUP-2024-001' AND i.code = 'ITM001';

INSERT INTO supply_items (supply_id, item_id, quantity, received_quantity, unit_price, tax_percent, total_price, batch_number, expiry_date)
SELECT sup.id, i.id, 10, 10, 245.00, 14, 2793.00, 'BATCH-002', CURRENT_DATE + INTERVAL '3 days'
FROM supplies sup, items i WHERE sup.supply_number = 'SUP-2024-001' AND i.code = 'ITM002';

INSERT INTO supply_items (supply_id, item_id, quantity, received_quantity, unit_price, tax_percent, total_price, batch_number, expiry_date)
SELECT sup.id, i.id, 50, 50, 14.00, 14, 798.00, 'BATCH-003', CURRENT_DATE + INTERVAL '7 days'
FROM supplies sup, items i WHERE sup.supply_number = 'SUP-2024-002' AND i.code = 'ITM003';

INSERT INTO supply_items (supply_id, item_id, quantity, received_quantity, unit_price, tax_percent, total_price, batch_number, expiry_date)
SELECT sup.id, i.id, 40, 40, 9.00, 14, 410.40, 'BATCH-004', CURRENT_DATE + INTERVAL '14 days'
FROM supplies sup, items i WHERE sup.supply_number = 'SUP-2024-002' AND i.code = 'ITM004';

-- Inventory for Main Warehouse
INSERT INTO inventory (branch_id, item_id, quantity, min_quantity, last_restock_date)
SELECT b.id, i.id, 30, 50, CURRENT_TIMESTAMP FROM branches b, items i WHERE b.code = 'MAIN' AND i.code = 'ITM001'
ON CONFLICT ON CONSTRAINT uk_inventory_branch_item DO UPDATE SET quantity = 30;

INSERT INTO inventory (branch_id, item_id, quantity, min_quantity, last_restock_date)
SELECT b.id, i.id, 10, 30, CURRENT_TIMESTAMP FROM branches b, items i WHERE b.code = 'MAIN' AND i.code = 'ITM002'
ON CONFLICT ON CONSTRAINT uk_inventory_branch_item DO UPDATE SET quantity = 10;

INSERT INTO inventory (branch_id, item_id, quantity, min_quantity, last_restock_date)
SELECT b.id, i.id, 50, 100, CURRENT_TIMESTAMP FROM branches b, items i WHERE b.code = 'MAIN' AND i.code = 'ITM003'
ON CONFLICT ON CONSTRAINT uk_inventory_branch_item DO UPDATE SET quantity = 50;

INSERT INTO inventory (branch_id, item_id, quantity, min_quantity, last_restock_date)
SELECT b.id, i.id, 40, 80, CURRENT_TIMESTAMP FROM branches b, items i WHERE b.code = 'MAIN' AND i.code = 'ITM004'
ON CONFLICT ON CONSTRAINT uk_inventory_branch_item DO UPDATE SET quantity = 40;

INSERT INTO inventory (branch_id, item_id, quantity, min_quantity, last_restock_date)
SELECT b.id, i.id, 25, 20, CURRENT_TIMESTAMP FROM branches b, items i WHERE b.code = 'MAIN' AND i.code = 'ITM005'
ON CONFLICT ON CONSTRAINT uk_inventory_branch_item DO UPDATE SET quantity = 25;

INSERT INTO inventory (branch_id, item_id, quantity, min_quantity, last_restock_date)
SELECT b.id, i.id, 150, 100, CURRENT_TIMESTAMP FROM branches b, items i WHERE b.code = 'MAIN' AND i.code = 'ITM006'
ON CONFLICT ON CONSTRAINT uk_inventory_branch_item DO UPDATE SET quantity = 150;

INSERT INTO inventory (branch_id, item_id, quantity, min_quantity, last_restock_date)
SELECT b.id, i.id, 15, 20, CURRENT_TIMESTAMP FROM branches b, items i WHERE b.code = 'MAIN' AND i.code = 'ITM007'
ON CONFLICT ON CONSTRAINT uk_inventory_branch_item DO UPDATE SET quantity = 15;

INSERT INTO inventory (branch_id, item_id, quantity, min_quantity, last_restock_date)
SELECT b.id, i.id, 300, 200, CURRENT_TIMESTAMP FROM branches b, items i WHERE b.code = 'MAIN' AND i.code = 'ITM008'
ON CONFLICT ON CONSTRAINT uk_inventory_branch_item DO UPDATE SET quantity = 300;

-- Inventory for Branch 1
INSERT INTO inventory (branch_id, item_id, quantity, min_quantity)
SELECT b.id, i.id, 10, 10 FROM branches b, items i WHERE b.code = 'BR001' AND i.code = 'ITM001'
ON CONFLICT ON CONSTRAINT uk_inventory_branch_item DO UPDATE SET quantity = 10;

INSERT INTO inventory (branch_id, item_id, quantity, min_quantity)
SELECT b.id, i.id, 5, 5 FROM branches b, items i WHERE b.code = 'BR001' AND i.code = 'ITM002'
ON CONFLICT ON CONSTRAINT uk_inventory_branch_item DO UPDATE SET quantity = 5;

INSERT INTO inventory (branch_id, item_id, quantity, min_quantity)
SELECT b.id, i.id, 20, 20 FROM branches b, items i WHERE b.code = 'BR001' AND i.code = 'ITM003'
ON CONFLICT ON CONSTRAINT uk_inventory_branch_item DO UPDATE SET quantity = 20;

INSERT INTO inventory (branch_id, item_id, quantity, min_quantity)
SELECT b.id, i.id, 50, 50 FROM branches b, items i WHERE b.code = 'BR001' AND i.code = 'ITM008'
ON CONFLICT ON CONSTRAINT uk_inventory_branch_item DO UPDATE SET quantity = 50;

-- Inventory Batches
INSERT INTO inventory_batches (inventory_id, batch_number, quantity, remaining_quantity, purchase_price, expiry_date, received_date, supply_id)
SELECT inv.id, 'BATCH-001', 30, 25, 78.00, CURRENT_DATE + INTERVAL '5 days', CURRENT_DATE, sup.id
FROM inventory inv
JOIN branches b ON inv.branch_id = b.id
JOIN items i ON inv.item_id = i.id
JOIN supplies sup ON sup.supply_number = 'SUP-2024-001'
WHERE b.code = 'MAIN' AND i.code = 'ITM001';

INSERT INTO inventory_batches (inventory_id, batch_number, quantity, remaining_quantity, purchase_price, expiry_date, received_date, supply_id)
SELECT inv.id, 'BATCH-002', 10, 8, 245.00, CURRENT_DATE + INTERVAL '3 days', CURRENT_DATE, sup.id
FROM inventory inv
JOIN branches b ON inv.branch_id = b.id
JOIN items i ON inv.item_id = i.id
JOIN supplies sup ON sup.supply_number = 'SUP-2024-001'
WHERE b.code = 'MAIN' AND i.code = 'ITM002';

-- Transfer Items
INSERT INTO transfer_items (transfer_id, item_id, requested_quantity, approved_quantity, shipped_quantity, received_quantity, notes)
SELECT t.id, i.id, 10, 10, 10, 10, 'Urgent need'
FROM transfers t, items i WHERE t.transfer_number = 'TRF-2024-001' AND i.code = 'ITM001';

INSERT INTO transfer_items (transfer_id, item_id, requested_quantity, approved_quantity, shipped_quantity, received_quantity, notes)
SELECT t.id, i.id, 5, 5, 5, 5, NULL
FROM transfers t, items i WHERE t.transfer_number = 'TRF-2024-001' AND i.code = 'ITM002';

INSERT INTO transfer_items (transfer_id, item_id, requested_quantity, approved_quantity, shipped_quantity, received_quantity, notes)
SELECT t.id, i.id, 20, 20, 20, 20, NULL
FROM transfers t, items i WHERE t.transfer_number = 'TRF-2024-001' AND i.code = 'ITM003';

-- Damages
INSERT INTO damages (damage_number, branch_id, item_id, quantity, unit_cost, total_cost, reason_id, description, status, registered_by, registered_at, approved_by, approved_at)
SELECT 'DMG-2024-001', b.id, i.id, 2, 245.00, 490.00, dr.id, 'Found expired during inspection', 'approved', 
       (SELECT id FROM users WHERE username = 'warehouse_mgr'), CURRENT_TIMESTAMP,
       (SELECT id FROM users WHERE username = 'admin'), CURRENT_TIMESTAMP
FROM branches b, items i, damage_reasons dr
WHERE b.code = 'MAIN' AND i.code = 'ITM002' AND dr.code = 'EXPIRED'
ON CONFLICT (damage_number) DO NOTHING;

INSERT INTO damages (damage_number, branch_id, item_id, quantity, unit_cost, total_cost, reason_id, description, status, registered_by, registered_at)
SELECT 'DMG-2024-002', b.id, i.id, 3, 78.00, 234.00, dr.id, 'Refrigerator malfunction', 'pending', 
       (SELECT id FROM users WHERE username = 'branch1_sup'), CURRENT_TIMESTAMP
FROM branches b, items i, damage_reasons dr
WHERE b.code = 'BR001' AND i.code = 'ITM001' AND dr.code = 'STORAGE'
ON CONFLICT (damage_number) DO NOTHING;

-- Supplier Returns
INSERT INTO supplier_returns (return_number, supply_id, supplier_id, item_id, quantity, unit_price, total_amount, reason, description, status, registered_by, registered_at, approved_by, approved_at)
SELECT 'RET-2024-001', sup.id, s.id, i.id, 5, 78.00, 390.00, 'Defective quality', 'Chicken had bad smell', 'approved',
       (SELECT id FROM users WHERE username = 'warehouse_mgr'), CURRENT_TIMESTAMP,
       (SELECT id FROM users WHERE username = 'admin'), CURRENT_TIMESTAMP
FROM supplies sup, suppliers s, items i
WHERE sup.supply_number = 'SUP-2024-001' AND s.code = 'SUP001' AND i.code = 'ITM001'
ON CONFLICT (return_number) DO NOTHING;

-- Inventory Transactions
INSERT INTO inventory_transactions (branch_id, item_id, operation_type, quantity, quantity_before, quantity_after, unit_cost, reference_type, created_by)
SELECT b.id, i.id, 'supply', 30, 0, 30, 78.00, 'supply', u.id
FROM branches b, items i, users u WHERE b.code = 'MAIN' AND i.code = 'ITM001' AND u.username = 'warehouse_mgr';

INSERT INTO inventory_transactions (branch_id, item_id, operation_type, quantity, quantity_before, quantity_after, unit_cost, reference_type, created_by)
SELECT b.id, i.id, 'supply', 10, 0, 10, 245.00, 'supply', u.id
FROM branches b, items i, users u WHERE b.code = 'MAIN' AND i.code = 'ITM002' AND u.username = 'warehouse_mgr';

INSERT INTO inventory_transactions (branch_id, item_id, operation_type, quantity, quantity_before, quantity_after, reference_type, created_by)
SELECT b.id, i.id, 'transfer_out', 10, 30, 20, 'transfer', u.id
FROM branches b, items i, users u WHERE b.code = 'MAIN' AND i.code = 'ITM001' AND u.username = 'warehouse_mgr';

INSERT INTO inventory_transactions (branch_id, item_id, operation_type, quantity, quantity_before, quantity_after, reference_type, created_by)
SELECT b.id, i.id, 'transfer_in', 10, 0, 10, 'transfer', u.id
FROM branches b, items i, users u WHERE b.code = 'BR001' AND i.code = 'ITM001' AND u.username = 'branch1_sup';

INSERT INTO inventory_transactions (branch_id, item_id, operation_type, quantity, quantity_before, quantity_after, unit_cost, reference_type, created_by)
SELECT b.id, i.id, 'damage', 2, 10, 8, 245.00, 'damage', u.id
FROM branches b, items i, users u WHERE b.code = 'MAIN' AND i.code = 'ITM002' AND u.username = 'warehouse_mgr';

INSERT INTO inventory_transactions (branch_id, item_id, operation_type, quantity, quantity_before, quantity_after, unit_cost, reference_type, created_by)
SELECT b.id, i.id, 'return', 5, 25, 20, 78.00, 'supplier_return', u.id
FROM branches b, items i, users u WHERE b.code = 'MAIN' AND i.code = 'ITM001' AND u.username = 'warehouse_mgr';

INSERT INTO inventory_transactions (branch_id, item_id, operation_type, quantity, quantity_before, quantity_after, reference_type, created_by)
SELECT b.id, i.id, 'consumption', 0.5, 10, 9.5, 'order', u.id
FROM branches b, items i, users u WHERE b.code = 'BR001' AND i.code = 'ITM001' AND u.username = 'cashier1';

-- Menu Item Ingredients
INSERT INTO menu_item_ingredients (menu_item_id, item_id, quantity, unit_id, is_optional)
SELECT mi.id, i.id, 0.250, u.id, FALSE
FROM menu_items mi, items i, units u
WHERE mi.code = 'MENU001' AND i.code = 'ITM001' AND u.code = 'KG';

INSERT INTO menu_item_ingredients (menu_item_id, item_id, quantity, unit_id, is_optional)
SELECT mi.id, i.id, 0.100, u.id, FALSE
FROM menu_items mi, items i, units u
WHERE mi.code = 'MENU001' AND i.code = 'ITM006' AND u.code = 'KG';

-- Daily Count Items
INSERT INTO daily_inventory_count_items (count_id, item_id, system_quantity, actual_quantity, variance_reason)
SELECT dic.id, i.id, 10, 10, NULL
FROM daily_inventory_counts dic, items i, branches b
WHERE dic.branch_id = b.id AND b.code = 'BR001' AND i.code = 'ITM001';

INSERT INTO daily_inventory_count_items (count_id, item_id, system_quantity, actual_quantity, variance_reason)
SELECT dic.id, i.id, 5, 5, NULL
FROM daily_inventory_counts dic, items i, branches b
WHERE dic.branch_id = b.id AND b.code = 'BR001' AND i.code = 'ITM002';

INSERT INTO daily_inventory_count_items (count_id, item_id, system_quantity, actual_quantity, variance_reason)
SELECT dic.id, i.id, 20, 19, 'One tomato was damaged'
FROM daily_inventory_counts dic, items i, branches b
WHERE dic.branch_id = b.id AND b.code = 'BR001' AND i.code = 'ITM003';
