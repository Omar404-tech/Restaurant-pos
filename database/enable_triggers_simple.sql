-- =====================================================
-- Step 1: Drop existing triggers if they exist
-- =====================================================
DROP TRIGGER IF EXISTS trg_update_inventory_on_damage ON damages;
DROP TRIGGER IF EXISTS trg_update_inventory_on_transfer ON transfers;
DROP TRIGGER IF EXISTS trg_update_inventory_on_return ON supplier_returns;

-- =====================================================
-- Step 2: Create triggers for existing functions
-- =====================================================

-- Trigger for damages
CREATE TRIGGER trg_update_inventory_on_damage
    AFTER UPDATE ON damages
    FOR EACH ROW
    EXECUTE FUNCTION update_inventory_on_damage();

-- Trigger for transfers  
CREATE TRIGGER trg_update_inventory_on_transfer
    AFTER UPDATE ON transfers
    FOR EACH ROW
    EXECUTE FUNCTION update_inventory_on_transfer();

-- Trigger for supplier returns
CREATE TRIGGER trg_update_inventory_on_return
    AFTER UPDATE ON supplier_returns
    FOR EACH ROW
    EXECUTE FUNCTION update_inventory_on_return();

-- =====================================================
-- Step 3: Verify triggers were created
-- =====================================================
SELECT tgname, tgrelid::regclass as table_name
FROM pg_trigger 
WHERE tgname IN ('trg_update_inventory_on_damage', 'trg_update_inventory_on_transfer', 'trg_update_inventory_on_return');
