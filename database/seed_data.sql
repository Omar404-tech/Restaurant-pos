-- Seed Data for Restaurant Management System

-- Insert default roles
INSERT INTO roles (name, name_ar, description, permissions, is_system_role) VALUES
('admin', 'Admin', 'Full system access', '{"all": true}', TRUE),
('warehouse_manager', 'Warehouse Manager', 'Warehouse and supplier management', '{"suppliers": true, "inventory": true}', TRUE),
('branch_supervisor', 'Branch Supervisor', 'Branch operations management', '{"branch_inventory": true}', TRUE),
('chef', 'Chef', 'Kitchen operations', '{"kitchen_pos": true}', TRUE),
('cashier', 'Cashier', 'POS and order management', '{"cashier_pos": true}', TRUE)
ON CONFLICT (name) DO NOTHING;

-- Insert default damage reasons
INSERT INTO damage_reasons (code, name, name_ar, sort_order) VALUES
('EXPIRED', 'Expired', 'Expired', 1),
('STORAGE', 'Poor Storage', 'Poor Storage', 2),
('TRANSPORT', 'Transport Damage', 'Transport Damage', 3),
('CONTAMINATION', 'Contamination', 'Contamination', 4),
('MOISTURE', 'Moisture/Leak', 'Moisture/Leak', 5),
('HEAT', 'Heat/Fire', 'Heat/Fire', 6),
('OTHER', 'Other', 'Other', 99)
ON CONFLICT (code) DO NOTHING;

-- Insert main warehouse as default branch
INSERT INTO branches (code, name, name_ar, is_main_warehouse, status) VALUES
('MAIN', 'Main Warehouse', 'Main Warehouse', TRUE, 'active'),
('BR001', 'Branch 1', 'Branch 1', FALSE, 'active'),
('BR002', 'Branch 2', 'Branch 2', FALSE, 'active')
ON CONFLICT (code) DO NOTHING;
