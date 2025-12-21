--
-- PostgreSQL database dump
--


-- Dumped from database version 18.1
-- Dumped by pg_dump version 18.1

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: uuid-ossp; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA public;


--
-- Name: EXTENSION "uuid-ossp"; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION "uuid-ossp" IS 'generate universally unique identifiers (UUIDs)';


--
-- Name: branch_return_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.branch_return_status AS ENUM (
    'pending',
    'approved',
    'rejected',
    'in_transit',
    'received',
    'cancelled'
);


--
-- Name: branch_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.branch_status AS ENUM (
    'active',
    'inactive',
    'maintenance'
);


--
-- Name: damage_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.damage_status AS ENUM (
    'pending',
    'approved',
    'rejected'
);


--
-- Name: inventory_operation; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.inventory_operation AS ENUM (
    'supply',
    'transfer_out',
    'transfer_in',
    'consumption',
    'damage',
    'return',
    'adjustment'
);


--
-- Name: item_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.item_status AS ENUM (
    'active',
    'inactive'
);


--
-- Name: order_payment_method; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.order_payment_method AS ENUM (
    'cash',
    'visa',
    'instapay',
    'wallet'
);


--
-- Name: order_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.order_status AS ENUM (
    'new',
    'pending_payment',
    'paid',
    'in_kitchen',
    'preparing',
    'ready',
    'delivered',
    'cancelled'
);


--
-- Name: payment_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.payment_status AS ENUM (
    'paid',
    'pending',
    'partial'
);


--
-- Name: purchase_request_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.purchase_request_status AS ENUM (
    'draft',
    'pending',
    'approved',
    'rejected',
    'ordered',
    'partially_received',
    'completed',
    'cancelled'
);


--
-- Name: return_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.return_status AS ENUM (
    'pending',
    'approved',
    'rejected',
    'received'
);


--
-- Name: supplier_payment_method; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.supplier_payment_method AS ENUM (
    'cash',
    'credit'
);


--
-- Name: supplier_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.supplier_status AS ENUM (
    'active',
    'inactive'
);


--
-- Name: transfer_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.transfer_status AS ENUM (
    'pending',
    'approved',
    'rejected',
    'received',
    'cancelled'
);


--
-- Name: user_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.user_status AS ENUM (
    'active',
    'inactive',
    'suspended'
);


--
-- Name: calculate_branch_inventory_total(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.calculate_branch_inventory_total() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- total_quantity = partial_quantity * content_quantity
    -- Example: 5 bags * 10 kg per bag = 50 kg total
    NEW.total_quantity := COALESCE(NEW.partial_quantity, 0) * COALESCE(NEW.content_quantity, 0);
    NEW.updated_at := CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$;


--
-- Name: calculate_inventory_period(uuid, date, date); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.calculate_inventory_period(p_branch_id uuid, p_start_date date, p_end_date date) RETURNS TABLE(item_id uuid, opening_balance numeric, incoming numeric, consumption numeric, closing_balance numeric)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
    SELECT 
        inv.item_id,
        -- Opening balance: quantity at start of period
        COALESCE(
            (SELECT SUM(CASE 
                WHEN it.operation_type IN ('supply', 'transfer_in', 'adjustment') THEN it.quantity
                WHEN it.operation_type IN ('transfer_out', 'damage', 'return', 'consumption') THEN -it.quantity
                ELSE 0
            END)
            FROM inventory_transactions it
            WHERE it.branch_id = p_branch_id 
            AND it.item_id = inv.item_id
            AND it.created_at < p_start_date::timestamp), 0
        )::DECIMAL as opening_balance,
        -- Incoming: supplies + transfers in during period
        COALESCE(
            (SELECT SUM(it.quantity)
            FROM inventory_transactions it
            WHERE it.branch_id = p_branch_id 
            AND it.item_id = inv.item_id
            AND it.operation_type IN ('supply', 'transfer_in')
            AND it.created_at >= p_start_date::timestamp
            AND it.created_at <= p_end_date::timestamp), 0
        )::DECIMAL as incoming,
        -- Consumption: all outgoing during period
        COALESCE(
            (SELECT SUM(it.quantity)
            FROM inventory_transactions it
            WHERE it.branch_id = p_branch_id 
            AND it.item_id = inv.item_id
            AND it.operation_type IN ('transfer_out', 'damage', 'return', 'consumption')
            AND it.created_at >= p_start_date::timestamp
            AND it.created_at <= p_end_date::timestamp), 0
        )::DECIMAL as consumption,
        -- Closing balance
        inv.quantity::DECIMAL as closing_balance
    FROM inventory inv
    WHERE inv.branch_id = p_branch_id;
END;
$$;


--
-- Name: generate_branch_inventory_doc_number(character varying); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.generate_branch_inventory_doc_number(branch_code character varying) RETURNS character varying
    LANGUAGE plpgsql
    AS $$
DECLARE
    prefix VARCHAR;
    year_month VARCHAR;
    seq_num INTEGER;
    new_number VARCHAR;
BEGIN
    prefix := 'INV-' || branch_code;
    year_month := TO_CHAR(CURRENT_DATE, 'YYYY-MM');
    
    SELECT COALESCE(MAX(CAST(SUBSTRING(document_number FROM LENGTH(prefix) + 10) AS INTEGER)), 0) + 1
    INTO seq_num
    FROM inventory
    WHERE document_number LIKE prefix || '-' || year_month || '-%';
    
    new_number := prefix || '-' || year_month || '-' || LPAD(seq_num::TEXT, 4, '0');
    RETURN new_number;
END;
$$;


--
-- Name: generate_branch_return_number(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.generate_branch_return_number() RETURNS character varying
    LANGUAGE plpgsql
    AS $$
DECLARE
    prefix VARCHAR;
    year_month VARCHAR;
    seq_num INTEGER;
    new_number VARCHAR;
BEGIN
    SELECT value INTO prefix FROM system_settings WHERE key = 'branch_return_prefix';
    prefix := COALESCE(prefix, 'BRT');
    year_month := TO_CHAR(CURRENT_DATE, 'YYYY-MM');
    
    SELECT COALESCE(MAX(CAST(SUBSTRING(return_number FROM LENGTH(prefix) + 10) AS INTEGER)), 0) + 1
    INTO seq_num
    FROM branch_returns
    WHERE return_number LIKE prefix || '-' || year_month || '-%';
    
    new_number := prefix || '-' || year_month || '-' || LPAD(seq_num::TEXT, 4, '0');
    RETURN new_number;
END;
$$;


--
-- Name: generate_purchase_order_number(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.generate_purchase_order_number() RETURNS character varying
    LANGUAGE plpgsql
    AS $$
DECLARE
    prefix VARCHAR;
    year_month VARCHAR;
    seq_num INTEGER;
    new_number VARCHAR;
BEGIN
    SELECT value INTO prefix FROM system_settings WHERE key = 'purchase_order_prefix';
    prefix := COALESCE(prefix, 'PO');
    year_month := TO_CHAR(CURRENT_DATE, 'YYYY-MM');
    
    SELECT COALESCE(MAX(CAST(SUBSTRING(order_number FROM LENGTH(prefix) + 10) AS INTEGER)), 0) + 1
    INTO seq_num
    FROM purchase_orders
    WHERE order_number LIKE prefix || '-' || year_month || '-%';
    
    new_number := prefix || '-' || year_month || '-' || LPAD(seq_num::TEXT, 4, '0');
    RETURN new_number;
END;
$$;


--
-- Name: generate_purchase_request_number(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.generate_purchase_request_number() RETURNS character varying
    LANGUAGE plpgsql
    AS $$
DECLARE
    prefix VARCHAR;
    year_month VARCHAR;
    seq_num INTEGER;
    new_number VARCHAR;
BEGIN
    SELECT value INTO prefix FROM system_settings WHERE key = 'purchase_request_prefix';
    prefix := COALESCE(prefix, 'PR');
    year_month := TO_CHAR(CURRENT_DATE, 'YYYY-MM');
    
    SELECT COALESCE(MAX(CAST(SUBSTRING(request_number FROM LENGTH(prefix) + 10) AS INTEGER)), 0) + 1
    INTO seq_num
    FROM purchase_requests
    WHERE request_number LIKE prefix || '-' || year_month || '-%';
    
    new_number := prefix || '-' || year_month || '-' || LPAD(seq_num::TEXT, 4, '0');
    RETURN new_number;
END;
$$;


--
-- Name: generate_sequence_number(character varying, character varying, character varying); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.generate_sequence_number(p_prefix character varying, p_table character varying, p_column character varying) RETURNS character varying
    LANGUAGE plpgsql
    AS $_$
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
$_$;


--
-- Name: update_branch_return_totals(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_branch_return_totals() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    UPDATE branch_returns SET
        total_items = (SELECT COUNT(*) FROM branch_return_items WHERE return_id = COALESCE(NEW.return_id, OLD.return_id)),
        total_quantity = (SELECT COALESCE(SUM(requested_quantity), 0) FROM branch_return_items WHERE return_id = COALESCE(NEW.return_id, OLD.return_id)),
        total_value = (SELECT COALESCE(SUM(total_value), 0) FROM branch_return_items WHERE return_id = COALESCE(NEW.return_id, OLD.return_id)),
        updated_at = CURRENT_TIMESTAMP
    WHERE id = COALESCE(NEW.return_id, OLD.return_id);
    
    RETURN COALESCE(NEW, OLD);
END;
$$;


--
-- Name: update_inventory_on_damage(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_inventory_on_damage() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
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
$$;


--
-- Name: update_inventory_on_return(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_inventory_on_return() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
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
$$;


--
-- Name: update_inventory_on_supply(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_inventory_on_supply() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
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
$$;


--
-- Name: update_inventory_on_transfer(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_inventory_on_transfer() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
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
$$;


--
-- Name: update_inventory_period(uuid, date, date); Type: PROCEDURE; Schema: public; Owner: -
--

CREATE PROCEDURE public.update_inventory_period(IN p_branch_id uuid, IN p_start_date date, IN p_end_date date)
    LANGUAGE plpgsql
    AS $$
DECLARE
    rec RECORD;
BEGIN
    FOR rec IN 
        SELECT * FROM calculate_inventory_period(p_branch_id, p_start_date, p_end_date)
    LOOP
        UPDATE inventory 
        SET 
            opening_balance = rec.opening_balance,
            incoming_quantity = rec.incoming,
            consumption_quantity = rec.consumption,
            period_start_date = p_start_date,
            period_end_date = p_end_date,
            updated_at = CURRENT_TIMESTAMP
        WHERE branch_id = p_branch_id AND item_id = rec.item_id;
    END LOOP;
END;
$$;


--
-- Name: update_purchase_request_totals(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_purchase_request_totals() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    UPDATE purchase_requests SET
        total_items = (SELECT COUNT(*) FROM purchase_request_items WHERE request_id = COALESCE(NEW.request_id, OLD.request_id)),
        total_quantity = (SELECT COALESCE(SUM(requested_quantity), 0) FROM purchase_request_items WHERE request_id = COALESCE(NEW.request_id, OLD.request_id)),
        estimated_cost = (SELECT COALESCE(SUM(estimated_total), 0) FROM purchase_request_items WHERE request_id = COALESCE(NEW.request_id, OLD.request_id)),
        updated_at = CURRENT_TIMESTAMP
    WHERE id = COALESCE(NEW.request_id, OLD.request_id);
    
    RETURN COALESCE(NEW, OLD);
END;
$$;


--
-- Name: update_supplier_balance(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_supplier_balance() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
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
$$;


--
-- Name: update_supplier_balance_on_return(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_supplier_balance_on_return() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF NEW.status = 'approved' AND (OLD.status IS NULL OR OLD.status != 'approved') THEN
        UPDATE suppliers 
        SET current_balance = current_balance - NEW.total_amount,
            updated_at = CURRENT_TIMESTAMP
        WHERE id = NEW.supplier_id;
    END IF;
    RETURN NEW;
END;
$$;


--
-- Name: update_updated_at_column(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_updated_at_column() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: alert_settings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.alert_settings (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    branch_id uuid,
    alert_type character varying(50) NOT NULL,
    is_enabled boolean DEFAULT true,
    threshold_value numeric(12,3),
    threshold_days integer,
    notify_roles text[],
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: audit_logs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.audit_logs (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    user_id uuid,
    action character varying(50) NOT NULL,
    table_name character varying(100),
    record_id uuid,
    old_values jsonb,
    new_values jsonb,
    ip_address inet,
    user_agent text,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: auth_group; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.auth_group (
    id integer NOT NULL,
    name character varying(150) NOT NULL
);


--
-- Name: auth_group_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.auth_group ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.auth_group_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: auth_group_permissions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.auth_group_permissions (
    id bigint NOT NULL,
    group_id integer NOT NULL,
    permission_id integer NOT NULL
);


--
-- Name: auth_group_permissions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.auth_group_permissions ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.auth_group_permissions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: auth_permission; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.auth_permission (
    id integer NOT NULL,
    name character varying(255) NOT NULL,
    content_type_id integer NOT NULL,
    codename character varying(100) NOT NULL
);


--
-- Name: auth_permission_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.auth_permission ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.auth_permission_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: branch_return_items; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.branch_return_items (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    return_id uuid NOT NULL,
    item_id uuid NOT NULL,
    requested_quantity numeric(12,3) NOT NULL,
    approved_quantity numeric(12,3),
    shipped_quantity numeric(12,3),
    received_quantity numeric(12,3),
    unit_cost numeric(12,2),
    total_value numeric(12,2),
    item_reason text,
    batch_id uuid,
    notes text,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_return_qty CHECK ((requested_quantity > (0)::numeric))
);


--
-- Name: branch_return_reasons; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.branch_return_reasons (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    code character varying(20) NOT NULL,
    name character varying(100) NOT NULL,
    name_ar character varying(100) NOT NULL,
    description text,
    is_active boolean DEFAULT true,
    sort_order integer DEFAULT 0,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: branch_returns; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.branch_returns (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    return_number character varying(30) NOT NULL,
    return_date date DEFAULT CURRENT_DATE NOT NULL,
    from_branch_id uuid NOT NULL,
    to_branch_id uuid NOT NULL,
    status public.branch_return_status DEFAULT 'pending'::public.branch_return_status,
    return_reason text NOT NULL,
    total_items integer DEFAULT 0,
    total_quantity numeric(12,3) DEFAULT 0,
    total_value numeric(12,2) DEFAULT 0,
    notes text,
    requested_by uuid NOT NULL,
    requested_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    approved_by uuid,
    approved_at timestamp with time zone,
    rejected_by uuid,
    rejected_at timestamp with time zone,
    rejection_reason text,
    shipped_at timestamp with time zone,
    received_by uuid,
    received_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_different_branches CHECK ((from_branch_id <> to_branch_id))
);


--
-- Name: branch_settings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.branch_settings (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    branch_id uuid NOT NULL,
    key character varying(100) NOT NULL,
    value text,
    updated_by uuid,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: branches; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.branches (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    code character varying(20) NOT NULL,
    name character varying(100) NOT NULL,
    name_ar character varying(100) NOT NULL,
    address text,
    phone character varying(20),
    email character varying(100),
    status public.branch_status DEFAULT 'active'::public.branch_status,
    is_main_warehouse boolean DEFAULT false,
    opening_time time without time zone,
    closing_time time without time zone,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: categories; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.categories (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    code character varying(20) NOT NULL,
    name character varying(100) NOT NULL,
    name_ar character varying(100) NOT NULL,
    description text,
    parent_id uuid,
    sort_order integer DEFAULT 0,
    is_active boolean DEFAULT true,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: daily_inventory_count_items; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.daily_inventory_count_items (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    count_id uuid NOT NULL,
    item_id uuid NOT NULL,
    system_quantity numeric(12,3) NOT NULL,
    actual_quantity numeric(12,3) NOT NULL,
    variance_reason text,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: daily_inventory_counts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.daily_inventory_counts (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    branch_id uuid NOT NULL,
    count_date date NOT NULL,
    count_type character varying(20) NOT NULL,
    status character varying(20) DEFAULT 'draft'::character varying,
    notes text,
    counted_by uuid NOT NULL,
    submitted_at timestamp with time zone,
    approved_by uuid,
    approved_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: damage_reasons; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.damage_reasons (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    code character varying(20) NOT NULL,
    name character varying(100) NOT NULL,
    name_ar character varying(100) NOT NULL,
    description text,
    is_active boolean DEFAULT true,
    sort_order integer DEFAULT 0,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: damages; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.damages (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    damage_number character varying(30) NOT NULL,
    branch_id uuid NOT NULL,
    item_id uuid NOT NULL,
    quantity numeric(12,3) NOT NULL,
    unit_cost numeric(12,2),
    total_cost numeric(12,2),
    reason_id uuid NOT NULL,
    description text,
    image_url text,
    batch_id uuid,
    status public.damage_status DEFAULT 'pending'::public.damage_status,
    registered_by uuid NOT NULL,
    registered_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    approved_by uuid,
    approved_at timestamp with time zone,
    rejected_by uuid,
    rejected_at timestamp with time zone,
    rejection_reason text,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_damage_quantity CHECK ((quantity > (0)::numeric))
);


--
-- Name: django_content_type; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.django_content_type (
    id integer NOT NULL,
    app_label character varying(100) NOT NULL,
    model character varying(100) NOT NULL
);


--
-- Name: django_content_type_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.django_content_type ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.django_content_type_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: django_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.django_migrations (
    id bigint NOT NULL,
    app character varying(255) NOT NULL,
    name character varying(255) NOT NULL,
    applied timestamp with time zone NOT NULL
);


--
-- Name: django_migrations_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.django_migrations ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.django_migrations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: inventory; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.inventory (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    branch_id uuid NOT NULL,
    item_id uuid NOT NULL,
    quantity numeric(12,3) DEFAULT 0 NOT NULL,
    reserved_quantity numeric(12,3) DEFAULT 0,
    min_quantity numeric(12,3) DEFAULT 0,
    last_restock_date timestamp with time zone,
    last_count_date timestamp with time zone,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    opening_balance numeric(12,3) DEFAULT 0,
    incoming_quantity numeric(12,3) DEFAULT 0,
    consumption_quantity numeric(12,3) DEFAULT 0,
    consumption_description text,
    period_start_date date,
    period_end_date date,
    entry_date date DEFAULT CURRENT_DATE,
    document_number character varying(30),
    partial_quantity numeric(12,3) DEFAULT 0,
    content_quantity numeric(12,3) DEFAULT 0,
    total_quantity numeric(12,3) DEFAULT 0,
    content_description text,
    CONSTRAINT chk_inventory_quantity CHECK ((quantity >= (0)::numeric))
);


--
-- Name: COLUMN inventory.opening_balance; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.inventory.opening_balance IS 'Opening balance at start of period (Ø±ØµÙŠØ¯ Ø£ÙˆÙ„ Ø§Ù„Ù…Ø¯Ø©)';


--
-- Name: COLUMN inventory.incoming_quantity; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.inventory.incoming_quantity IS 'Total incoming quantity in period (Ø§Ù„ÙˆØ§Ø±Ø¯)';


--
-- Name: COLUMN inventory.consumption_quantity; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.inventory.consumption_quantity IS 'Total consumption in period (Ø§Ù„Ù…Ø­ØªÙˆÙ‰ Ø¨Ø§Ù„ÙƒÙ…ÙŠØ©)';


--
-- Name: COLUMN inventory.period_start_date; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.inventory.period_start_date IS 'Start date of tracking period';


--
-- Name: COLUMN inventory.period_end_date; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.inventory.period_end_date IS 'End date of tracking period';


--
-- Name: COLUMN inventory.entry_date; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.inventory.entry_date IS 'Entry date - Ø§Ù„ØªØ§Ø±ÙŠØ®';


--
-- Name: COLUMN inventory.document_number; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.inventory.document_number IS 'Document number - Ø±Ù‚Ù… Ø§Ù„Ù…Ø³ØªÙ†Ø¯';


--
-- Name: COLUMN inventory.partial_quantity; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.inventory.partial_quantity IS 'Number of units (bags, boxes, cans) - entered manually when adding item';


--
-- Name: COLUMN inventory.content_quantity; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.inventory.content_quantity IS 'Content per unit (kg per bag, items per box) - the unit itself';


--
-- Name: COLUMN inventory.total_quantity; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.inventory.total_quantity IS 'Total = partial * content (e.g., 5 bags * 10 kg = 50 kg total)';


--
-- Name: COLUMN inventory.content_description; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.inventory.content_description IS 'Description of content (e.g., divided into plates, cartons)';


--
-- Name: inventory_batches; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.inventory_batches (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    inventory_id uuid NOT NULL,
    batch_number character varying(50),
    quantity numeric(12,3) NOT NULL,
    remaining_quantity numeric(12,3) NOT NULL,
    purchase_price numeric(12,2),
    production_date date,
    expiry_date date,
    received_date date DEFAULT CURRENT_DATE NOT NULL,
    supply_id uuid,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_batch_quantity CHECK ((quantity > (0)::numeric)),
    CONSTRAINT chk_batch_remaining CHECK ((remaining_quantity >= (0)::numeric))
);


--
-- Name: inventory_transactions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.inventory_transactions (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    branch_id uuid NOT NULL,
    item_id uuid NOT NULL,
    operation_type public.inventory_operation NOT NULL,
    quantity numeric(12,3) NOT NULL,
    quantity_before numeric(12,3) NOT NULL,
    quantity_after numeric(12,3) NOT NULL,
    unit_cost numeric(12,2),
    reference_type character varying(50),
    reference_id uuid,
    batch_id uuid,
    notes text,
    created_by uuid NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_transaction_qty CHECK ((quantity <> (0)::numeric))
);


--
-- Name: items; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.items (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    code character varying(50) NOT NULL,
    barcode character varying(50),
    name character varying(150) NOT NULL,
    name_ar character varying(150) NOT NULL,
    description text,
    category_id uuid,
    unit_id uuid NOT NULL,
    purchase_price numeric(12,2) DEFAULT 0,
    selling_price numeric(12,2) DEFAULT 0,
    min_stock_level numeric(12,3) DEFAULT 0,
    max_stock_level numeric(12,3),
    reorder_level numeric(12,3),
    is_perishable boolean DEFAULT false,
    shelf_life_days integer,
    storage_conditions text,
    status public.item_status DEFAULT 'active'::public.item_status,
    image_url text,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    created_by uuid,
    CONSTRAINT chk_item_prices CHECK (((purchase_price >= (0)::numeric) AND (selling_price >= (0)::numeric)))
);


--
-- Name: menu_categories; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.menu_categories (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    code character varying(20) NOT NULL,
    name character varying(100) NOT NULL,
    name_ar character varying(100) NOT NULL,
    description text,
    image_url text,
    parent_id uuid,
    sort_order integer DEFAULT 0,
    is_active boolean DEFAULT true,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: menu_item_ingredients; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.menu_item_ingredients (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    menu_item_id uuid NOT NULL,
    item_id uuid NOT NULL,
    quantity numeric(12,4) NOT NULL,
    unit_id uuid NOT NULL,
    is_optional boolean DEFAULT false,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_ingredient_qty CHECK ((quantity > (0)::numeric))
);


--
-- Name: menu_items; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.menu_items (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    code character varying(50) NOT NULL,
    name character varying(150) NOT NULL,
    name_ar character varying(150) NOT NULL,
    description text,
    description_ar text,
    category_id uuid,
    price numeric(12,2) NOT NULL,
    cost numeric(12,2) DEFAULT 0,
    tax_percent numeric(5,2) DEFAULT 0,
    image_url text,
    preparation_time_minutes integer,
    calories integer,
    is_available boolean DEFAULT true,
    is_active boolean DEFAULT true,
    sort_order integer DEFAULT 0,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_menu_item_price CHECK ((price >= (0)::numeric))
);


--
-- Name: notifications; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.notifications (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    user_id uuid,
    branch_id uuid,
    type character varying(50) NOT NULL,
    title character varying(200) NOT NULL,
    message text NOT NULL,
    priority character varying(20) DEFAULT 'normal'::character varying,
    reference_type character varying(50),
    reference_id uuid,
    is_read boolean DEFAULT false,
    read_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    expires_at timestamp with time zone
);


--
-- Name: order_items; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.order_items (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    order_id uuid NOT NULL,
    menu_item_id uuid NOT NULL,
    quantity integer NOT NULL,
    unit_price numeric(12,2) NOT NULL,
    discount_amount numeric(12,2) DEFAULT 0,
    total_price numeric(12,2) NOT NULL,
    notes text,
    status character varying(20) DEFAULT 'pending'::character varying,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_order_item_qty CHECK ((quantity > 0))
);


--
-- Name: orders; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.orders (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    order_number character varying(30) NOT NULL,
    branch_id uuid NOT NULL,
    order_type character varying(20) DEFAULT 'takeaway'::character varying,
    customer_name character varying(100),
    customer_phone character varying(20),
    subtotal numeric(12,2) DEFAULT 0 NOT NULL,
    tax_amount numeric(12,2) DEFAULT 0,
    discount_amount numeric(12,2) DEFAULT 0,
    discount_reason text,
    total_amount numeric(12,2) DEFAULT 0 NOT NULL,
    payment_method public.order_payment_method,
    payment_reference character varying(100),
    status public.order_status DEFAULT 'new'::public.order_status,
    notes text,
    kitchen_notes text,
    cashier_id uuid NOT NULL,
    chef_id uuid,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    paid_at timestamp with time zone,
    sent_to_kitchen_at timestamp with time zone,
    preparation_started_at timestamp with time zone,
    ready_at timestamp with time zone,
    delivered_at timestamp with time zone,
    cancelled_at timestamp with time zone,
    cancelled_by uuid,
    cancellation_reason text,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_order_amounts CHECK ((total_amount >= (0)::numeric))
);


--
-- Name: purchase_order_items; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.purchase_order_items (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    order_id uuid NOT NULL,
    item_id uuid NOT NULL,
    request_item_id uuid,
    quantity numeric(12,3) NOT NULL,
    unit_price numeric(12,2) NOT NULL,
    tax_percent numeric(5,2) DEFAULT 0,
    discount_percent numeric(5,2) DEFAULT 0,
    total_price numeric(12,2) NOT NULL,
    received_quantity numeric(12,3) DEFAULT 0,
    notes text,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_po_item_qty CHECK ((quantity > (0)::numeric))
);


--
-- Name: purchase_orders; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.purchase_orders (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    order_number character varying(30) NOT NULL,
    order_date date DEFAULT CURRENT_DATE NOT NULL,
    request_id uuid,
    supplier_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    subtotal numeric(12,2) DEFAULT 0 NOT NULL,
    tax_amount numeric(12,2) DEFAULT 0,
    discount_amount numeric(12,2) DEFAULT 0,
    total_amount numeric(12,2) DEFAULT 0 NOT NULL,
    status character varying(20) DEFAULT 'pending'::character varying,
    expected_delivery_date date,
    notes text,
    created_by uuid NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    approved_by uuid,
    approved_at timestamp with time zone,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: purchase_request_items; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.purchase_request_items (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    request_id uuid NOT NULL,
    item_id uuid NOT NULL,
    supplier_id uuid,
    requested_quantity numeric(12,3) NOT NULL,
    approved_quantity numeric(12,3),
    ordered_quantity numeric(12,3),
    received_quantity numeric(12,3) DEFAULT 0,
    estimated_unit_price numeric(12,2),
    estimated_total numeric(12,2),
    notes text,
    item_status character varying(20) DEFAULT 'pending'::character varying,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_request_qty CHECK ((requested_quantity > (0)::numeric))
);


--
-- Name: purchase_requests; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.purchase_requests (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    request_number character varying(30) NOT NULL,
    request_date date DEFAULT CURRENT_DATE NOT NULL,
    branch_id uuid NOT NULL,
    status public.purchase_request_status DEFAULT 'draft'::public.purchase_request_status,
    priority integer DEFAULT 0,
    notes text,
    total_items integer DEFAULT 0,
    total_quantity numeric(12,3) DEFAULT 0,
    estimated_cost numeric(12,2) DEFAULT 0,
    requested_by uuid NOT NULL,
    requested_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    approved_by uuid,
    approved_at timestamp with time zone,
    rejected_by uuid,
    rejected_at timestamp with time zone,
    rejection_reason text,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: roles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.roles (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    name character varying(50) NOT NULL,
    name_ar character varying(50) NOT NULL,
    description text,
    permissions jsonb DEFAULT '{}'::jsonb,
    is_system_role boolean DEFAULT false,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: supplier_items; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.supplier_items (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    supplier_id uuid NOT NULL,
    item_id uuid NOT NULL,
    supplier_item_code character varying(50),
    unit_price numeric(12,2),
    min_order_quantity numeric(12,3),
    lead_time_days integer,
    is_preferred boolean DEFAULT false,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: supplier_payments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.supplier_payments (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    payment_number character varying(30) NOT NULL,
    supplier_id uuid NOT NULL,
    supply_id uuid,
    amount numeric(12,2) NOT NULL,
    payment_method character varying(50) NOT NULL,
    reference_number character varying(50),
    bank_name character varying(100),
    payment_date date DEFAULT CURRENT_DATE NOT NULL,
    notes text,
    created_by uuid NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_payment_amount CHECK ((amount > (0)::numeric))
);


--
-- Name: supplier_returns; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.supplier_returns (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    return_number character varying(30) NOT NULL,
    supply_id uuid NOT NULL,
    supplier_id uuid NOT NULL,
    item_id uuid NOT NULL,
    quantity numeric(12,3) NOT NULL,
    unit_price numeric(12,2) NOT NULL,
    total_amount numeric(12,2) NOT NULL,
    reason text NOT NULL,
    description text,
    image_url text,
    status public.return_status DEFAULT 'pending'::public.return_status,
    registered_by uuid NOT NULL,
    registered_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    approved_by uuid,
    approved_at timestamp with time zone,
    rejected_by uuid,
    rejected_at timestamp with time zone,
    rejection_reason text,
    received_by_supplier_at timestamp with time zone,
    credit_note_number character varying(50),
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_return_quantity CHECK ((quantity > (0)::numeric))
);


--
-- Name: suppliers; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.suppliers (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    code character varying(20) NOT NULL,
    name character varying(150) NOT NULL,
    name_ar character varying(150),
    contact_person character varying(100),
    phone character varying(20) NOT NULL,
    phone_alt character varying(20),
    email character varying(100),
    address text,
    city character varying(50),
    tax_number character varying(50),
    commercial_register character varying(50),
    payment_terms public.supplier_payment_method DEFAULT 'cash'::public.supplier_payment_method,
    credit_limit numeric(12,2) DEFAULT 0,
    credit_period_days integer DEFAULT 0,
    current_balance numeric(12,2) DEFAULT 0,
    status public.supplier_status DEFAULT 'active'::public.supplier_status,
    notes text,
    rating integer,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    created_by uuid,
    CONSTRAINT chk_supplier_balance CHECK ((current_balance >= (0)::numeric)),
    CONSTRAINT suppliers_rating_check CHECK (((rating >= 1) AND (rating <= 5)))
);


--
-- Name: supplies; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.supplies (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    supply_number character varying(30) NOT NULL,
    supplier_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    invoice_number character varying(50),
    invoice_date date,
    subtotal numeric(12,2) DEFAULT 0 NOT NULL,
    tax_amount numeric(12,2) DEFAULT 0,
    discount_amount numeric(12,2) DEFAULT 0,
    total_amount numeric(12,2) DEFAULT 0 NOT NULL,
    payment_method public.supplier_payment_method NOT NULL,
    payment_status public.payment_status DEFAULT 'pending'::public.payment_status,
    paid_amount numeric(12,2) DEFAULT 0,
    due_date date,
    notes text,
    received_by uuid NOT NULL,
    received_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    approved_by uuid,
    approved_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_supply_amounts CHECK (((total_amount >= (0)::numeric) AND (paid_amount >= (0)::numeric)))
);


--
-- Name: supply_items; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.supply_items (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    supply_id uuid NOT NULL,
    item_id uuid NOT NULL,
    quantity numeric(12,3) NOT NULL,
    received_quantity numeric(12,3) NOT NULL,
    unit_price numeric(12,2) NOT NULL,
    discount_percent numeric(5,2) DEFAULT 0,
    tax_percent numeric(5,2) DEFAULT 0,
    total_price numeric(12,2) NOT NULL,
    batch_number character varying(50),
    production_date date,
    expiry_date date,
    notes text,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_supply_item_qty CHECK ((quantity > (0)::numeric))
);


--
-- Name: system_settings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.system_settings (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    key character varying(100) NOT NULL,
    value text,
    value_type character varying(20) DEFAULT 'string'::character varying,
    description text,
    is_public boolean DEFAULT false,
    updated_by uuid,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: transfer_items; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.transfer_items (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    transfer_id uuid NOT NULL,
    item_id uuid NOT NULL,
    requested_quantity numeric(12,3) NOT NULL,
    approved_quantity numeric(12,3),
    shipped_quantity numeric(12,3),
    received_quantity numeric(12,3),
    notes text,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_transfer_item_qty CHECK ((requested_quantity > (0)::numeric))
);


--
-- Name: transfers; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.transfers (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    transfer_number character varying(30) NOT NULL,
    from_branch_id uuid NOT NULL,
    to_branch_id uuid NOT NULL,
    status public.transfer_status DEFAULT 'pending'::public.transfer_status,
    priority integer DEFAULT 0,
    notes text,
    requested_by uuid NOT NULL,
    requested_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    approved_by uuid,
    approved_at timestamp with time zone,
    rejected_by uuid,
    rejected_at timestamp with time zone,
    rejection_reason text,
    shipped_at timestamp with time zone,
    received_by uuid,
    received_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_transfer_branches CHECK ((from_branch_id <> to_branch_id))
);


--
-- Name: units; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.units (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    code character varying(10) NOT NULL,
    name character varying(50) NOT NULL,
    name_ar character varying(50) NOT NULL,
    is_active boolean DEFAULT true,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: user_sessions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_sessions (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    user_id uuid NOT NULL,
    token_hash character varying(255) NOT NULL,
    device_info text,
    ip_address inet,
    is_active boolean DEFAULT true,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    expires_at timestamp with time zone NOT NULL,
    last_activity_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.users (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    employee_code character varying(20) NOT NULL,
    username character varying(50) NOT NULL,
    email character varying(100) NOT NULL,
    password_hash character varying(255) NOT NULL,
    full_name character varying(100) NOT NULL,
    full_name_ar character varying(100),
    phone character varying(20),
    role_id uuid NOT NULL,
    branch_id uuid,
    status public.user_status DEFAULT 'active'::public.user_status,
    last_login timestamp with time zone,
    password_changed_at timestamp with time zone,
    failed_login_attempts integer DEFAULT 0,
    locked_until timestamp with time zone,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    created_by uuid
);


--
-- Name: vw_branch_inventory; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.vw_branch_inventory AS
 SELECT row_number() OVER (PARTITION BY b.id ORDER BY c.name, i.code) AS row_num,
    b.code AS branch_code,
    b.name AS branch_name,
    c.name AS category,
    i.code AS item_code,
    i.name AS item_name,
    u.name AS unit_name,
    inv.opening_balance,
    inv.incoming_quantity AS incoming,
    inv.consumption_quantity AS consumption,
    inv.quantity AS total_balance,
    inv.consumption_description,
    inv.min_quantity,
        CASE
            WHEN (inv.quantity < inv.min_quantity) THEN 'LOW'::text
            WHEN (inv.quantity < (inv.min_quantity * 1.5)) THEN 'WARNING'::text
            ELSE 'OK'::text
        END AS stock_status
   FROM ((((public.inventory inv
     JOIN public.branches b ON ((inv.branch_id = b.id)))
     JOIN public.items i ON ((inv.item_id = i.id)))
     JOIN public.categories c ON ((i.category_id = c.id)))
     JOIN public.units u ON ((i.unit_id = u.id)))
  WHERE (b.is_main_warehouse = false)
  ORDER BY b.name, c.name, i.code;


--
-- Name: vw_branch_inventory_details; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.vw_branch_inventory_details AS
 SELECT row_number() OVER (ORDER BY inv.entry_date DESC, i.code) AS row_num,
    inv.entry_date,
    inv.document_number,
    i.code AS item_code,
    i.name AS item_name,
    inv.partial_quantity,
    inv.content_quantity,
    inv.total_quantity,
    inv.content_description,
    b.code AS branch_code,
    b.name AS branch_name,
    inv.quantity AS current_stock,
    inv.min_quantity,
    u.name AS unit_name,
    inv.updated_at
   FROM (((public.inventory inv
     JOIN public.items i ON ((inv.item_id = i.id)))
     JOIN public.branches b ON ((inv.branch_id = b.id)))
     LEFT JOIN public.units u ON ((i.unit_id = u.id)))
  WHERE ((b.code)::text <> 'MAIN'::text)
  ORDER BY inv.entry_date DESC, i.code;


--
-- Name: vw_branch_returns; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.vw_branch_returns AS
 SELECT row_number() OVER (ORDER BY br.return_date DESC, br.return_number) AS row_num,
    br.return_number,
    br.return_date,
    fb.name AS from_branch,
    tb.name AS to_branch,
    i.code AS item_code,
    i.name AS item_name,
    bri.requested_quantity,
    bri.approved_quantity,
    bri.received_quantity,
    bri.unit_cost,
    bri.total_value,
    br.return_reason,
    bri.item_reason,
    br.status,
    u.full_name AS requested_by_name,
    br.requested_at
   FROM (((((public.branch_returns br
     JOIN public.branch_return_items bri ON ((br.id = bri.return_id)))
     JOIN public.branches fb ON ((br.from_branch_id = fb.id)))
     JOIN public.branches tb ON ((br.to_branch_id = tb.id)))
     JOIN public.items i ON ((bri.item_id = i.id)))
     JOIN public.users u ON ((br.requested_by = u.id)))
  ORDER BY br.return_date DESC, br.return_number, i.code;


--
-- Name: vw_main_warehouse_inventory; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.vw_main_warehouse_inventory AS
 SELECT row_number() OVER (ORDER BY c.name, i.code) AS row_num,
    c.name AS category,
    c.name_ar AS category_ar,
    i.code AS item_code,
    i.name AS item_name,
    i.name_ar AS item_name_ar,
    u.name AS unit_name,
    u.name_ar AS unit_name_ar,
    inv.opening_balance,
    inv.incoming_quantity AS incoming,
    inv.consumption_quantity AS consumption,
    inv.quantity AS total_balance,
    inv.consumption_description,
    inv.min_quantity,
        CASE
            WHEN (inv.quantity < inv.min_quantity) THEN 'LOW'::text
            WHEN (inv.quantity < (inv.min_quantity * 1.5)) THEN 'WARNING'::text
            ELSE 'OK'::text
        END AS stock_status,
    inv.period_start_date,
    inv.period_end_date,
    inv.updated_at
   FROM ((((public.inventory inv
     JOIN public.branches b ON ((inv.branch_id = b.id)))
     JOIN public.items i ON ((inv.item_id = i.id)))
     JOIN public.categories c ON ((i.category_id = c.id)))
     JOIN public.units u ON ((i.unit_id = u.id)))
  WHERE (b.is_main_warehouse = true)
  ORDER BY c.name, i.code;


--
-- Name: vw_purchase_requests; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.vw_purchase_requests AS
 SELECT row_number() OVER (ORDER BY pr.request_date DESC, pr.request_number) AS row_num,
    pr.request_date AS date,
    pr.request_number AS document_number,
    pri.id AS item_row_id,
    i.code AS item_code,
    i.name AS item_name,
    i.name_ar AS item_name_ar,
    COALESCE(s.name, 'Not Assigned'::character varying) AS supplier_name,
    COALESCE(s.name_ar, 'Not Assigned'::character varying) AS supplier_name_ar,
    pri.requested_quantity AS quantity,
    pri.notes,
    pr.status AS request_status,
    b.name AS branch_name,
    u.full_name AS requested_by_name
   FROM (((((public.purchase_requests pr
     JOIN public.purchase_request_items pri ON ((pr.id = pri.request_id)))
     JOIN public.items i ON ((pri.item_id = i.id)))
     LEFT JOIN public.suppliers s ON ((pri.supplier_id = s.id)))
     JOIN public.branches b ON ((pr.branch_id = b.id)))
     JOIN public.users u ON ((pr.requested_by = u.id)))
  ORDER BY pr.request_date DESC, pr.request_number, i.code;


--
-- Data for Name: alert_settings; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.alert_settings VALUES ('e3a5e471-38c5-4190-8735-3e03aef94d6b', '0375f387-cb50-46ff-b41d-d60fe932addf', 'low_stock', true, NULL, 7, '{warehouse_manager,admin}', '2025-12-11 17:24:12.369808+02', '2025-12-11 17:24:12.369808+02');
INSERT INTO public.alert_settings VALUES ('87543efa-c09d-4391-85cd-8dc6310d471c', '0375f387-cb50-46ff-b41d-d60fe932addf', 'expiry_warning', true, NULL, 30, '{warehouse_manager,admin}', '2025-12-11 17:24:12.373833+02', '2025-12-11 17:24:12.373833+02');
INSERT INTO public.alert_settings VALUES ('f7539dd2-7f22-4781-bf02-4123b38e6c7f', '393fdf52-1982-481b-a254-11ba0edc1d8b', 'low_stock', true, NULL, 3, '{branch_supervisor}', '2025-12-11 17:24:12.375523+02', '2025-12-11 17:24:12.375523+02');


--
-- Data for Name: audit_logs; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.audit_logs VALUES ('ff407331-6b30-42f0-a11b-8540a86035ad', '0bd55267-11ed-4a77-aa37-8a990e94dd31', 'CREATE', 'supplies', '381c4da0-06e3-4058-9974-1f337b74cd60', NULL, '{"total_amount": 5700, "supply_number": "SUP-2024-001"}', '192.168.1.100', NULL, '2025-12-11 17:24:12.377273+02');
INSERT INTO public.audit_logs VALUES ('5a6b19da-b116-4e85-b563-e44e6c7d32d9', '0bd55267-11ed-4a77-aa37-8a990e94dd31', 'UPDATE', 'transfers', 'eee5bdc4-5c73-4772-9d87-57c8bc28041e', '{"status": "pending"}', '{"status": "approved"}', '192.168.1.100', NULL, '2025-12-11 17:24:12.381639+02');
INSERT INTO public.audit_logs VALUES ('65b9789e-7680-413c-b6bd-18ad745b11cd', 'a0ada47f-f5ff-43b3-8c3e-68492f870fc1', 'LOGIN', 'users', NULL, NULL, NULL, '192.168.1.100', 'Mozilla/5.0 Chrome/120.0', '2025-12-11 17:36:51.307645+02');
INSERT INTO public.audit_logs VALUES ('cc1ef8a3-4b21-4bc1-b91c-4f8d4bf067a0', '53c3ad83-b852-4386-9a69-afdb98a4d9c9', 'LOGIN', 'users', NULL, NULL, NULL, '192.168.1.101', 'Mozilla/5.0 Chrome/120.0', '2025-12-11 17:36:51.310755+02');
INSERT INTO public.audit_logs VALUES ('cda78cb9-89fe-4193-af48-63a8ec3c18d2', '0bd55267-11ed-4a77-aa37-8a990e94dd31', 'CREATE', 'supplies', '09625919-731b-4c97-9039-0ef4354bfbd9', NULL, '{"supplier": "SUP001", "total_amount": 9120, "supply_number": "SUP-2024-003"}', '192.168.1.100', NULL, '2025-12-11 17:36:51.312644+02');
INSERT INTO public.audit_logs VALUES ('3a77d130-5f5c-44f3-9d20-c6b9d1ed33ef', 'a0ada47f-f5ff-43b3-8c3e-68492f870fc1', 'UPDATE', 'damages', '8cd8b543-1173-482e-b30b-9db9f1a38963', '{"status": "pending"}', '{"status": "approved", "approved_by": "admin"}', '192.168.1.100', NULL, '2025-12-11 17:36:51.31437+02');
INSERT INTO public.audit_logs VALUES ('b800a786-4588-40c0-bd09-e44c3b3d4509', 'a0ada47f-f5ff-43b3-8c3e-68492f870fc1', 'CREATE', 'supplier_payments', '342a04a9-e1a1-4011-859a-da2dbcccad69', NULL, '{"amount": 5000, "method": "bank_transfer", "payment_number": "PAY-2024-002"}', '192.168.1.100', NULL, '2025-12-11 17:36:51.316544+02');
INSERT INTO public.audit_logs VALUES ('d14222b0-bd8b-4321-97d8-7d64e58a6d83', '53c3ad83-b852-4386-9a69-afdb98a4d9c9', 'UPDATE', 'orders', '8bc80a38-e8b5-4286-8db9-07ce55c3b976', '{"status": "new"}', '{"status": "delivered"}', '192.168.1.101', NULL, '2025-12-11 17:36:51.320048+02');
INSERT INTO public.audit_logs VALUES ('df396dcc-d967-46b9-8fac-944bdbf91a03', '0bd55267-11ed-4a77-aa37-8a990e94dd31', 'UPDATE', 'inventory', NULL, '{"item": "ITM004", "quantity": 40}', '{"item": "ITM004", "reason": "Found extra stock", "quantity": 45}', '192.168.1.100', NULL, '2025-12-11 17:36:51.321941+02');
INSERT INTO public.audit_logs VALUES ('66ac963b-00b5-450d-a801-22d12418abef', 'eff3e90d-dbf6-4536-baa5-1ff53e82c659', 'CREATE', 'branch_returns', NULL, NULL, '{"reason": "Excess stock", "to_branch": "MAIN", "from_branch": "BR001", "return_number": "BRT-2024-12-0001"}', '192.168.1.101', NULL, '2025-12-11 18:34:18.496279+02');
INSERT INTO public.audit_logs VALUES ('5746f1c4-4b76-418f-93ca-afd5782f55a2', '0bd55267-11ed-4a77-aa37-8a990e94dd31', 'UPDATE', 'branch_returns', NULL, '{"status": "pending"}', '{"status": "approved", "approved_by": "warehouse_mgr"}', '192.168.1.100', NULL, '2025-12-11 18:34:18.508478+02');
INSERT INTO public.audit_logs VALUES ('14a4fc93-d256-4fbd-babb-792fc855f2d4', '0bd55267-11ed-4a77-aa37-8a990e94dd31', 'UPDATE', 'branch_returns', NULL, '{"status": "in_transit"}', '{"status": "received", "received_by": "warehouse_mgr"}', '192.168.1.100', NULL, '2025-12-11 18:34:18.510467+02');
INSERT INTO public.audit_logs VALUES ('0f8b7b1c-5285-4207-8d7d-0f7cc42dfb3f', '0bd55267-11ed-4a77-aa37-8a990e94dd31', 'UPDATE', 'branch_returns', NULL, '{"status": "pending"}', '{"status": "rejected", "rejection_reason": "Oil is a stable item"}', '192.168.1.100', NULL, '2025-12-11 18:34:18.513162+02');
INSERT INTO public.audit_logs VALUES ('94d6d441-3780-4277-abf7-2e7d94424451', '0bd55267-11ed-4a77-aa37-8a990e94dd31', 'CREATE', 'supplies', NULL, NULL, '{"total": 3990, "supplier": "SUP005", "supply_number": "SUP-2024-005"}', '192.168.1.100', NULL, '2025-12-11 18:58:00.743672+02');
INSERT INTO public.audit_logs VALUES ('6ed0c0e4-7f6e-43c8-9248-5784cc7ca288', '0bd55267-11ed-4a77-aa37-8a990e94dd31', 'UPDATE', 'transfers', NULL, '{"status": "pending"}', '{"status": "received", "transfer_number": "TRF-2024-003"}', '192.168.1.100', NULL, '2025-12-11 18:58:00.746045+02');
INSERT INTO public.audit_logs VALUES ('24611592-ea32-41e0-a17d-41e2801593cf', '6c4746c9-75c7-4d40-bd3f-309dc6b5968a', 'CREATE', 'damages', NULL, NULL, '{"reason": "STORAGE", "quantity": 8, "damage_number": "DMG-2024-006"}', '192.168.1.102', NULL, '2025-12-11 18:58:00.748128+02');
INSERT INTO public.audit_logs VALUES ('a2accae1-ea76-4947-9fa5-81e4f22085be', '0bd55267-11ed-4a77-aa37-8a990e94dd31', 'UPDATE', 'branch_returns', NULL, '{"status": "pending"}', '{"status": "received", "return_number": "BRT-2024-12-0006"}', '192.168.1.100', NULL, '2025-12-11 18:58:00.750055+02');
INSERT INTO public.audit_logs VALUES ('c426b60a-5858-48f3-8dc8-36034eee1e86', '0bd55267-11ed-4a77-aa37-8a990e94dd31', 'CREATE', 'supplier_returns', NULL, NULL, '{"quantity": 20, "supplier": "SUP005", "return_number": "RET-2024-004"}', '192.168.1.100', NULL, '2025-12-11 18:58:00.75187+02');
INSERT INTO public.audit_logs VALUES ('c8437524-7cb5-4559-a1e2-d6ca43c34d89', 'f34679bc-52fa-4b0f-9e95-0b7306af2468', 'UPDATE', 'orders', NULL, '{"status": "new"}', '{"status": "delivered", "order_number": "ORD-2024-007"}', '192.168.1.102', NULL, '2025-12-11 18:58:00.753344+02');
INSERT INTO public.audit_logs VALUES ('0c74058b-243c-4f65-bf7a-4e5338141da2', 'a0ada47f-f5ff-43b3-8c3e-68492f870fc1', 'CREATE', 'supplier_payments', NULL, NULL, '{"amount": 2000, "supplier": "SUP005", "payment_number": "PAY-2024-005"}', '192.168.1.100', NULL, '2025-12-11 18:58:00.754839+02');


--
-- Data for Name: auth_group; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: auth_group_permissions; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: auth_permission; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: branch_return_items; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.branch_return_items VALUES ('a41ee9bd-77b6-4b07-9196-4b95b56e635b', '4baa52e5-41e0-448a-b589-92291ce371a7', '9194f596-622a-46e7-bcd8-537b322083d2', 5.000, NULL, NULL, NULL, 78.00, 390.00, 'Excess stock', NULL, 'Slow sales this week', '2025-12-11 18:34:18.42571+02');
INSERT INTO public.branch_return_items VALUES ('0bebab4c-6376-4ba1-a4cd-3df7b3a000ae', '4baa52e5-41e0-448a-b589-92291ce371a7', 'c4394116-cc14-4a0b-ba16-13189361429e', 3.000, NULL, NULL, NULL, 245.00, 735.00, 'Near expiry', NULL, 'Expiring in 3 days', '2025-12-11 18:34:18.433446+02');
INSERT INTO public.branch_return_items VALUES ('5c9335eb-a7f1-4a95-891f-bf5f7b400536', '0b3c0978-d25b-461d-880b-0e04bb639f22', 'dd165c16-b9b3-476c-8309-47a08dfacca9', 10.000, 10.000, 10.000, NULL, 15.00, 150.00, 'Quality issue - overripe', NULL, NULL, '2025-12-11 18:34:18.438421+02');
INSERT INTO public.branch_return_items VALUES ('d4da4258-8a7e-4de8-b3ad-16669915b167', 'c2e337e6-22e2-416c-9faa-23e1e5c02b05', '9194f596-622a-46e7-bcd8-537b322083d2', 15.000, 15.000, 15.000, 15.000, 78.00, 1170.00, 'Excess stock', NULL, NULL, '2025-12-11 18:34:18.443083+02');
INSERT INTO public.branch_return_items VALUES ('6f773fd3-4ea2-466b-b6c5-d2340ddaceec', 'c2e337e6-22e2-416c-9faa-23e1e5c02b05', '99484384-95cd-475e-8c06-971ec03f75f7', 20.000, 20.000, 20.000, 18.000, 8.00, 144.00, 'Slow moving - 2 damaged in transit', NULL, NULL, '2025-12-11 18:34:18.445451+02');
INSERT INTO public.branch_return_items VALUES ('1627e328-6cd3-4f8d-971c-56b70ec86dfa', 'b15da1ea-b30c-4ffc-9722-0dd3d55d635e', 'bfbff945-e1b4-4cfe-8fac-274fe629b3dd', 10.000, NULL, NULL, NULL, 45.00, 450.00, 'Excess stock', NULL, NULL, '2025-12-11 18:34:18.481852+02');
INSERT INTO public.branch_return_items VALUES ('272ba4a6-ab32-4337-be5e-d2651c9d5381', 'b479fa38-aaee-41be-8079-a5e04bbd53ea', '431d3ad0-1b54-483a-8572-332da247a065', 5.000, NULL, NULL, NULL, 120.00, 600.00, 'Slow moving', NULL, NULL, '2025-12-11 18:34:18.486556+02');
INSERT INTO public.branch_return_items VALUES ('eb1b7318-3b16-4ae2-af7a-49a990047034', '5a3f81ab-e992-4f3a-bbb4-88a6adee5b6e', 'c4394116-cc14-4a0b-ba16-13189361429e', 5.000, 5.000, 5.000, 5.000, 245.00, 1225.00, 'Near expiry - 3 days left', NULL, NULL, '2025-12-11 18:58:00.672779+02');


--
-- Data for Name: branch_return_reasons; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.branch_return_reasons VALUES ('75fe2493-9157-45fb-ad90-3185508e7e15', 'EXCESS', 'Excess Stock', 'Excess Stock', NULL, true, 1, '2025-12-11 18:30:26.878165+02');
INSERT INTO public.branch_return_reasons VALUES ('69351301-5c4b-474e-9a6d-daaef333eb51', 'SLOW_MOVING', 'Slow Moving Items', 'Slow Moving', NULL, true, 2, '2025-12-11 18:30:26.878165+02');
INSERT INTO public.branch_return_reasons VALUES ('aeac64f4-316d-4dd2-ae95-8400bc347020', 'NEAR_EXPIRY', 'Near Expiry', 'Near Expiry', NULL, true, 3, '2025-12-11 18:30:26.878165+02');
INSERT INTO public.branch_return_reasons VALUES ('75b7fe5c-0be5-492d-8249-12a1c36b2b16', 'QUALITY_ISSUE', 'Quality Issue', 'Quality Issue', NULL, true, 4, '2025-12-11 18:30:26.878165+02');
INSERT INTO public.branch_return_reasons VALUES ('e0e7aa77-07a9-40d1-a921-a5c765f54aca', 'WRONG_DELIVERY', 'Wrong Delivery', 'Wrong Delivery', NULL, true, 5, '2025-12-11 18:30:26.878165+02');
INSERT INTO public.branch_return_reasons VALUES ('a2ef993b-e146-46c9-8b57-ae3ae5ab0b65', 'BRANCH_CLOSING', 'Branch Closing', 'Branch Closing', NULL, true, 6, '2025-12-11 18:30:26.878165+02');
INSERT INTO public.branch_return_reasons VALUES ('df90e9df-ea08-4839-bbb5-83bc5e7d958a', 'REBALANCING', 'Stock Rebalancing', 'Rebalancing', NULL, true, 7, '2025-12-11 18:30:26.878165+02');
INSERT INTO public.branch_return_reasons VALUES ('de4ca0f9-a3b2-4be5-ab18-8bb8b2c77bea', 'OTHER', 'Other', 'Other', NULL, true, 99, '2025-12-11 18:30:26.878165+02');


--
-- Data for Name: branch_returns; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.branch_returns VALUES ('4baa52e5-41e0-448a-b589-92291ce371a7', 'BRT-2024-12-0001', '2025-12-11', '393fdf52-1982-481b-a254-11ba0edc1d8b', '0375f387-cb50-46ff-b41d-d60fe932addf', 'pending', 'Excess stock after slow weekend sales', 2, 8.000, 1125.00, 'Branch has excess chicken and beef that will expire soon', 'eff3e90d-dbf6-4536-baa5-1ff53e82c659', '2025-12-11 18:34:18.413364+02', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2025-12-11 18:34:18.413364+02', '2025-12-11 18:34:18.433446+02');
INSERT INTO public.branch_returns VALUES ('0b3c0978-d25b-461d-880b-0e04bb639f22', 'BRT-2024-12-0002', '2025-12-10', '393fdf52-1982-481b-a254-11ba0edc1d8b', '0375f387-cb50-46ff-b41d-d60fe932addf', 'in_transit', 'Quality issue with tomatoes - some are overripe', 1, 10.000, 150.00, 'Tomatoes received were already soft, need to return before spoilage', 'eff3e90d-dbf6-4536-baa5-1ff53e82c659', '2025-12-10 18:34:18.435902+02', '0bd55267-11ed-4a77-aa37-8a990e94dd31', '2025-12-11 06:34:18.435902+02', NULL, NULL, NULL, '2025-12-11 12:34:18.435902+02', NULL, NULL, '2025-12-11 18:34:18.435902+02', '2025-12-11 18:34:18.438421+02');
INSERT INTO public.branch_returns VALUES ('c2e337e6-22e2-416c-9faa-23e1e5c02b05', 'BRT-2024-12-0003', '2025-12-08', '7a5e81b1-5777-425c-968a-ccac5f43fcae', '0375f387-cb50-46ff-b41d-d60fe932addf', 'received', 'Stock rebalancing - Branch 2 overstocked', 2, 35.000, 1314.00, 'Returning excess items to main warehouse for redistribution', '6c4746c9-75c7-4d40-bd3f-309dc6b5968a', '2025-12-08 18:34:18.440703+02', '0bd55267-11ed-4a77-aa37-8a990e94dd31', '2025-12-09 00:34:18.440703+02', NULL, NULL, NULL, '2025-12-09 06:34:18.440703+02', '0bd55267-11ed-4a77-aa37-8a990e94dd31', '2025-12-09 18:34:18.440703+02', '2025-12-11 18:34:18.440703+02', '2025-12-11 18:34:18.445451+02');
INSERT INTO public.branch_returns VALUES ('b15da1ea-b30c-4ffc-9722-0dd3d55d635e', 'BRT-2024-12-0004', '2025-12-09', '393fdf52-1982-481b-a254-11ba0edc1d8b', '0375f387-cb50-46ff-b41d-d60fe932addf', 'rejected', 'Want to return cooking oil', 1, 10.000, 450.00, 'We have too much oil', 'eff3e90d-dbf6-4536-baa5-1ff53e82c659', '2025-12-09 18:34:18.479466+02', NULL, NULL, '0bd55267-11ed-4a77-aa37-8a990e94dd31', '2025-12-09 22:34:18.479466+02', 'Oil is a stable item with long shelf life. Please use it for cooking. Return not justified.', NULL, NULL, NULL, '2025-12-11 18:34:18.479466+02', '2025-12-11 18:34:18.481852+02');
INSERT INTO public.branch_returns VALUES ('b479fa38-aaee-41be-8079-a5e04bbd53ea', 'BRT-2024-12-0005', '2025-12-07', '7a5e81b1-5777-425c-968a-ccac5f43fcae', '0375f387-cb50-46ff-b41d-d60fe932addf', 'cancelled', 'Slow moving cheese', 1, 5.000, 600.00, 'Cancelled - found use for cheese in new menu item', '6c4746c9-75c7-4d40-bd3f-309dc6b5968a', '2025-12-07 18:34:18.484321+02', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2025-12-11 18:34:18.484321+02', '2025-12-11 18:34:18.486556+02');
INSERT INTO public.branch_returns VALUES ('5a3f81ab-e992-4f3a-bbb4-88a6adee5b6e', 'BRT-2024-12-0006', '2025-12-11', '393fdf52-1982-481b-a254-11ba0edc1d8b', '0375f387-cb50-46ff-b41d-d60fe932addf', 'received', 'Near expiry items need to be returned', 1, 5.000, 1225.00, 'Items expiring within 5 days', 'eff3e90d-dbf6-4536-baa5-1ff53e82c659', '2025-12-11 18:58:00.670368+02', '0bd55267-11ed-4a77-aa37-8a990e94dd31', '2025-12-11 18:58:00.6777+02', NULL, NULL, NULL, '2025-12-11 18:58:00.679647+02', '0bd55267-11ed-4a77-aa37-8a990e94dd31', '2025-12-11 18:58:00.681467+02', '2025-12-11 18:58:00.670368+02', '2025-12-11 18:58:00.682537+02');


--
-- Data for Name: branch_settings; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.branch_settings VALUES ('491f023b-00b9-46fa-bdc9-259478abcaaf', '393fdf52-1982-481b-a254-11ba0edc1d8b', 'receipt_header', 'Welcome to Our Restaurant', 'a0ada47f-f5ff-43b3-8c3e-68492f870fc1', '2025-12-11 17:24:12.389291+02');
INSERT INTO public.branch_settings VALUES ('19c891dc-f277-4dd8-a12f-8f6235e891fb', '393fdf52-1982-481b-a254-11ba0edc1d8b', 'receipt_footer', 'Thank you for visiting!', 'a0ada47f-f5ff-43b3-8c3e-68492f870fc1', '2025-12-11 17:24:12.393801+02');
INSERT INTO public.branch_settings VALUES ('8ad846eb-abcc-46ea-bb17-6716fb45a4d2', '393fdf52-1982-481b-a254-11ba0edc1d8b', 'auto_print_kitchen', 'true', 'a0ada47f-f5ff-43b3-8c3e-68492f870fc1', '2025-12-11 17:24:12.395879+02');
INSERT INTO public.branch_settings VALUES ('2c4bfbdc-6795-4fde-ba6a-4263d12958bc', '7a5e81b1-5777-425c-968a-ccac5f43fcae', 'receipt_header', 'Welcome to Branch 2', 'a0ada47f-f5ff-43b3-8c3e-68492f870fc1', '2025-12-11 17:36:51.355294+02');
INSERT INTO public.branch_settings VALUES ('cba3bb47-6f73-471a-880d-5b7b9938b25e', '7a5e81b1-5777-425c-968a-ccac5f43fcae', 'receipt_footer', 'Thank you! Visit again!', 'a0ada47f-f5ff-43b3-8c3e-68492f870fc1', '2025-12-11 17:36:51.358017+02');
INSERT INTO public.branch_settings VALUES ('f4e199bf-59d3-4502-ab39-1b8645eceaca', '7a5e81b1-5777-425c-968a-ccac5f43fcae', 'kitchen_printer', 'PRINTER-BR2-001', 'a0ada47f-f5ff-43b3-8c3e-68492f870fc1', '2025-12-11 17:36:51.360111+02');


--
-- Data for Name: branches; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.branches VALUES ('0375f387-cb50-46ff-b41d-d60fe932addf', 'MAIN', 'Main Warehouse', 'Main Warehouse', NULL, NULL, NULL, 'active', true, NULL, NULL, '2025-12-11 17:16:37.119418+02', '2025-12-11 17:16:37.119418+02');
INSERT INTO public.branches VALUES ('393fdf52-1982-481b-a254-11ba0edc1d8b', 'BR001', 'Branch 1', 'Branch 1', NULL, NULL, NULL, 'active', false, NULL, NULL, '2025-12-11 17:16:37.119418+02', '2025-12-11 17:16:37.119418+02');
INSERT INTO public.branches VALUES ('7a5e81b1-5777-425c-968a-ccac5f43fcae', 'BR002', 'Branch 2', 'Branch 2', NULL, NULL, NULL, 'active', false, NULL, NULL, '2025-12-11 17:16:37.119418+02', '2025-12-11 17:16:37.119418+02');


--
-- Data for Name: categories; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.categories VALUES ('bae9363b-443a-4cd4-8230-7861b4ce0ea7', 'CAT001', 'Meat', 'Meat', 'All types of meat', NULL, 1, true, '2025-12-11 17:25:42.94529+02', '2025-12-11 17:25:42.94529+02');
INSERT INTO public.categories VALUES ('5dc69575-7f72-4214-ae63-f984eb3b39c0', 'CAT002', 'Vegetables', 'Vegetables', 'Fresh vegetables', NULL, 2, true, '2025-12-11 17:25:42.94529+02', '2025-12-11 17:25:42.94529+02');
INSERT INTO public.categories VALUES ('515b0ee3-e3ca-4989-a3f1-b908b205432e', 'CAT003', 'Dairy', 'Dairy', 'Dairy products', NULL, 3, true, '2025-12-11 17:25:42.94529+02', '2025-12-11 17:25:42.94529+02');
INSERT INTO public.categories VALUES ('f4a4e59d-408c-4aeb-8a66-434899e9ade1', 'CAT004', 'Beverages', 'Beverages', 'Drinks', NULL, 4, true, '2025-12-11 17:25:42.94529+02', '2025-12-11 17:25:42.94529+02');
INSERT INTO public.categories VALUES ('3af268a6-ba8b-4cef-9fa6-55f1f3fa2471', 'CAT005', 'Spices', 'Spices', 'Spices and seasonings', NULL, 5, true, '2025-12-11 17:25:42.94529+02', '2025-12-11 17:25:42.94529+02');
INSERT INTO public.categories VALUES ('de53cd45-4b5e-41c4-9f0c-b08ed4017a6c', 'CAT006', 'Oils', 'Oils', 'Cooking oils', NULL, 6, true, '2025-12-11 17:25:42.94529+02', '2025-12-11 17:25:42.94529+02');
INSERT INTO public.categories VALUES ('5a483cf6-413a-417c-b6d4-6a7aca239095', 'CAT007', 'Grains', 'Grains', 'Rice, pasta', NULL, 7, true, '2025-12-11 17:25:42.94529+02', '2025-12-11 17:25:42.94529+02');


--
-- Data for Name: daily_inventory_count_items; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.daily_inventory_count_items VALUES ('61031bf1-0682-4ee3-b383-be469992799f', '4b24e40f-a098-4578-9822-fb31076b1469', '9194f596-622a-46e7-bcd8-537b322083d2', 10.000, 10.000, NULL, '2025-12-11 17:25:43.091953+02');
INSERT INTO public.daily_inventory_count_items VALUES ('1eef0325-f18a-453a-b7bb-4660612bf8e3', '4b24e40f-a098-4578-9822-fb31076b1469', 'c4394116-cc14-4a0b-ba16-13189361429e', 5.000, 5.000, NULL, '2025-12-11 17:25:43.098816+02');
INSERT INTO public.daily_inventory_count_items VALUES ('70a95cd8-52d7-4988-9ba1-dae4d13d441f', '4b24e40f-a098-4578-9822-fb31076b1469', 'dd165c16-b9b3-476c-8309-47a08dfacca9', 20.000, 19.000, 'One tomato was damaged', '2025-12-11 17:25:43.101551+02');
INSERT INTO public.daily_inventory_count_items VALUES ('e9dd6f3d-b891-4568-b1c2-7e83b8f33e30', 'a01e9463-4d02-4b94-93f7-7e7f12caeb5f', '9194f596-622a-46e7-bcd8-537b322083d2', 9.000, 8.500, 'Possible theft or miscounting', '2025-12-11 17:36:51.269413+02');
INSERT INTO public.daily_inventory_count_items VALUES ('4a377fa9-a85d-4888-a883-60db19770351', 'a01e9463-4d02-4b94-93f7-7e7f12caeb5f', 'c4394116-cc14-4a0b-ba16-13189361429e', 5.000, 5.000, NULL, '2025-12-11 17:36:51.273214+02');
INSERT INTO public.daily_inventory_count_items VALUES ('371563ae-610b-4ab6-ba83-132470a68675', 'a01e9463-4d02-4b94-93f7-7e7f12caeb5f', 'dd165c16-b9b3-476c-8309-47a08dfacca9', 18.000, 17.000, 'Used for staff meal', '2025-12-11 17:36:51.275493+02');
INSERT INTO public.daily_inventory_count_items VALUES ('444206d2-418e-40ac-a190-bdcf2db8c632', 'a01e9463-4d02-4b94-93f7-7e7f12caeb5f', '99484384-95cd-475e-8c06-971ec03f75f7', 48.000, 45.000, 'Some bottles broken', '2025-12-11 17:36:51.277506+02');
INSERT INTO public.daily_inventory_count_items VALUES ('ca976d39-e670-4fed-a3af-dea74838f1cc', '2cd75a64-be8c-48aa-82a6-4d5fea90172e', '9194f596-622a-46e7-bcd8-537b322083d2', 70.000, 70.000, NULL, '2025-12-11 17:36:51.281784+02');
INSERT INTO public.daily_inventory_count_items VALUES ('f7b469ad-2950-4571-aa73-f4102d2321db', '2cd75a64-be8c-48aa-82a6-4d5fea90172e', 'c4394116-cc14-4a0b-ba16-13189361429e', 30.000, 30.000, NULL, '2025-12-11 17:36:51.284087+02');
INSERT INTO public.daily_inventory_count_items VALUES ('ab6f1e71-3bfc-4e51-ab21-936ce62fd8fc', '2cd75a64-be8c-48aa-82a6-4d5fea90172e', 'dd165c16-b9b3-476c-8309-47a08dfacca9', 45.000, 44.000, 'One bag damaged', '2025-12-11 17:36:51.286112+02');
INSERT INTO public.daily_inventory_count_items VALUES ('c6689474-1b38-4bf0-9e83-db5957bd117d', '3a38af22-64af-44d6-bebb-8422e0ed70b7', '9194f596-622a-46e7-bcd8-537b322083d2', 25.000, 25.000, NULL, '2025-12-11 17:36:51.351373+02');
INSERT INTO public.daily_inventory_count_items VALUES ('4ef03417-f6e2-4b7c-b780-e54086e6faff', '3a38af22-64af-44d6-bebb-8422e0ed70b7', 'c4394116-cc14-4a0b-ba16-13189361429e', 10.000, 10.000, NULL, '2025-12-11 17:36:51.35337+02');
INSERT INTO public.daily_inventory_count_items VALUES ('55aee5d0-1a77-4214-811e-2b8db6e6c49d', '6cd06980-4039-4b84-bf08-ba4bd861f11c', '9194f596-622a-46e7-bcd8-537b322083d2', 1.250, 1.000, 'Minor variance - possible measurement error', '2025-12-11 18:58:00.72913+02');
INSERT INTO public.daily_inventory_count_items VALUES ('e3fffdf6-a69f-452e-aef5-6b178125deb3', '6cd06980-4039-4b84-bf08-ba4bd861f11c', 'c4394116-cc14-4a0b-ba16-13189361429e', 10.000, 10.000, NULL, '2025-12-11 18:58:00.73321+02');


--
-- Data for Name: daily_inventory_counts; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.daily_inventory_counts VALUES ('4b24e40f-a098-4578-9822-fb31076b1469', '393fdf52-1982-481b-a254-11ba0edc1d8b', '2025-12-11', 'morning', 'submitted', 'Morning opening count', 'eff3e90d-dbf6-4536-baa5-1ff53e82c659', '2025-12-11 17:24:12.354653+02', NULL, NULL, '2025-12-11 17:24:12.354653+02', '2025-12-11 17:24:12.354653+02');
INSERT INTO public.daily_inventory_counts VALUES ('a01e9463-4d02-4b94-93f7-7e7f12caeb5f', '393fdf52-1982-481b-a254-11ba0edc1d8b', '2025-12-11', 'evening', 'submitted', 'End of day count', 'eff3e90d-dbf6-4536-baa5-1ff53e82c659', '2025-12-11 17:36:51.266749+02', NULL, NULL, '2025-12-11 17:36:51.266749+02', '2025-12-11 17:36:51.266749+02');
INSERT INTO public.daily_inventory_counts VALUES ('2cd75a64-be8c-48aa-82a6-4d5fea90172e', '0375f387-cb50-46ff-b41d-d60fe932addf', '2025-12-11', 'morning', 'approved', 'Opening count - all items verified', '0bd55267-11ed-4a77-aa37-8a990e94dd31', '2025-12-11 17:36:51.279036+02', 'a0ada47f-f5ff-43b3-8c3e-68492f870fc1', '2025-12-11 17:36:51.279036+02', '2025-12-11 17:36:51.279036+02', '2025-12-11 17:36:51.279036+02');
INSERT INTO public.daily_inventory_counts VALUES ('3a38af22-64af-44d6-bebb-8422e0ed70b7', '7a5e81b1-5777-425c-968a-ccac5f43fcae', '2025-12-11', 'morning', 'submitted', 'Branch 2 opening count', '6c4746c9-75c7-4d40-bd3f-309dc6b5968a', '2025-12-11 17:36:51.348936+02', NULL, NULL, '2025-12-11 17:36:51.348936+02', '2025-12-11 17:36:51.348936+02');
INSERT INTO public.daily_inventory_counts VALUES ('6cd06980-4039-4b84-bf08-ba4bd861f11c', '7a5e81b1-5777-425c-968a-ccac5f43fcae', '2025-12-11', 'evening', 'submitted', 'End of day count - all items verified', '6c4746c9-75c7-4d40-bd3f-309dc6b5968a', '2025-12-11 18:58:00.726908+02', NULL, NULL, '2025-12-11 18:58:00.726908+02', '2025-12-11 18:58:00.726908+02');


--
-- Data for Name: damage_reasons; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.damage_reasons VALUES ('a2fc7335-ec53-411d-aca6-c188c6ff7c8f', 'EXPIRED', 'Expired', 'Expired', NULL, true, 1, '2025-12-11 17:16:37.109709+02');
INSERT INTO public.damage_reasons VALUES ('9dc4a5c1-0864-4da6-9eb1-0beb0703291b', 'STORAGE', 'Poor Storage', 'Poor Storage', NULL, true, 2, '2025-12-11 17:16:37.109709+02');
INSERT INTO public.damage_reasons VALUES ('091f4ad7-3f0d-410c-b75b-92ff04a6872a', 'TRANSPORT', 'Transport Damage', 'Transport Damage', NULL, true, 3, '2025-12-11 17:16:37.109709+02');
INSERT INTO public.damage_reasons VALUES ('e660256a-64d2-4f87-8501-bc91200de66e', 'CONTAMINATION', 'Contamination', 'Contamination', NULL, true, 4, '2025-12-11 17:16:37.109709+02');
INSERT INTO public.damage_reasons VALUES ('3c995f36-1324-4e18-8d2d-bfc8499a61db', 'MOISTURE', 'Moisture/Leak', 'Moisture/Leak', NULL, true, 5, '2025-12-11 17:16:37.109709+02');
INSERT INTO public.damage_reasons VALUES ('e5c0fdc1-eca9-4e80-a745-79ab0e4fbdce', 'HEAT', 'Heat/Fire', 'Heat/Fire', NULL, true, 6, '2025-12-11 17:16:37.109709+02');
INSERT INTO public.damage_reasons VALUES ('242fce53-ea65-4f3c-a9a1-410ec73abdba', 'OTHER', 'Other', 'Other', NULL, true, 99, '2025-12-11 17:16:37.109709+02');


--
-- Data for Name: damages; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.damages VALUES ('a8cc90e9-ebd0-4060-a97e-e53170ab9fde', 'DMG-2024-001', '0375f387-cb50-46ff-b41d-d60fe932addf', 'c4394116-cc14-4a0b-ba16-13189361429e', 2.000, 245.00, 490.00, 'a2fc7335-ec53-411d-aca6-c188c6ff7c8f', 'Found expired during inspection', NULL, NULL, 'approved', '0bd55267-11ed-4a77-aa37-8a990e94dd31', '2025-12-11 17:25:43.04515+02', 'a0ada47f-f5ff-43b3-8c3e-68492f870fc1', '2025-12-11 17:25:43.04515+02', NULL, NULL, NULL, '2025-12-11 17:25:43.04515+02', '2025-12-11 17:25:43.04515+02');
INSERT INTO public.damages VALUES ('b113bc5b-82aa-49d6-9894-55153a0f0eb9', 'DMG-2024-002', '393fdf52-1982-481b-a254-11ba0edc1d8b', '9194f596-622a-46e7-bcd8-537b322083d2', 3.000, 78.00, 234.00, '9dc4a5c1-0864-4da6-9eb1-0beb0703291b', 'Refrigerator malfunction', NULL, NULL, 'pending', 'eff3e90d-dbf6-4536-baa5-1ff53e82c659', '2025-12-11 17:25:43.054176+02', NULL, NULL, NULL, NULL, NULL, '2025-12-11 17:25:43.054176+02', '2025-12-11 17:25:43.054176+02');
INSERT INTO public.damages VALUES ('8cd8b543-1173-482e-b30b-9db9f1a38963', 'DMG-2024-003', '0375f387-cb50-46ff-b41d-d60fe932addf', 'dd165c16-b9b3-476c-8309-47a08dfacca9', 5.000, 15.00, 75.00, '091f4ad7-3f0d-410c-b75b-92ff04a6872a', 'Tomatoes crushed during delivery', NULL, NULL, 'approved', '0bd55267-11ed-4a77-aa37-8a990e94dd31', '2025-12-11 17:36:51.207796+02', 'a0ada47f-f5ff-43b3-8c3e-68492f870fc1', '2025-12-11 17:36:51.215631+02', NULL, NULL, NULL, '2025-12-11 17:36:51.207796+02', '2025-12-11 17:36:51.207796+02');
INSERT INTO public.damages VALUES ('eb2d80c1-bc4e-4e17-9193-52049a3c5c6f', 'DMG-2024-004', '0375f387-cb50-46ff-b41d-d60fe932addf', '431d3ad0-1b54-483a-8572-332da247a065', 3.000, 120.00, 360.00, 'e660256a-64d2-4f87-8501-bc91200de66e', 'Cheese contaminated - mold found', NULL, NULL, 'approved', '0bd55267-11ed-4a77-aa37-8a990e94dd31', '2025-12-11 17:36:51.211605+02', 'a0ada47f-f5ff-43b3-8c3e-68492f870fc1', '2025-12-11 17:36:51.215631+02', NULL, NULL, NULL, '2025-12-11 17:36:51.211605+02', '2025-12-11 17:36:51.211605+02');
INSERT INTO public.damages VALUES ('0cfe0b23-8d67-46f8-a63a-5cee2436a950', 'DMG-2024-005', '393fdf52-1982-481b-a254-11ba0edc1d8b', '99484384-95cd-475e-8c06-971ec03f75f7', 10.000, 8.00, 80.00, 'e5c0fdc1-eca9-4e80-a745-79ab0e4fbdce', 'Pepsi bottles exploded due to heat', NULL, NULL, 'rejected', 'eff3e90d-dbf6-4536-baa5-1ff53e82c659', '2025-12-11 17:36:51.213673+02', NULL, NULL, 'a0ada47f-f5ff-43b3-8c3e-68492f870fc1', '2025-12-11 17:36:51.218991+02', 'Need photos and more details before approval', '2025-12-11 17:36:51.213673+02', '2025-12-11 17:36:51.213673+02');
INSERT INTO public.damages VALUES ('7da16c70-0162-47a4-a1b9-737be418dc2b', 'DMG-2024-006', '7a5e81b1-5777-425c-968a-ccac5f43fcae', '9194f596-622a-46e7-bcd8-537b322083d2', 8.000, 78.00, 624.00, '9dc4a5c1-0864-4da6-9eb1-0beb0703291b', 'Chicken found spoiled in storage', NULL, NULL, 'approved', '6c4746c9-75c7-4d40-bd3f-309dc6b5968a', '2025-12-11 18:58:00.659369+02', 'a0ada47f-f5ff-43b3-8c3e-68492f870fc1', '2025-12-11 18:58:00.664333+02', NULL, NULL, NULL, '2025-12-11 18:58:00.659369+02', '2025-12-11 18:58:00.659369+02');


--
-- Data for Name: django_content_type; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: django_migrations; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.django_migrations VALUES (1, 'accounts', '0001_initial', '2025-12-11 19:47:34.940871+02');
INSERT INTO public.django_migrations VALUES (2, 'branches', '0001_initial', '2025-12-11 19:47:34.95372+02');
INSERT INTO public.django_migrations VALUES (3, 'contenttypes', '0001_initial', '2025-12-11 19:47:34.974532+02');
INSERT INTO public.django_migrations VALUES (4, 'contenttypes', '0002_remove_content_type_name', '2025-12-11 19:47:34.984454+02');
INSERT INTO public.django_migrations VALUES (5, 'auth', '0001_initial', '2025-12-11 19:47:35.024246+02');
INSERT INTO public.django_migrations VALUES (6, 'auth', '0002_alter_permission_name_max_length', '2025-12-11 19:47:35.028706+02');
INSERT INTO public.django_migrations VALUES (7, 'auth', '0003_alter_user_email_max_length', '2025-12-11 19:47:35.031903+02');
INSERT INTO public.django_migrations VALUES (8, 'auth', '0004_alter_user_username_opts', '2025-12-11 19:47:35.03559+02');
INSERT INTO public.django_migrations VALUES (9, 'auth', '0005_alter_user_last_login_null', '2025-12-11 19:47:35.039192+02');
INSERT INTO public.django_migrations VALUES (10, 'auth', '0006_require_contenttypes_0002', '2025-12-11 19:47:35.040328+02');
INSERT INTO public.django_migrations VALUES (11, 'auth', '0007_alter_validators_add_error_messages', '2025-12-11 19:47:35.043566+02');
INSERT INTO public.django_migrations VALUES (12, 'auth', '0008_alter_user_username_max_length', '2025-12-11 19:47:35.046949+02');
INSERT INTO public.django_migrations VALUES (13, 'auth', '0009_alter_user_last_name_max_length', '2025-12-11 19:47:35.052137+02');
INSERT INTO public.django_migrations VALUES (14, 'auth', '0010_alter_group_name_max_length', '2025-12-11 19:47:35.057333+02');
INSERT INTO public.django_migrations VALUES (15, 'auth', '0011_update_proxy_permissions', '2025-12-11 19:47:35.064352+02');
INSERT INTO public.django_migrations VALUES (16, 'auth', '0012_alter_user_first_name_max_length', '2025-12-11 19:47:35.068333+02');


--
-- Data for Name: inventory; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.inventory VALUES ('11d646a7-bdce-4699-bcc0-68aff8819077', '393fdf52-1982-481b-a254-11ba0edc1d8b', 'dd165c16-b9b3-476c-8309-47a08dfacca9', 20.000, 0.000, 20.000, NULL, NULL, '2025-12-11 17:25:43.025449+02', '2025-12-11 17:25:43.025449+02', 0.000, 0.000, 0.000, NULL, NULL, NULL, '2025-12-11', NULL, 0.000, 0.000, 0.000, NULL);
INSERT INTO public.inventory VALUES ('308ae2af-844a-4cdb-8c92-56b7a512931e', '7a5e81b1-5777-425c-968a-ccac5f43fcae', '9194f596-622a-46e7-bcd8-537b322083d2', 2.000, 0.000, 15.000, NULL, NULL, '2025-12-11 17:36:51.33227+02', '2025-12-11 19:24:50.252874+02', 0.000, 0.000, 0.000, NULL, NULL, NULL, '2025-12-11', 'INV-BR002-2024-12-0001', 1.000, 2.000, 2.000, 'Chicken - 1 bag, 2 kg remaining');
INSERT INTO public.inventory VALUES ('fdd6db31-85db-477c-999b-d5f453f09f40', '393fdf52-1982-481b-a254-11ba0edc1d8b', '718d6492-8a33-409f-8939-373649df220a', 40.000, 0.000, 20.000, NULL, NULL, '2025-12-11 18:58:00.651452+02', '2025-12-11 19:24:50.25369+02', 0.000, 0.000, 0.000, NULL, NULL, NULL, '2025-12-11', NULL, 4.000, 10.000, 40.000, 'Rice - 4 bags, each 10 kg');
INSERT INTO public.inventory VALUES ('2a3d7ee2-5cf2-498e-96bd-090e56dba3a6', '393fdf52-1982-481b-a254-11ba0edc1d8b', '99484384-95cd-475e-8c06-971ec03f75f7', 50.000, 0.000, 50.000, NULL, NULL, '2025-12-11 17:25:43.027248+02', '2025-12-11 19:24:50.25437+02', 0.000, 0.000, 0.000, NULL, NULL, NULL, '2025-12-11', NULL, 2.000, 24.000, 48.000, 'Pepsi - 2 cartons, 24 bottles each + 2 loose');
INSERT INTO public.inventory VALUES ('6de15893-1d54-4bdf-a19e-e9b2da1c5d80', '7a5e81b1-5777-425c-968a-ccac5f43fcae', '99484384-95cd-475e-8c06-971ec03f75f7', 62.000, 0.000, 50.000, NULL, NULL, '2025-12-11 17:36:51.340908+02', '2025-12-11 19:24:50.255005+02', 0.000, 0.000, 0.000, NULL, NULL, NULL, '2025-12-11', NULL, 2.000, 24.000, 48.000, 'Pepsi - 2 cartons + 14 loose bottles');
INSERT INTO public.inventory VALUES ('b48f2a71-7cee-48d5-8b90-a72018154e27', '7a5e81b1-5777-425c-968a-ccac5f43fcae', 'c4394116-cc14-4a0b-ba16-13189361429e', 10.000, 0.000, 8.000, NULL, NULL, '2025-12-11 17:36:51.334696+02', '2025-12-11 17:36:51.334696+02', 0.000, 0.000, 0.000, NULL, NULL, NULL, '2025-12-11', NULL, 0.000, 0.000, 0.000, NULL);
INSERT INTO public.inventory VALUES ('97d812c9-819e-4e5f-ab28-93e6a21a6592', '7a5e81b1-5777-425c-968a-ccac5f43fcae', 'dd165c16-b9b3-476c-8309-47a08dfacca9', 30.000, 0.000, 25.000, NULL, NULL, '2025-12-11 17:36:51.337327+02', '2025-12-11 17:36:51.337327+02', 0.000, 0.000, 0.000, NULL, NULL, NULL, '2025-12-11', NULL, 0.000, 0.000, 0.000, NULL);
INSERT INTO public.inventory VALUES ('9395a688-d8de-4512-84e3-6ad1babcfd7e', '7a5e81b1-5777-425c-968a-ccac5f43fcae', '718d6492-8a33-409f-8939-373649df220a', 50.000, 0.000, 30.000, NULL, NULL, '2025-12-11 17:36:51.339306+02', '2025-12-11 17:36:51.339306+02', 0.000, 0.000, 0.000, NULL, NULL, NULL, '2025-12-11', NULL, 0.000, 0.000, 0.000, NULL);
INSERT INTO public.inventory VALUES ('e853db21-fdd7-483a-bc5f-e2cd5ab4c152', '0375f387-cb50-46ff-b41d-d60fe932addf', 'dd165c16-b9b3-476c-8309-47a08dfacca9', 45.000, 0.000, 100.000, '2025-12-11 17:25:43.010183+02', NULL, '2025-12-11 17:25:43.010183+02', '2025-12-11 18:14:49.483557+02', 0.000, 0.000, 5.000, NULL, '2025-12-01', '2025-12-31', '2025-12-11', NULL, 0.000, 0.000, 0.000, NULL);
INSERT INTO public.inventory VALUES ('a90f485b-1a34-4f43-8370-a54b95ef3f66', '0375f387-cb50-46ff-b41d-d60fe932addf', 'ad18601e-1e61-4ad9-8b66-1b8e1b9f0932', 45.000, 0.000, 80.000, '2025-12-11 17:25:43.012543+02', NULL, '2025-12-11 17:25:43.012543+02', '2025-12-11 18:14:49.483557+02', 0.000, 0.000, 0.000, NULL, '2025-12-01', '2025-12-31', '2025-12-11', NULL, 0.000, 0.000, 0.000, NULL);
INSERT INTO public.inventory VALUES ('dd8938fc-3024-42f3-ab3a-d4aabf59107b', '0375f387-cb50-46ff-b41d-d60fe932addf', 'bfbff945-e1b4-4cfe-8fac-274fe629b3dd', 25.000, 0.000, 20.000, '2025-12-11 17:25:43.014424+02', NULL, '2025-12-11 17:25:43.014424+02', '2025-12-11 18:14:49.483557+02', 0.000, 0.000, 0.000, NULL, '2025-12-01', '2025-12-31', '2025-12-11', NULL, 0.000, 0.000, 0.000, NULL);
INSERT INTO public.inventory VALUES ('c02a94fb-1682-4c99-bcbc-7b27be8c3b2d', '0375f387-cb50-46ff-b41d-d60fe932addf', '431d3ad0-1b54-483a-8572-332da247a065', 32.000, 0.000, 20.000, '2025-12-11 17:25:43.018209+02', NULL, '2025-12-11 17:25:43.018209+02', '2025-12-11 18:14:49.483557+02', 0.000, 20.000, 3.000, NULL, '2025-12-01', '2025-12-31', '2025-12-11', NULL, 0.000, 0.000, 0.000, NULL);
INSERT INTO public.inventory VALUES ('e9d5f3b9-8f3e-4154-b8d8-c4b72653a57c', '0375f387-cb50-46ff-b41d-d60fe932addf', '99484384-95cd-475e-8c06-971ec03f75f7', 318.000, 0.000, 200.000, '2025-12-11 17:25:43.020101+02', NULL, '2025-12-11 17:25:43.020101+02', '2025-12-11 18:14:49.483557+02', 0.000, 0.000, 0.000, NULL, '2025-12-01', '2025-12-31', '2025-12-11', NULL, 0.000, 0.000, 0.000, NULL);
INSERT INTO public.inventory VALUES ('96399edb-3b65-401b-883d-3512978b9703', '0375f387-cb50-46ff-b41d-d60fe932addf', '9194f596-622a-46e7-bcd8-537b322083d2', 65.000, 0.000, 50.000, '2025-12-11 17:25:43.001588+02', NULL, '2025-12-11 17:25:43.001588+02', '2025-12-11 18:14:49.483557+02', 0.000, 80.000, 25.000, NULL, '2025-12-01', '2025-12-31', '2025-12-11', NULL, 0.000, 0.000, 0.000, NULL);
INSERT INTO public.inventory VALUES ('9b689234-79d7-4ffa-ba41-1a8b852cd84e', '0375f387-cb50-46ff-b41d-d60fe932addf', 'c4394116-cc14-4a0b-ba16-13189361429e', 25.000, 0.000, 30.000, '2025-12-11 17:25:43.00806+02', NULL, '2025-12-11 17:25:43.00806+02', '2025-12-11 18:14:49.483557+02', 0.000, 30.000, 2.000, NULL, '2025-12-01', '2025-12-31', '2025-12-11', NULL, 0.000, 0.000, 0.000, NULL);
INSERT INTO public.inventory VALUES ('961f0530-85ab-4d5f-aa07-c5068097d0f5', '0375f387-cb50-46ff-b41d-d60fe932addf', '718d6492-8a33-409f-8939-373649df220a', 188.000, 0.000, 100.000, '2025-12-11 17:25:43.01619+02', NULL, '2025-12-11 17:25:43.01619+02', '2025-12-11 18:14:49.483557+02', 0.000, 100.000, 0.000, NULL, '2025-12-01', '2025-12-31', '2025-12-11', NULL, 0.000, 0.000, 0.000, NULL);
INSERT INTO public.inventory VALUES ('4237720c-8474-4e4f-a664-3edbba82e506', '393fdf52-1982-481b-a254-11ba0edc1d8b', '9194f596-622a-46e7-bcd8-537b322083d2', 30.000, 0.000, 10.000, NULL, NULL, '2025-12-11 17:25:43.02175+02', '2025-12-11 19:24:50.24508+02', 0.000, 0.000, 0.000, NULL, NULL, NULL, '2025-12-11', 'INV-BR001-2024-12-0001', 5.000, 6.000, 30.000, 'Chicken breast - 5 bags, each 6 kg, for grilling');
INSERT INTO public.inventory VALUES ('d1445871-cb88-4a89-a346-910e5be6ea0a', '393fdf52-1982-481b-a254-11ba0edc1d8b', 'c4394116-cc14-4a0b-ba16-13189361429e', 10.000, 0.000, 5.000, NULL, NULL, '2025-12-11 17:25:43.02362+02', '2025-12-11 19:24:50.25172+02', 0.000, 0.000, 0.000, NULL, NULL, NULL, '2025-12-11', 'INV-BR001-2024-12-0002', 2.000, 5.000, 10.000, 'Beef cuts - 2 boxes, each 5 kg, for steaks');


--
-- Data for Name: inventory_batches; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.inventory_batches VALUES ('9cc5bc93-d6eb-42fc-b243-76a3e21cbea5', '96399edb-3b65-401b-883d-3512978b9703', 'BATCH-001', 30.000, 25.000, 78.00, NULL, '2025-12-16', '2025-12-11', '381c4da0-06e3-4058-9974-1f337b74cd60', '2025-12-11 17:25:43.028844+02');
INSERT INTO public.inventory_batches VALUES ('0ad8ccce-8111-4c72-9f75-b7a44418c6c3', '9b689234-79d7-4ffa-ba41-1a8b852cd84e', 'BATCH-002', 10.000, 8.000, 245.00, NULL, '2025-12-14', '2025-12-11', '381c4da0-06e3-4058-9974-1f337b74cd60', '2025-12-11 17:25:43.033226+02');
INSERT INTO public.inventory_batches VALUES ('b20c29fc-d5cc-41d8-9ec2-9ba4b8ce1072', '96399edb-3b65-401b-883d-3512978b9703', 'BATCH-005', 50.000, 50.000, 78.00, NULL, '2025-12-18', '2025-12-11', '09625919-731b-4c97-9039-0ef4354bfbd9', '2025-12-11 17:36:51.167494+02');
INSERT INTO public.inventory_batches VALUES ('f98a9588-2c09-4cc0-8992-8a1b698605f6', '9b689234-79d7-4ffa-ba41-1a8b852cd84e', 'BATCH-006', 20.000, 20.000, 245.00, NULL, '2025-12-16', '2025-12-11', '09625919-731b-4c97-9039-0ef4354bfbd9', '2025-12-11 17:36:51.171808+02');
INSERT INTO public.inventory_batches VALUES ('81c8aecb-4b89-41d6-8032-d7af77ba7db3', 'c02a94fb-1682-4c99-bcbc-7b27be8c3b2d', 'BATCH-007', 20.000, 20.000, 120.00, NULL, '2026-01-10', '2025-12-11', '0738e999-4886-4ee3-bed4-b774828030a0', '2025-12-11 17:36:51.393669+02');


--
-- Data for Name: inventory_transactions; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.inventory_transactions VALUES ('8d8fd730-a2fc-441c-8ee6-98d412b77459', '0375f387-cb50-46ff-b41d-d60fe932addf', '9194f596-622a-46e7-bcd8-537b322083d2', 'supply', 30.000, 0.000, 30.000, 78.00, 'supply', NULL, NULL, NULL, '0bd55267-11ed-4a77-aa37-8a990e94dd31', '2025-12-11 17:25:43.062192+02');
INSERT INTO public.inventory_transactions VALUES ('1d55170c-b66e-4d6b-922f-1ff1fd5b83c1', '0375f387-cb50-46ff-b41d-d60fe932addf', 'c4394116-cc14-4a0b-ba16-13189361429e', 'supply', 10.000, 0.000, 10.000, 245.00, 'supply', NULL, NULL, NULL, '0bd55267-11ed-4a77-aa37-8a990e94dd31', '2025-12-11 17:25:43.067249+02');
INSERT INTO public.inventory_transactions VALUES ('454848b8-9205-4224-936e-5d8b855451b7', '0375f387-cb50-46ff-b41d-d60fe932addf', '9194f596-622a-46e7-bcd8-537b322083d2', 'transfer_out', 10.000, 30.000, 20.000, NULL, 'transfer', NULL, NULL, NULL, '0bd55267-11ed-4a77-aa37-8a990e94dd31', '2025-12-11 17:25:43.06929+02');
INSERT INTO public.inventory_transactions VALUES ('2143ba6f-d73c-4e1d-b81d-373e6c6283b3', '393fdf52-1982-481b-a254-11ba0edc1d8b', '9194f596-622a-46e7-bcd8-537b322083d2', 'transfer_in', 10.000, 0.000, 10.000, NULL, 'transfer', NULL, NULL, NULL, 'eff3e90d-dbf6-4536-baa5-1ff53e82c659', '2025-12-11 17:25:43.071224+02');
INSERT INTO public.inventory_transactions VALUES ('696bf76f-58f4-4a0f-ac8c-bcf6c0800353', '0375f387-cb50-46ff-b41d-d60fe932addf', 'c4394116-cc14-4a0b-ba16-13189361429e', 'damage', 2.000, 10.000, 8.000, 245.00, 'damage', NULL, NULL, NULL, '0bd55267-11ed-4a77-aa37-8a990e94dd31', '2025-12-11 17:25:43.073903+02');
INSERT INTO public.inventory_transactions VALUES ('1ced150c-40ea-4ddd-b8c6-8dd7f0df3219', '0375f387-cb50-46ff-b41d-d60fe932addf', '9194f596-622a-46e7-bcd8-537b322083d2', 'return', 5.000, 25.000, 20.000, 78.00, 'supplier_return', NULL, NULL, NULL, '0bd55267-11ed-4a77-aa37-8a990e94dd31', '2025-12-11 17:25:43.076276+02');
INSERT INTO public.inventory_transactions VALUES ('95965c30-bcbf-4abf-8418-7d388771c46c', '393fdf52-1982-481b-a254-11ba0edc1d8b', '9194f596-622a-46e7-bcd8-537b322083d2', 'consumption', 0.500, 10.000, 9.500, NULL, 'order', NULL, NULL, NULL, '53c3ad83-b852-4386-9a69-afdb98a4d9c9', '2025-12-11 17:25:43.07821+02');
INSERT INTO public.inventory_transactions VALUES ('cc8629ec-8777-49f0-898d-b313c0bc71b3', '0375f387-cb50-46ff-b41d-d60fe932addf', '9194f596-622a-46e7-bcd8-537b322083d2', 'supply', 50.000, 30.000, 80.000, 78.00, 'supply', NULL, NULL, NULL, '0bd55267-11ed-4a77-aa37-8a990e94dd31', '2025-12-11 17:36:51.174061+02');
INSERT INTO public.inventory_transactions VALUES ('656048ac-24ab-4faf-806a-d916ae642722', '0375f387-cb50-46ff-b41d-d60fe932addf', 'c4394116-cc14-4a0b-ba16-13189361429e', 'supply', 20.000, 10.000, 30.000, 245.00, 'supply', NULL, NULL, NULL, '0bd55267-11ed-4a77-aa37-8a990e94dd31', '2025-12-11 17:36:51.177968+02');
INSERT INTO public.inventory_transactions VALUES ('978eeed2-41f7-4713-91eb-b00328491084', '0375f387-cb50-46ff-b41d-d60fe932addf', 'dd165c16-b9b3-476c-8309-47a08dfacca9', 'damage', 5.000, 50.000, 45.000, 15.00, 'damage', NULL, NULL, NULL, '0bd55267-11ed-4a77-aa37-8a990e94dd31', '2025-12-11 17:36:51.222485+02');
INSERT INTO public.inventory_transactions VALUES ('00a0a24c-b09a-453e-81b9-86613fc22ac9', '0375f387-cb50-46ff-b41d-d60fe932addf', '431d3ad0-1b54-483a-8572-332da247a065', 'damage', 3.000, 15.000, 12.000, 120.00, 'damage', NULL, NULL, NULL, '0bd55267-11ed-4a77-aa37-8a990e94dd31', '2025-12-11 17:36:51.224857+02');
INSERT INTO public.inventory_transactions VALUES ('0499bfd1-6c1e-4b33-b7d1-c6d5b90ff24b', '0375f387-cb50-46ff-b41d-d60fe932addf', '9194f596-622a-46e7-bcd8-537b322083d2', 'return', 10.000, 80.000, 70.000, 78.00, 'supplier_return', NULL, NULL, NULL, '0bd55267-11ed-4a77-aa37-8a990e94dd31', '2025-12-11 17:36:51.237197+02');
INSERT INTO public.inventory_transactions VALUES ('a90b956d-c1e7-442a-ab17-967eb882575b', '393fdf52-1982-481b-a254-11ba0edc1d8b', '9194f596-622a-46e7-bcd8-537b322083d2', 'consumption', 0.500, 9.500, 9.000, NULL, 'order', NULL, NULL, NULL, '53c3ad83-b852-4386-9a69-afdb98a4d9c9', '2025-12-11 17:36:51.264787+02');
INSERT INTO public.inventory_transactions VALUES ('8a261126-e64c-4c9b-a2f6-79e715b84684', '0375f387-cb50-46ff-b41d-d60fe932addf', 'ad18601e-1e61-4ad9-8b66-1b8e1b9f0932', 'adjustment', 5.000, 40.000, 45.000, NULL, 'adjustment', NULL, NULL, 'Found extra stock during reorganization', '0bd55267-11ed-4a77-aa37-8a990e94dd31', '2025-12-11 17:36:51.288109+02');
INSERT INTO public.inventory_transactions VALUES ('8f46fd49-c456-40b8-b8aa-878dfefdf231', '0375f387-cb50-46ff-b41d-d60fe932addf', '718d6492-8a33-409f-8939-373649df220a', 'adjustment', -2.000, 150.000, 148.000, NULL, 'adjustment', NULL, NULL, 'Discrepancy found during audit', '0bd55267-11ed-4a77-aa37-8a990e94dd31', '2025-12-11 17:36:51.291467+02');
INSERT INTO public.inventory_transactions VALUES ('5607250a-beca-4cc0-ad07-8e8ed81d2e01', '0375f387-cb50-46ff-b41d-d60fe932addf', '431d3ad0-1b54-483a-8572-332da247a065', 'supply', 20.000, 12.000, 32.000, 120.00, 'supply', NULL, NULL, NULL, '0bd55267-11ed-4a77-aa37-8a990e94dd31', '2025-12-11 17:36:51.395697+02');
INSERT INTO public.inventory_transactions VALUES ('2a29c10c-a377-4b1b-b3d3-fae316569053', '0375f387-cb50-46ff-b41d-d60fe932addf', '9194f596-622a-46e7-bcd8-537b322083d2', 'transfer_in', 15.000, 70.000, 85.000, 78.00, 'branch_return', NULL, NULL, 'Branch return BRT-2024-12-0003', '0bd55267-11ed-4a77-aa37-8a990e94dd31', '2025-12-11 18:34:18.458208+02');
INSERT INTO public.inventory_transactions VALUES ('a3216c5b-909e-4530-9a25-2a7a17535479', '0375f387-cb50-46ff-b41d-d60fe932addf', '99484384-95cd-475e-8c06-971ec03f75f7', 'transfer_in', 18.000, 100.000, 118.000, 8.00, 'branch_return', NULL, NULL, 'Branch return BRT-2024-12-0003', '0bd55267-11ed-4a77-aa37-8a990e94dd31', '2025-12-11 18:34:18.470086+02');
INSERT INTO public.inventory_transactions VALUES ('c08a1ecf-d088-410c-a019-e5fefd40f9d9', '0375f387-cb50-46ff-b41d-d60fe932addf', '718d6492-8a33-409f-8939-373649df220a', 'supply', 100.000, 148.000, 248.000, 35.00, 'supply', NULL, NULL, NULL, '0bd55267-11ed-4a77-aa37-8a990e94dd31', '2025-12-11 18:58:00.619462+02');
INSERT INTO public.inventory_transactions VALUES ('c321d6ca-ff06-406a-a058-4fb676a98ab4', '0375f387-cb50-46ff-b41d-d60fe932addf', '9194f596-622a-46e7-bcd8-537b322083d2', 'transfer_out', 20.000, 85.000, 65.000, NULL, 'transfer', NULL, NULL, NULL, '0bd55267-11ed-4a77-aa37-8a990e94dd31', '2025-12-11 18:58:00.655126+02');
INSERT INTO public.inventory_transactions VALUES ('ceefb549-87c5-47e8-81a5-3ed38a6e1459', '393fdf52-1982-481b-a254-11ba0edc1d8b', '9194f596-622a-46e7-bcd8-537b322083d2', 'transfer_in', 20.000, 10.000, 30.000, NULL, 'transfer', NULL, NULL, NULL, 'eff3e90d-dbf6-4536-baa5-1ff53e82c659', '2025-12-11 18:58:00.657387+02');
INSERT INTO public.inventory_transactions VALUES ('0ba11ff4-0590-4555-b6e2-10ca6645f378', '7a5e81b1-5777-425c-968a-ccac5f43fcae', '9194f596-622a-46e7-bcd8-537b322083d2', 'damage', 8.000, 10.000, 2.000, 78.00, 'damage', NULL, NULL, NULL, '6c4746c9-75c7-4d40-bd3f-309dc6b5968a', '2025-12-11 18:58:00.668609+02');
INSERT INTO public.inventory_transactions VALUES ('e4d01037-f209-4068-a005-f52de6edc3cd', '393fdf52-1982-481b-a254-11ba0edc1d8b', 'c4394116-cc14-4a0b-ba16-13189361429e', 'transfer_out', 5.000, 15.000, 10.000, 245.00, 'branch_return', NULL, NULL, 'Branch return BRT-2024-12-0006', 'eff3e90d-dbf6-4536-baa5-1ff53e82c659', '2025-12-11 18:58:00.685843+02');
INSERT INTO public.inventory_transactions VALUES ('5b912ca7-1161-43ba-b91c-52d50ddf4799', '0375f387-cb50-46ff-b41d-d60fe932addf', 'c4394116-cc14-4a0b-ba16-13189361429e', 'transfer_in', 5.000, 30.000, 35.000, 245.00, 'branch_return', NULL, NULL, 'Branch return BRT-2024-12-0006', '0bd55267-11ed-4a77-aa37-8a990e94dd31', '2025-12-11 18:58:00.6877+02');
INSERT INTO public.inventory_transactions VALUES ('11fe9f39-da87-43be-9c33-78c775cf0f77', '0375f387-cb50-46ff-b41d-d60fe932addf', '718d6492-8a33-409f-8939-373649df220a', 'return', 20.000, 248.000, 228.000, 35.00, 'supplier_return', NULL, NULL, NULL, '0bd55267-11ed-4a77-aa37-8a990e94dd31', '2025-12-11 18:58:00.694082+02');
INSERT INTO public.inventory_transactions VALUES ('0ecf6c12-2611-43d8-a74c-39af27c03e7f', '7a5e81b1-5777-425c-968a-ccac5f43fcae', '9194f596-622a-46e7-bcd8-537b322083d2', 'consumption', 0.750, 2.000, 1.250, NULL, 'order', NULL, NULL, NULL, 'f34679bc-52fa-4b0f-9e95-0b7306af2468', '2025-12-11 18:58:00.724299+02');


--
-- Data for Name: items; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.items VALUES ('9194f596-622a-46e7-bcd8-537b322083d2', 'ITM001', '1234567890001', 'Chicken Breast', 'Chicken', NULL, 'bae9363b-443a-4cd4-8230-7861b4ce0ea7', 'e6672057-ac2c-4cca-b054-89fc377fdb5c', 80.00, 0.00, 50.000, NULL, NULL, true, 5, NULL, 'active', NULL, '2025-12-11 17:25:42.957725+02', '2025-12-11 17:25:42.957725+02', NULL);
INSERT INTO public.items VALUES ('c4394116-cc14-4a0b-ba16-13189361429e', 'ITM002', '1234567890002', 'Beef Meat', 'Beef', NULL, 'bae9363b-443a-4cd4-8230-7861b4ce0ea7', 'e6672057-ac2c-4cca-b054-89fc377fdb5c', 250.00, 0.00, 30.000, NULL, NULL, true, 3, NULL, 'active', NULL, '2025-12-11 17:25:42.964557+02', '2025-12-11 17:25:42.964557+02', NULL);
INSERT INTO public.items VALUES ('dd165c16-b9b3-476c-8309-47a08dfacca9', 'ITM003', '1234567890003', 'Tomatoes', 'Tomatoes', NULL, '5dc69575-7f72-4214-ae63-f984eb3b39c0', 'e6672057-ac2c-4cca-b054-89fc377fdb5c', 15.00, 0.00, 100.000, NULL, NULL, true, 7, NULL, 'active', NULL, '2025-12-11 17:25:42.966537+02', '2025-12-11 17:25:42.966537+02', NULL);
INSERT INTO public.items VALUES ('ad18601e-1e61-4ad9-8b66-1b8e1b9f0932', 'ITM004', '1234567890004', 'Onions', 'Onions', NULL, '5dc69575-7f72-4214-ae63-f984eb3b39c0', 'e6672057-ac2c-4cca-b054-89fc377fdb5c', 10.00, 0.00, 80.000, NULL, NULL, true, 14, NULL, 'active', NULL, '2025-12-11 17:25:42.968723+02', '2025-12-11 17:25:42.968723+02', NULL);
INSERT INTO public.items VALUES ('bfbff945-e1b4-4cfe-8fac-274fe629b3dd', 'ITM005', '1234567890005', 'Cooking Oil', 'Oil', NULL, 'de53cd45-4b5e-41c4-9f0c-b08ed4017a6c', '876adef7-7f0e-41ec-b42c-aa629728c37e', 45.00, 0.00, 20.000, NULL, NULL, false, 365, NULL, 'active', NULL, '2025-12-11 17:25:42.970697+02', '2025-12-11 17:25:42.970697+02', NULL);
INSERT INTO public.items VALUES ('718d6492-8a33-409f-8939-373649df220a', 'ITM006', '1234567890006', 'Rice', 'Rice', NULL, '5a483cf6-413a-417c-b6d4-6a7aca239095', 'e6672057-ac2c-4cca-b054-89fc377fdb5c', 35.00, 0.00, 100.000, NULL, NULL, false, 180, NULL, 'active', NULL, '2025-12-11 17:25:42.972624+02', '2025-12-11 17:25:42.972624+02', NULL);
INSERT INTO public.items VALUES ('431d3ad0-1b54-483a-8572-332da247a065', 'ITM007', '1234567890007', 'Cheese', 'Cheese', NULL, '515b0ee3-e3ca-4989-a3f1-b908b205432e', 'e6672057-ac2c-4cca-b054-89fc377fdb5c', 120.00, 0.00, 20.000, NULL, NULL, true, 30, NULL, 'active', NULL, '2025-12-11 17:25:42.974428+02', '2025-12-11 17:25:42.974428+02', NULL);
INSERT INTO public.items VALUES ('99484384-95cd-475e-8c06-971ec03f75f7', 'ITM008', '1234567890008', 'Pepsi', 'Pepsi', NULL, 'f4a4e59d-408c-4aeb-8a66-434899e9ade1', '44d9b3a5-3cff-4f4d-a96c-dc45bf4eed07', 8.00, 0.00, 200.000, NULL, NULL, false, 180, NULL, 'active', NULL, '2025-12-11 17:25:42.976668+02', '2025-12-11 17:25:42.976668+02', NULL);


--
-- Data for Name: menu_categories; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.menu_categories VALUES ('a2555e41-0550-4f26-b4c6-8ab91dd1958c', 'MCAT001', 'Grills', 'Ù…Ø´ÙˆÙŠØ§Øª', 'Grilled items', NULL, NULL, 1, true, '2025-12-11 17:24:12.318082+02', '2025-12-11 17:24:12.318082+02');
INSERT INTO public.menu_categories VALUES ('c30ce458-f55d-4f44-9814-d58f131fea27', 'MCAT002', 'Sandwiches', 'Ø³Ù†Ø¯ÙˆØªØ´Ø§Øª', 'Sandwiches', NULL, NULL, 2, true, '2025-12-11 17:24:12.318082+02', '2025-12-11 17:24:12.318082+02');
INSERT INTO public.menu_categories VALUES ('08e6c9db-dca8-479c-8d1d-f66121b5fd87', 'MCAT003', 'Meals', 'ÙˆØ¬Ø¨Ø§Øª', 'Complete meals', NULL, NULL, 3, true, '2025-12-11 17:24:12.318082+02', '2025-12-11 17:24:12.318082+02');
INSERT INTO public.menu_categories VALUES ('84a589e2-f10b-4235-b1c9-0a4691541a43', 'MCAT004', 'Drinks', 'Ù…Ø´Ø±ÙˆØ¨Ø§Øª', 'Beverages', NULL, NULL, 4, true, '2025-12-11 17:24:12.318082+02', '2025-12-11 17:24:12.318082+02');


--
-- Data for Name: menu_item_ingredients; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.menu_item_ingredients VALUES ('9b23eada-4f63-4281-bdc7-d0b39a56e9be', '8e1087bc-750a-4d7b-9ead-412fcc731112', '9194f596-622a-46e7-bcd8-537b322083d2', 0.2500, 'e6672057-ac2c-4cca-b054-89fc377fdb5c', false, '2025-12-11 17:25:43.081376+02');
INSERT INTO public.menu_item_ingredients VALUES ('8554195c-0eb1-40ce-9e24-185f936a9b2e', '8e1087bc-750a-4d7b-9ead-412fcc731112', '718d6492-8a33-409f-8939-373649df220a', 0.1000, 'e6672057-ac2c-4cca-b054-89fc377fdb5c', false, '2025-12-11 17:25:43.089026+02');
INSERT INTO public.menu_item_ingredients VALUES ('794a9db8-047e-43d3-a24d-948dc8762ea8', 'abcd391f-73e4-4208-8e9a-0577df7f84b5', 'c4394116-cc14-4a0b-ba16-13189361429e', 0.1500, 'e6672057-ac2c-4cca-b054-89fc377fdb5c', false, '2025-12-11 17:36:51.370054+02');
INSERT INTO public.menu_item_ingredients VALUES ('09a998ee-4822-4385-b877-b4e4d9463097', 'abcd391f-73e4-4208-8e9a-0577df7f84b5', '431d3ad0-1b54-483a-8572-332da247a065', 0.0500, 'e6672057-ac2c-4cca-b054-89fc377fdb5c', true, '2025-12-11 17:36:51.37397+02');
INSERT INTO public.menu_item_ingredients VALUES ('7fe657da-5524-4593-bd8f-9135a0380cf3', 'b7a4e824-2a16-40cf-9716-e2a203024ff4', '9194f596-622a-46e7-bcd8-537b322083d2', 0.2000, 'e6672057-ac2c-4cca-b054-89fc377fdb5c', false, '2025-12-11 17:36:51.376268+02');
INSERT INTO public.menu_item_ingredients VALUES ('eba17974-67d0-4fae-8a91-bf0b09a33ee8', 'b7a4e824-2a16-40cf-9716-e2a203024ff4', 'c4394116-cc14-4a0b-ba16-13189361429e', 0.2000, 'e6672057-ac2c-4cca-b054-89fc377fdb5c', false, '2025-12-11 17:36:51.378293+02');
INSERT INTO public.menu_item_ingredients VALUES ('a55b26b6-20f0-4b0a-ae0e-00feeed46751', 'df71a9f5-c7db-4f33-ac74-fb312f9eb1c2', '718d6492-8a33-409f-8939-373649df220a', 0.1500, 'e6672057-ac2c-4cca-b054-89fc377fdb5c', false, '2025-12-11 17:36:51.380294+02');
INSERT INTO public.menu_item_ingredients VALUES ('da0ebb79-ed42-4cf8-ba7a-001aba243134', 'df71a9f5-c7db-4f33-ac74-fb312f9eb1c2', 'dd165c16-b9b3-476c-8309-47a08dfacca9', 0.0500, 'e6672057-ac2c-4cca-b054-89fc377fdb5c', false, '2025-12-11 17:36:51.383179+02');
INSERT INTO public.menu_item_ingredients VALUES ('222361c1-6dfe-4c1e-ba10-32b2b57bbc2f', 'df71a9f5-c7db-4f33-ac74-fb312f9eb1c2', 'ad18601e-1e61-4ad9-8b66-1b8e1b9f0932', 0.0300, 'e6672057-ac2c-4cca-b054-89fc377fdb5c', false, '2025-12-11 17:36:51.385532+02');


--
-- Data for Name: menu_items; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.menu_items VALUES ('8e1087bc-750a-4d7b-9ead-412fcc731112', 'MENU001', 'Grilled Chicken', 'Ø¯Ø¬Ø§Ø¬ Ù…Ø´ÙˆÙŠ', 'Quarter grilled chicken with rice', NULL, 'a2555e41-0550-4f26-b4c6-8ab91dd1958c', 85.00, 45.00, 14.00, NULL, 20, NULL, true, true, 0, '2025-12-11 17:24:12.326669+02', '2025-12-11 17:24:12.326669+02');
INSERT INTO public.menu_items VALUES ('1fd35a9d-36ce-40c7-81be-3d0179b9edc9', 'MENU004', 'Pepsi', 'Ø¨ÙŠØ¨Ø³ÙŠ', 'Pepsi 330ml', NULL, '84a589e2-f10b-4235-b1c9-0a4691541a43', 15.00, 8.00, 14.00, NULL, 1, NULL, true, true, 0, '2025-12-11 17:24:12.332283+02', '2025-12-11 17:24:12.332283+02');
INSERT INTO public.menu_items VALUES ('abcd391f-73e4-4208-8e9a-0577df7f84b5', 'MENU005', 'Beef Burger', 'Beef Burger', 'Grilled beef burger with cheese', NULL, 'c30ce458-f55d-4f44-9814-d58f131fea27', 75.00, 40.00, 14.00, NULL, 15, NULL, true, true, 0, '2025-12-11 17:36:51.362358+02', '2025-12-11 17:36:51.362358+02');
INSERT INTO public.menu_items VALUES ('b7a4e824-2a16-40cf-9716-e2a203024ff4', 'MENU006', 'Mixed Grill', 'Mixed Grill', 'Assorted grilled meats', NULL, 'a2555e41-0550-4f26-b4c6-8ab91dd1958c', 180.00, 100.00, 14.00, NULL, 30, NULL, true, true, 0, '2025-12-11 17:36:51.36643+02', '2025-12-11 17:36:51.36643+02');
INSERT INTO public.menu_items VALUES ('df71a9f5-c7db-4f33-ac74-fb312f9eb1c2', 'MENU007', 'Rice Meal', 'Rice Meal', 'Rice with vegetables', NULL, '08e6c9db-dca8-479c-8d1d-f66121b5fd87', 45.00, 20.00, 14.00, NULL, 15, NULL, true, true, 0, '2025-12-11 17:36:51.368354+02', '2025-12-11 17:36:51.368354+02');


--
-- Data for Name: notifications; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.notifications VALUES ('dd0da31b-5c03-4d59-a435-28ceee32160d', '0bd55267-11ed-4a77-aa37-8a990e94dd31', '0375f387-cb50-46ff-b41d-d60fe932addf', 'expiry_warning', 'Expiry Warning', 'Some items will expire in 3 days', 'high', 'inventory', NULL, false, NULL, '2025-12-11 17:24:12.36287+02', NULL);
INSERT INTO public.notifications VALUES ('25d47853-5913-4aea-b27a-e954cf8e0570', '0bd55267-11ed-4a77-aa37-8a990e94dd31', '0375f387-cb50-46ff-b41d-d60fe932addf', 'transfer_request', 'New Transfer Request', 'Branch 1 requested items transfer', 'normal', 'transfer', 'eee5bdc4-5c73-4772-9d87-57c8bc28041e', false, NULL, '2025-12-11 17:24:12.367289+02', NULL);
INSERT INTO public.notifications VALUES ('c1dc35c1-aa5b-4185-9dd0-6e3ca14b9df3', '0bd55267-11ed-4a77-aa37-8a990e94dd31', '0375f387-cb50-46ff-b41d-d60fe932addf', 'low_stock', 'CRITICAL: Stock Depleted', 'Beef Meat stock is critically low (only 30 units)', 'high', 'inventory', NULL, false, NULL, '2025-12-11 17:36:51.294289+02', NULL);
INSERT INTO public.notifications VALUES ('abd71e17-05a8-4b0b-827f-821decbb0f25', '0bd55267-11ed-4a77-aa37-8a990e94dd31', '0375f387-cb50-46ff-b41d-d60fe932addf', 'expiry_warning', 'Items Expiring Soon', '3 batches will expire within 7 days. Please review.', 'high', 'inventory', NULL, false, NULL, '2025-12-11 17:36:51.297017+02', NULL);
INSERT INTO public.notifications VALUES ('519069f6-d22a-40ad-9113-d58090d45929', 'a0ada47f-f5ff-43b3-8c3e-68492f870fc1', NULL, 'pending_approval', 'Pending Approvals', 'You have 3 pending damage reports awaiting approval', 'normal', 'damage', NULL, false, NULL, '2025-12-11 17:36:51.299245+02', NULL);
INSERT INTO public.notifications VALUES ('c158efed-e157-4aa8-991a-97c4c5c31105', '0bd55267-11ed-4a77-aa37-8a990e94dd31', '0375f387-cb50-46ff-b41d-d60fe932addf', 'transfer_received', 'Transfer Received', 'Transfer TRF-2024-001 has been received at Branch 1', 'normal', 'transfer', NULL, true, NULL, '2025-12-11 17:36:51.300894+02', NULL);
INSERT INTO public.notifications VALUES ('804a70b5-1c40-4ad6-9f69-be4f16f65103', 'aaee8a92-fce0-4a57-9569-852ad211d873', '393fdf52-1982-481b-a254-11ba0edc1d8b', 'new_order', 'New Order Received', 'Order ORD-2024-004 is waiting in queue', 'high', 'order', NULL, false, NULL, '2025-12-11 17:36:51.303176+02', NULL);
INSERT INTO public.notifications VALUES ('e78773c7-aaf6-4b18-9982-97da4e06ef0a', 'a0ada47f-f5ff-43b3-8c3e-68492f870fc1', NULL, 'system', 'System Maintenance', 'Scheduled maintenance tonight at 2 AM', 'normal', NULL, NULL, false, NULL, '2025-12-11 17:36:51.305284+02', '2025-12-12 05:36:51.305284+02');
INSERT INTO public.notifications VALUES ('72bf29d6-c6df-4d5c-8764-1173b4ea9645', '0bd55267-11ed-4a77-aa37-8a990e94dd31', '0375f387-cb50-46ff-b41d-d60fe932addf', 'pending_approval', 'Branch Return Pending', 'Branch return BRT-2024-12-0001 from Branch 1 is waiting for approval', 'normal', 'branch_return', NULL, false, NULL, '2025-12-11 18:34:18.488777+02', NULL);
INSERT INTO public.notifications VALUES ('5c84e0df-bbaa-45fa-a6a7-bcb76f3764aa', '0bd55267-11ed-4a77-aa37-8a990e94dd31', '0375f387-cb50-46ff-b41d-d60fe932addf', 'transfer_received', 'Branch Return In Transit', 'Branch return BRT-2024-12-0002 is on the way to Main Warehouse', 'normal', 'branch_return', NULL, false, NULL, '2025-12-11 18:34:18.491487+02', NULL);
INSERT INTO public.notifications VALUES ('52674cd8-0e4b-4d32-a00c-ea14f274b0b7', 'eff3e90d-dbf6-4536-baa5-1ff53e82c659', '393fdf52-1982-481b-a254-11ba0edc1d8b', 'system', 'Branch Return Rejected', 'Your return request BRT-2024-12-0004 has been rejected. Reason: Oil is a stable item.', 'normal', 'branch_return', NULL, false, NULL, '2025-12-11 18:34:18.493702+02', NULL);
INSERT INTO public.notifications VALUES ('aa6abc90-9313-4975-aae1-cffa5040883c', '6c4746c9-75c7-4d40-bd3f-309dc6b5968a', '7a5e81b1-5777-425c-968a-ccac5f43fcae', 'low_stock', 'Low Stock Alert', 'Chicken Breast at Branch 2 is critically low (only 1.25 kg)', 'high', 'inventory', NULL, false, NULL, '2025-12-11 18:58:00.737473+02', NULL);
INSERT INTO public.notifications VALUES ('59efa077-d13c-4ef0-afa1-490edbcc0759', '0bd55267-11ed-4a77-aa37-8a990e94dd31', '0375f387-cb50-46ff-b41d-d60fe932addf', 'transfer_received', 'Transfer Completed', 'Transfer TRF-2024-003 has been received successfully', 'normal', 'transfer', NULL, false, NULL, '2025-12-11 18:58:00.739643+02', NULL);
INSERT INTO public.notifications VALUES ('9f02f53a-ea99-4845-b1bb-1ac9923f01d9', 'eff3e90d-dbf6-4536-baa5-1ff53e82c659', '393fdf52-1982-481b-a254-11ba0edc1d8b', 'system', 'Branch Return Received', 'Branch return BRT-2024-12-0006 has been received at Main Warehouse', 'normal', 'branch_return', NULL, false, NULL, '2025-12-11 18:58:00.741135+02', NULL);
INSERT INTO public.notifications VALUES ('6c2ace25-6167-43f1-85a6-0c579122e8ef', '576d7ede-d0bb-4e96-a09c-6665a7e5b2a2', '0375f387-cb50-46ff-b41d-d60fe932addf', 'pending_approval', 'Purchase Request Approved', 'Your purchase request PR-2024-12-0005 has been approved', 'normal', 'purchase_request', NULL, false, NULL, '2025-12-11 18:58:00.742427+02', NULL);


--
-- Data for Name: order_items; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.order_items VALUES ('cad85492-a5f0-4c23-adff-7f2bb8100079', 'e410256d-60f8-4784-aceb-3d0770564c45', '8e1087bc-750a-4d7b-9ead-412fcc731112', 2, 85.00, 0.00, 170.00, NULL, 'pending', '2025-12-11 17:24:12.341435+02');
INSERT INTO public.order_items VALUES ('a3f8abde-8b27-4be8-804e-71d8778e3916', 'e410256d-60f8-4784-aceb-3d0770564c45', '1fd35a9d-36ce-40c7-81be-3d0179b9edc9', 2, 15.00, 0.00, 30.00, NULL, 'pending', '2025-12-11 17:24:12.346853+02');
INSERT INTO public.order_items VALUES ('88314195-7b04-471a-8c25-8bf6d9ab1da7', '8bc80a38-e8b5-4286-8db9-07ce55c3b976', '8e1087bc-750a-4d7b-9ead-412fcc731112', 2, 85.00, 0.00, 170.00, NULL, 'delivered', '2025-12-11 17:36:51.243467+02');
INSERT INTO public.order_items VALUES ('3ae43241-601f-470b-b300-771b60191181', '8bc80a38-e8b5-4286-8db9-07ce55c3b976', '1fd35a9d-36ce-40c7-81be-3d0179b9edc9', 1, 15.00, 0.00, 15.00, NULL, 'delivered', '2025-12-11 17:36:51.249182+02');
INSERT INTO public.order_items VALUES ('51e94511-1c1e-49c7-9e6b-ce4c62ea89f3', '5396bdb2-cd18-4b0d-9e95-c85651ed6683', '8e1087bc-750a-4d7b-9ead-412fcc731112', 2, 85.00, 0.00, 170.00, NULL, 'preparing', '2025-12-11 17:36:51.25346+02');
INSERT INTO public.order_items VALUES ('4ae07255-828a-4efa-9fdf-f1a7b005282c', '0d99d355-7a2a-4e5d-b7ab-d55e8e09b712', '8e1087bc-750a-4d7b-9ead-412fcc731112', 1, 85.00, 0.00, 85.00, NULL, 'pending', '2025-12-11 17:36:51.258401+02');
INSERT INTO public.order_items VALUES ('b4418a07-5260-438f-acae-88ea623fc969', '0d99d355-7a2a-4e5d-b7ab-d55e8e09b712', '1fd35a9d-36ce-40c7-81be-3d0179b9edc9', 1, 15.00, 0.00, 15.00, NULL, 'pending', '2025-12-11 17:36:51.260676+02');
INSERT INTO public.order_items VALUES ('19f3e050-760c-4709-a61f-a4f21535a90e', 'b87e16c9-bf5d-49b3-8dc7-acfbb5514e6b', '8e1087bc-750a-4d7b-9ead-412fcc731112', 2, 85.00, 0.00, 170.00, NULL, 'delivered', '2025-12-11 17:36:51.345143+02');
INSERT INTO public.order_items VALUES ('7ce4cf31-cd24-4c6e-ab1f-3e32177c1c53', 'b87e16c9-bf5d-49b3-8dc7-acfbb5514e6b', '1fd35a9d-36ce-40c7-81be-3d0179b9edc9', 1, 15.00, 0.00, 15.00, NULL, 'delivered', '2025-12-11 17:36:51.347139+02');
INSERT INTO public.order_items VALUES ('7dde28da-6123-4d6e-b69f-118a3ae20e86', '822f3b4a-bfd8-44f4-975e-101b7f1ad49f', '8e1087bc-750a-4d7b-9ead-412fcc731112', 3, 85.00, 0.00, 255.00, 'Extra spicy', 'delivered', '2025-12-11 18:58:00.711799+02');


--
-- Data for Name: orders; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.orders VALUES ('e410256d-60f8-4784-aceb-3d0770564c45', 'ORD-2024-001', '393fdf52-1982-481b-a254-11ba0edc1d8b', 'dine_in', 'Ahmed Customer', '01200000001', 220.00, 30.80, 0.00, NULL, 250.80, 'cash', NULL, 'delivered', NULL, NULL, '53c3ad83-b852-4386-9a69-afdb98a4d9c9', 'aaee8a92-fce0-4a57-9569-852ad211d873', '2025-12-11 17:24:12.335894+02', '2025-12-11 17:24:12.34868+02', '2025-12-11 17:24:12.349784+02', '2025-12-11 17:24:12.351265+02', '2025-12-11 17:24:12.352074+02', '2025-12-11 17:24:12.352641+02', NULL, NULL, NULL, '2025-12-11 17:24:12.335894+02');
INSERT INTO public.orders VALUES ('8bc80a38-e8b5-4286-8db9-07ce55c3b976', 'ORD-2024-002', '393fdf52-1982-481b-a254-11ba0edc1d8b', 'dine_in', 'Mohamed Hassan', '01200000002', 205.00, 28.70, 0.00, NULL, 233.70, 'visa', NULL, 'delivered', NULL, NULL, '53c3ad83-b852-4386-9a69-afdb98a4d9c9', NULL, '2025-12-11 15:36:51.240171+02', '2025-12-11 15:36:51.240171+02', '2025-12-11 15:41:51.240171+02', NULL, '2025-12-11 16:06:51.240171+02', '2025-12-11 16:11:51.240171+02', NULL, NULL, NULL, '2025-12-11 17:36:51.240171+02');
INSERT INTO public.orders VALUES ('5396bdb2-cd18-4b0d-9e95-c85651ed6683', 'ORD-2024-003', '393fdf52-1982-481b-a254-11ba0edc1d8b', 'takeaway', 'Sara Ali', '01200000003', 170.00, 23.80, 0.00, NULL, 193.80, 'cash', NULL, 'preparing', NULL, NULL, '53c3ad83-b852-4386-9a69-afdb98a4d9c9', 'aaee8a92-fce0-4a57-9569-852ad211d873', '2025-12-11 17:06:51.25106+02', '2025-12-11 17:06:51.25106+02', '2025-12-11 17:08:51.25106+02', '2025-12-11 17:11:51.25106+02', NULL, NULL, NULL, NULL, NULL, '2025-12-11 17:36:51.25106+02');
INSERT INTO public.orders VALUES ('0d99d355-7a2a-4e5d-b7ab-d55e8e09b712', 'ORD-2024-004', '393fdf52-1982-481b-a254-11ba0edc1d8b', 'dine_in', 'Walk-in Customer', NULL, 100.00, 14.00, 0.00, NULL, 114.00, NULL, NULL, 'new', NULL, NULL, '53c3ad83-b852-4386-9a69-afdb98a4d9c9', NULL, '2025-12-11 17:36:51.256247+02', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2025-12-11 17:36:51.256247+02');
INSERT INTO public.orders VALUES ('090d0dde-4c2e-4dab-9ac7-6dcdc8b0bb6e', 'ORD-2024-005', '393fdf52-1982-481b-a254-11ba0edc1d8b', 'takeaway', 'Cancelled Customer', NULL, 85.00, 11.90, 0.00, NULL, 96.90, NULL, NULL, 'cancelled', NULL, NULL, '53c3ad83-b852-4386-9a69-afdb98a4d9c9', NULL, '2025-12-11 16:36:51.262659+02', NULL, NULL, NULL, NULL, NULL, '2025-12-11 16:41:51.262659+02', '53c3ad83-b852-4386-9a69-afdb98a4d9c9', 'Customer changed mind', '2025-12-11 17:36:51.262659+02');
INSERT INTO public.orders VALUES ('b87e16c9-bf5d-49b3-8dc7-acfbb5514e6b', 'ORD-2024-006', '7a5e81b1-5777-425c-968a-ccac5f43fcae', 'dine_in', 'Branch 2 Customer 1', NULL, 185.00, 25.90, 0.00, NULL, 210.90, 'cash', NULL, 'delivered', NULL, NULL, 'f34679bc-52fa-4b0f-9e95-0b7306af2468', NULL, '2025-12-11 14:36:51.342836+02', '2025-12-11 14:36:51.342836+02', '2025-12-11 14:41:51.342836+02', NULL, '2025-12-11 15:06:51.342836+02', '2025-12-11 15:11:51.342836+02', NULL, NULL, NULL, '2025-12-11 17:36:51.342836+02');
INSERT INTO public.orders VALUES ('822f3b4a-bfd8-44f4-975e-101b7f1ad49f', 'ORD-2024-007', '7a5e81b1-5777-425c-968a-ccac5f43fcae', 'dine_in', 'Ahmed Mahmoud', '01100000007', 255.00, 35.70, 0.00, NULL, 290.70, 'visa', NULL, 'delivered', NULL, NULL, 'f34679bc-52fa-4b0f-9e95-0b7306af2468', 'd99706bb-c485-4767-abdd-19ec90c448e8', '2025-12-11 18:58:00.709217+02', '2025-12-11 18:58:00.718391+02', '2025-12-11 18:58:00.719068+02', '2025-12-11 18:58:00.721301+02', '2025-12-11 18:58:00.722277+02', '2025-12-11 18:58:00.723259+02', NULL, NULL, NULL, '2025-12-11 18:58:00.709217+02');


--
-- Data for Name: purchase_order_items; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.purchase_order_items VALUES ('ae187504-6877-427b-afc9-32477d47b3cf', 'cc70cbfc-d282-4111-b5cd-d8e3b3992627', '431d3ad0-1b54-483a-8572-332da247a065', '471ba1fd-f13d-45a0-9223-a0634c419e37', 30.000, 120.00, 14.00, 0.00, 4104.00, 0.000, 'Cheese for pizza', '2025-12-11 18:22:37.845688+02');


--
-- Data for Name: purchase_orders; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.purchase_orders VALUES ('cc70cbfc-d282-4111-b5cd-d8e3b3992627', 'PO-2024-12-0001', '2025-12-10', '772f84e7-f23d-435b-85e8-1e58b58da371', '8ce501a0-a9cd-4b8c-b803-d189e6d2a348', '0375f387-cb50-46ff-b41d-d60fe932addf', 3600.00, 504.00, 0.00, 4104.00, 'pending', '2025-12-13', 'Dairy order', '576d7ede-d0bb-4e96-a09c-6665a7e5b2a2', '2025-12-11 18:22:37.839353+02', NULL, NULL, '2025-12-11 18:22:37.839353+02');


--
-- Data for Name: purchase_request_items; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.purchase_request_items VALUES ('f24d4f4b-5509-49a7-a494-0ff2024c8ab6', '14fd37c4-1539-454d-9360-59590b3f89b5', '9194f596-622a-46e7-bcd8-537b322083d2', '69d55ed6-d16b-464f-9fd0-bd93a92bf522', 100.000, NULL, NULL, 0.000, 78.00, 7800.00, 'Urgent - low stock', 'pending', '2025-12-11 18:22:37.782003+02');
INSERT INTO public.purchase_request_items VALUES ('5a514976-7bb2-4ee4-a45d-538dc2fa39c7', '14fd37c4-1539-454d-9360-59590b3f89b5', 'c4394116-cc14-4a0b-ba16-13189361429e', '69d55ed6-d16b-464f-9fd0-bd93a92bf522', 50.000, NULL, NULL, 0.000, 245.00, 12250.00, NULL, 'pending', '2025-12-11 18:22:37.810122+02');
INSERT INTO public.purchase_request_items VALUES ('1ddc4795-17c1-4d6d-92a6-4638c535ba8a', '14fd37c4-1539-454d-9360-59590b3f89b5', 'dd165c16-b9b3-476c-8309-47a08dfacca9', 'c34b5f9c-285f-4e3f-b35e-1acd0ae00247', 200.000, NULL, NULL, 0.000, 15.00, 3000.00, 'For salads', 'pending', '2025-12-11 18:22:37.812921+02');
INSERT INTO public.purchase_request_items VALUES ('471ba1fd-f13d-45a0-9223-a0634c419e37', '772f84e7-f23d-435b-85e8-1e58b58da371', '431d3ad0-1b54-483a-8572-332da247a065', '8ce501a0-a9cd-4b8c-b803-d189e6d2a348', 30.000, 30.000, NULL, 0.000, 120.00, 3600.00, 'For pizza', 'pending', '2025-12-11 18:22:37.82182+02');
INSERT INTO public.purchase_request_items VALUES ('b8477b22-34c9-4ba6-80ef-21c0468056b6', '62122030-14d4-400d-9c20-3fe54aed5479', '9194f596-622a-46e7-bcd8-537b322083d2', NULL, 20.000, NULL, NULL, 0.000, 78.00, 1560.00, 'Running low', 'pending', '2025-12-11 18:22:37.826536+02');
INSERT INTO public.purchase_request_items VALUES ('af0b0825-f860-43e6-958c-8dd6bd165099', '62122030-14d4-400d-9c20-3fe54aed5479', '99484384-95cd-475e-8c06-971ec03f75f7', NULL, 100.000, NULL, NULL, 0.000, 8.00, 800.00, 'Weekend rush expected', 'pending', '2025-12-11 18:22:37.828688+02');
INSERT INTO public.purchase_request_items VALUES ('abaa6879-2606-4bdc-81d1-051066ee126d', '8b03acb1-b70f-41db-b3dc-7bf44c083093', 'bfbff945-e1b4-4cfe-8fac-274fe629b3dd', NULL, 50.000, 50.000, 50.000, 50.000, 45.00, 2250.00, 'Delivered on time', 'received', '2025-12-11 18:22:37.834527+02');
INSERT INTO public.purchase_request_items VALUES ('d9bd48f2-e8e1-4596-aef7-70a2412bc23a', '8b03acb1-b70f-41db-b3dc-7bf44c083093', '718d6492-8a33-409f-8939-373649df220a', NULL, 200.000, 200.000, 200.000, 200.000, 35.00, 7000.00, NULL, 'received', '2025-12-11 18:22:37.83716+02');
INSERT INTO public.purchase_request_items VALUES ('dd74ca42-975f-4fdb-bb16-847ef5baafed', '1b64043f-0308-44e7-821d-43c901f58b94', '9194f596-622a-46e7-bcd8-537b322083d2', '69d55ed6-d16b-464f-9fd0-bd93a92bf522', 100.000, NULL, NULL, 0.000, 78.00, NULL, 'Weekly chicken order', 'pending', '2025-12-11 18:58:00.699152+02');
INSERT INTO public.purchase_request_items VALUES ('ade3fda2-e4a4-4f77-834d-34ca2d075abd', '1b64043f-0308-44e7-821d-43c901f58b94', 'c4394116-cc14-4a0b-ba16-13189361429e', '69d55ed6-d16b-464f-9fd0-bd93a92bf522', 50.000, NULL, NULL, 0.000, 245.00, NULL, 'Beef for weekend', 'pending', '2025-12-11 18:58:00.705743+02');


--
-- Data for Name: purchase_requests; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.purchase_requests VALUES ('14fd37c4-1539-454d-9360-59590b3f89b5', 'PR-2024-12-0001', '2025-12-11', '0375f387-cb50-46ff-b41d-d60fe932addf', 'pending', 1, 'Weekly stock replenishment', 3, 350.000, 23050.00, '576d7ede-d0bb-4e96-a09c-6665a7e5b2a2', '2025-12-11 18:22:37.773879+02', NULL, NULL, NULL, NULL, NULL, '2025-12-11 18:22:37.773879+02', '2025-12-11 18:22:37.812921+02');
INSERT INTO public.purchase_requests VALUES ('772f84e7-f23d-435b-85e8-1e58b58da371', 'PR-2024-12-0002', '2025-12-09', '0375f387-cb50-46ff-b41d-d60fe932addf', 'approved', 2, 'Dairy products needed', 1, 30.000, 3600.00, '576d7ede-d0bb-4e96-a09c-6665a7e5b2a2', '2025-12-11 18:22:37.815044+02', 'a0ada47f-f5ff-43b3-8c3e-68492f870fc1', '2025-12-10 18:22:37.815044+02', NULL, NULL, NULL, '2025-12-11 18:22:37.815044+02', '2025-12-11 18:22:37.82182+02');
INSERT INTO public.purchase_requests VALUES ('62122030-14d4-400d-9c20-3fe54aed5479', 'PR-2024-12-0003', '2025-12-11', '393fdf52-1982-481b-a254-11ba0edc1d8b', 'draft', 0, 'Branch 1 weekly needs', 2, 120.000, 2360.00, 'eff3e90d-dbf6-4536-baa5-1ff53e82c659', '2025-12-11 18:22:37.824491+02', NULL, NULL, NULL, NULL, NULL, '2025-12-11 18:22:37.824491+02', '2025-12-11 18:22:37.828688+02');
INSERT INTO public.purchase_requests VALUES ('8b03acb1-b70f-41db-b3dc-7bf44c083093', 'PR-2024-12-0004', '2025-12-06', '0375f387-cb50-46ff-b41d-d60fe932addf', 'completed', 1, 'Oils and grains', 2, 250.000, 9250.00, '576d7ede-d0bb-4e96-a09c-6665a7e5b2a2', '2025-12-11 18:22:37.831431+02', 'a0ada47f-f5ff-43b3-8c3e-68492f870fc1', '2025-12-07 18:22:37.831431+02', NULL, NULL, NULL, '2025-12-11 18:22:37.831431+02', '2025-12-11 18:22:37.83716+02');
INSERT INTO public.purchase_requests VALUES ('1b64043f-0308-44e7-821d-43c901f58b94', 'PR-2024-12-0005', '2025-12-11', '0375f387-cb50-46ff-b41d-d60fe932addf', 'approved', 2, 'Urgent items needed for next week', 2, 150.000, 0.00, '576d7ede-d0bb-4e96-a09c-6665a7e5b2a2', '2025-12-11 18:58:00.695659+02', 'a0ada47f-f5ff-43b3-8c3e-68492f870fc1', '2025-12-11 18:58:00.708427+02', NULL, NULL, NULL, '2025-12-11 18:58:00.695659+02', '2025-12-11 18:58:00.705743+02');


--
-- Data for Name: roles; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.roles VALUES ('989aa75b-61a1-44c4-9279-fd183df84979', 'admin', 'Admin', 'Full system access', '{"all": true}', true, '2025-12-11 17:16:37.096312+02', '2025-12-11 17:16:37.096312+02');
INSERT INTO public.roles VALUES ('fda5287b-f3a4-44f4-9d29-83441895610f', 'warehouse_manager', 'Warehouse Manager', 'Warehouse and supplier management', '{"inventory": true, "suppliers": true}', true, '2025-12-11 17:16:37.096312+02', '2025-12-11 17:16:37.096312+02');
INSERT INTO public.roles VALUES ('2263c054-7645-48dd-b4a9-c536563ed8a7', 'branch_supervisor', 'Branch Supervisor', 'Branch operations management', '{"branch_inventory": true}', true, '2025-12-11 17:16:37.096312+02', '2025-12-11 17:16:37.096312+02');
INSERT INTO public.roles VALUES ('5f43ee8f-f827-447f-b69a-7c60c6e41f42', 'chef', 'Chef', 'Kitchen operations', '{"kitchen_pos": true}', true, '2025-12-11 17:16:37.096312+02', '2025-12-11 17:16:37.096312+02');
INSERT INTO public.roles VALUES ('a3658e54-8797-4730-a228-8d233bfbaa9c', 'cashier', 'Cashier', 'POS and order management', '{"cashier_pos": true}', true, '2025-12-11 17:16:37.096312+02', '2025-12-11 17:16:37.096312+02');
INSERT INTO public.roles VALUES ('cd5f1c71-218e-4d28-b501-4d84a85367f6', 'purchase_manager', 'Purchase Manager', 'Manages all purchase requests and supplier orders', '{"purchases": true, "suppliers": true, "inventory_view": true}', true, '2025-12-11 18:21:00.303631+02', '2025-12-11 18:21:00.303631+02');


--
-- Data for Name: supplier_items; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.supplier_items VALUES ('90c729f8-961c-4a34-9e07-6ecc6995fa28', '69d55ed6-d16b-464f-9fd0-bd93a92bf522', '9194f596-622a-46e7-bcd8-537b322083d2', 'SM-001', 78.00, 10.000, 1, true, '2025-12-11 17:25:42.978509+02', '2025-12-11 17:25:42.978509+02');
INSERT INTO public.supplier_items VALUES ('7f338e94-0c1e-4c5c-9680-97867cf80ddd', '69d55ed6-d16b-464f-9fd0-bd93a92bf522', 'c4394116-cc14-4a0b-ba16-13189361429e', 'SM-002', 245.00, 5.000, 1, true, '2025-12-11 17:25:42.983914+02', '2025-12-11 17:25:42.983914+02');
INSERT INTO public.supplier_items VALUES ('89a98d88-361d-4037-84af-c8c37ff83e1a', 'c34b5f9c-285f-4e3f-b35e-1acd0ae00247', 'dd165c16-b9b3-476c-8309-47a08dfacca9', 'GF-001', 14.00, 20.000, 1, true, '2025-12-11 17:25:42.985887+02', '2025-12-11 17:25:42.985887+02');
INSERT INTO public.supplier_items VALUES ('62956f9e-2300-4387-88bf-6edf2a53c123', 'c34b5f9c-285f-4e3f-b35e-1acd0ae00247', 'ad18601e-1e61-4ad9-8b66-1b8e1b9f0932', 'GF-002', 9.00, 30.000, 1, true, '2025-12-11 17:25:42.987642+02', '2025-12-11 17:25:42.987642+02');


--
-- Data for Name: supplier_payments; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.supplier_payments VALUES ('bf22a5c0-9cb7-4090-b4e9-f1f9582877be', 'PAY-2024-001', '69d55ed6-d16b-464f-9fd0-bd93a92bf522', '381c4da0-06e3-4058-9974-1f337b74cd60', 3000.00, 'bank_transfer', 'TRX-123456', NULL, '2025-12-11', 'Partial payment', 'a0ada47f-f5ff-43b3-8c3e-68492f870fc1', '2025-12-11 17:24:12.309805+02');
INSERT INTO public.supplier_payments VALUES ('342a04a9-e1a1-4011-859a-da2dbcccad69', 'PAY-2024-002', '69d55ed6-d16b-464f-9fd0-bd93a92bf522', NULL, 5000.00, 'bank_transfer', 'TRX-789012', 'CIB Bank', '2025-12-11', 'Second payment', 'a0ada47f-f5ff-43b3-8c3e-68492f870fc1', '2025-12-11 17:36:51.181007+02');
INSERT INTO public.supplier_payments VALUES ('de15346b-16f2-4b98-bea1-c08571f5a2d1', 'PAY-2024-003', '69d55ed6-d16b-464f-9fd0-bd93a92bf522', NULL, 2000.00, 'cash', NULL, NULL, '2025-12-11', 'Cash payment', 'a0ada47f-f5ff-43b3-8c3e-68492f870fc1', '2025-12-11 17:36:51.185293+02');
INSERT INTO public.supplier_payments VALUES ('2c76d61d-b1b2-485c-97eb-d6a124dd4627', 'PAY-2024-004', '69d55ed6-d16b-464f-9fd0-bd93a92bf522', NULL, 1500.00, 'check', 'CHK-123456', NULL, '2025-12-18', 'Post-dated check', 'a0ada47f-f5ff-43b3-8c3e-68492f870fc1', '2025-12-11 17:36:51.187811+02');


--
-- Data for Name: supplier_returns; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.supplier_returns VALUES ('5a16a0e6-7881-4ff6-8819-0cf718df5d39', 'RET-2024-001', '381c4da0-06e3-4058-9974-1f337b74cd60', '69d55ed6-d16b-464f-9fd0-bd93a92bf522', '9194f596-622a-46e7-bcd8-537b322083d2', 5.000, 78.00, 390.00, 'Defective quality', 'Chicken had bad smell', NULL, 'approved', '0bd55267-11ed-4a77-aa37-8a990e94dd31', '2025-12-11 17:25:43.056406+02', 'a0ada47f-f5ff-43b3-8c3e-68492f870fc1', '2025-12-11 17:25:43.056406+02', NULL, NULL, NULL, NULL, NULL, '2025-12-11 17:25:43.056406+02', '2025-12-11 17:25:43.056406+02');
INSERT INTO public.supplier_returns VALUES ('64ab181b-7d01-49b4-86e7-1a91357cc3b2', 'RET-2024-003', '52674029-f781-429a-a557-d5a4fc81644d', 'c34b5f9c-285f-4e3f-b35e-1acd0ae00247', 'dd165c16-b9b3-476c-8309-47a08dfacca9', 15.000, 14.00, 210.00, 'Wrong variety delivered', 'Ordered Roma tomatoes, received regular', NULL, 'pending', '0bd55267-11ed-4a77-aa37-8a990e94dd31', '2025-12-11 17:36:51.230162+02', NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2025-12-11 17:36:51.230162+02', '2025-12-11 17:36:51.230162+02');
INSERT INTO public.supplier_returns VALUES ('03d8ad74-b490-4eae-b053-34bd352a0349', 'RET-2024-002', '09625919-731b-4c97-9039-0ef4354bfbd9', '69d55ed6-d16b-464f-9fd0-bd93a92bf522', '9194f596-622a-46e7-bcd8-537b322083d2', 10.000, 78.00, 780.00, 'Quality below standard', 'Chicken color was off', NULL, 'approved', '0bd55267-11ed-4a77-aa37-8a990e94dd31', '2025-12-11 17:36:51.226736+02', 'a0ada47f-f5ff-43b3-8c3e-68492f870fc1', '2025-12-11 17:36:51.232753+02', NULL, NULL, NULL, NULL, NULL, '2025-12-11 17:36:51.226736+02', '2025-12-11 17:36:51.226736+02');


--
-- Data for Name: suppliers; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.suppliers VALUES ('c34b5f9c-285f-4e3f-b35e-1acd0ae00247', 'SUP002', 'Green Farms', 'Ø§Ù„Ù…Ø²Ø§Ø±Ø¹ Ø§Ù„Ø®Ø¶Ø±Ø§Ø¡', 'Ali Mohamed', '01100000002', NULL, 'farms@supplier.com', '456 Agriculture Zone', 'Giza', NULL, NULL, 'cash', 0.00, 0, 0.00, 'active', NULL, NULL, '2025-12-11 17:24:12.233958+02', '2025-12-11 17:24:12.233958+02', NULL);
INSERT INTO public.suppliers VALUES ('fe2193ad-2093-4e0c-9031-31d3592cad99', 'SUP004', 'Beverages Distributor', 'Ù…ÙˆØ²Ø¹ Ø§Ù„Ù…Ø´Ø±ÙˆØ¨Ø§Øª', 'Omar Khaled', '01100000004', NULL, 'drinks@supplier.com', '321 Commercial St', 'Cairo', NULL, NULL, 'credit', 20000.00, 7, 0.00, 'active', NULL, NULL, '2025-12-11 17:24:12.233958+02', '2025-12-11 17:24:12.233958+02', NULL);
INSERT INTO public.suppliers VALUES ('69d55ed6-d16b-464f-9fd0-bd93a92bf522', 'SUP001', 'Fresh Meat Co.', 'Ø´Ø±ÙƒØ© Ø§Ù„Ù„Ø­ÙˆÙ… Ø§Ù„Ø·Ø§Ø²Ø¬Ø©', 'Mahmoud Hassan', '01100000001', NULL, 'meat@supplier.com', '123 Industrial Area', 'Cairo', NULL, NULL, 'credit', 50000.00, 30, 2150.00, 'active', NULL, NULL, '2025-12-11 17:24:12.233958+02', '2025-12-11 17:24:12.233958+02', NULL);
INSERT INTO public.suppliers VALUES ('8ce501a0-a9cd-4b8c-b803-d189e6d2a348', 'SUP003', 'Dairy Products Ltd', 'Ù…Ù†ØªØ¬Ø§Øª Ø§Ù„Ø£Ù„Ø¨Ø§Ù†', 'Fatma Ahmed', '01100000003', NULL, 'dairy@supplier.com', '789 Food District', 'Alexandria', NULL, NULL, 'credit', 30000.00, 15, 2736.00, 'active', NULL, NULL, '2025-12-11 17:24:12.233958+02', '2025-12-11 17:24:12.233958+02', NULL);
INSERT INTO public.suppliers VALUES ('4e25b7f4-8979-4212-bf2d-8c7dc9baad72', 'SUP005', 'Spices World', NULL, 'Hassan Ibrahim', '01555000001', NULL, 'spices@world.com', 'Spices Market, Cairo', NULL, NULL, NULL, 'cash', 25000.00, 0, 0.00, 'active', NULL, NULL, '2025-12-11 18:58:10.698303+02', '2025-12-11 18:58:10.698303+02', 'a0ada47f-f5ff-43b3-8c3e-68492f870fc1');


--
-- Data for Name: supplies; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.supplies VALUES ('52674029-f781-429a-a557-d5a4fc81644d', 'SUP-2024-002', 'c34b5f9c-285f-4e3f-b35e-1acd0ae00247', '0375f387-cb50-46ff-b41d-d60fe932addf', 'INV-002', '2025-12-11', 1000.00, 140.00, 0.00, 1140.00, 'cash', 'paid', 1140.00, NULL, NULL, '0bd55267-11ed-4a77-aa37-8a990e94dd31', '2025-12-11 17:24:12.258269+02', NULL, NULL, '2025-12-11 17:24:12.258269+02', '2025-12-11 17:24:12.258269+02');
INSERT INTO public.supplies VALUES ('381c4da0-06e3-4058-9974-1f337b74cd60', 'SUP-2024-001', '69d55ed6-d16b-464f-9fd0-bd93a92bf522', '0375f387-cb50-46ff-b41d-d60fe932addf', 'INV-001', '2025-12-11', 5000.00, 700.00, 0.00, 5700.00, 'credit', 'partial', 3000.00, NULL, NULL, '0bd55267-11ed-4a77-aa37-8a990e94dd31', '2025-12-11 17:24:12.248998+02', NULL, NULL, '2025-12-11 17:24:12.248998+02', '2025-12-11 17:24:12.248998+02');
INSERT INTO public.supplies VALUES ('09625919-731b-4c97-9039-0ef4354bfbd9', 'SUP-2024-003', '69d55ed6-d16b-464f-9fd0-bd93a92bf522', '0375f387-cb50-46ff-b41d-d60fe932addf', 'INV-003', '2025-12-11', 8000.00, 1120.00, 0.00, 9120.00, 'credit', 'pending', 0.00, NULL, NULL, '0bd55267-11ed-4a77-aa37-8a990e94dd31', '2025-12-11 17:36:51.140081+02', NULL, NULL, '2025-12-11 17:36:51.140081+02', '2025-12-11 17:36:51.140081+02');
INSERT INTO public.supplies VALUES ('0738e999-4886-4ee3-bed4-b774828030a0', 'SUP-2024-004', '8ce501a0-a9cd-4b8c-b803-d189e6d2a348', '0375f387-cb50-46ff-b41d-d60fe932addf', 'INV-004', '2025-12-11', 2400.00, 336.00, 0.00, 2736.00, 'credit', 'pending', 0.00, NULL, NULL, '0bd55267-11ed-4a77-aa37-8a990e94dd31', '2025-12-11 17:36:51.387666+02', NULL, NULL, '2025-12-11 17:36:51.387666+02', '2025-12-11 17:36:51.387666+02');


--
-- Data for Name: supply_items; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.supply_items VALUES ('d386a62c-494f-4dc0-ae8a-880785acb078', '381c4da0-06e3-4058-9974-1f337b74cd60', '9194f596-622a-46e7-bcd8-537b322083d2', 30.000, 30.000, 78.00, 0.00, 14.00, 2668.80, 'BATCH-001', NULL, '2025-12-16', NULL, '2025-12-11 17:25:42.990151+02');
INSERT INTO public.supply_items VALUES ('0e210d37-0584-4d08-bb90-58ccde50ae4b', '381c4da0-06e3-4058-9974-1f337b74cd60', 'c4394116-cc14-4a0b-ba16-13189361429e', 10.000, 10.000, 245.00, 0.00, 14.00, 2793.00, 'BATCH-002', NULL, '2025-12-14', NULL, '2025-12-11 17:25:42.995895+02');
INSERT INTO public.supply_items VALUES ('3679d902-7234-4e8f-aba4-80345961ec11', '52674029-f781-429a-a557-d5a4fc81644d', 'dd165c16-b9b3-476c-8309-47a08dfacca9', 50.000, 50.000, 14.00, 0.00, 14.00, 798.00, 'BATCH-003', NULL, '2025-12-18', NULL, '2025-12-11 17:25:42.997951+02');
INSERT INTO public.supply_items VALUES ('8be8d210-c07b-475c-95a5-0e7e7b6eed6f', '52674029-f781-429a-a557-d5a4fc81644d', 'ad18601e-1e61-4ad9-8b66-1b8e1b9f0932', 40.000, 40.000, 9.00, 0.00, 14.00, 410.40, 'BATCH-004', NULL, '2025-12-25', NULL, '2025-12-11 17:25:42.999854+02');
INSERT INTO public.supply_items VALUES ('1115f7da-d9ea-4dd5-b46b-8005336e4b53', '09625919-731b-4c97-9039-0ef4354bfbd9', '9194f596-622a-46e7-bcd8-537b322083d2', 50.000, 50.000, 78.00, 0.00, 14.00, 4446.00, 'BATCH-005', NULL, '2025-12-18', NULL, '2025-12-11 17:36:51.153561+02');
INSERT INTO public.supply_items VALUES ('76f579b7-93b1-4f16-985d-70db7fd63fba', '09625919-731b-4c97-9039-0ef4354bfbd9', 'c4394116-cc14-4a0b-ba16-13189361429e', 20.000, 20.000, 245.00, 0.00, 14.00, 5586.00, 'BATCH-006', NULL, '2025-12-16', NULL, '2025-12-11 17:36:51.159676+02');
INSERT INTO public.supply_items VALUES ('04f7aacd-db11-4f1c-a505-1d8990081e6b', '0738e999-4886-4ee3-bed4-b774828030a0', '431d3ad0-1b54-483a-8572-332da247a065', 20.000, 20.000, 120.00, 0.00, 14.00, 2736.00, 'BATCH-007', NULL, '2026-01-10', NULL, '2025-12-11 17:36:51.389947+02');


--
-- Data for Name: system_settings; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.system_settings VALUES ('cef7f94e-5fa2-4b65-ba43-7a71b9243ead', 'company_name', 'Restaurant Name', 'string', 'Company name', false, NULL, '2025-12-11 17:07:15.618745+02');
INSERT INTO public.system_settings VALUES ('41ac23e4-7030-48de-8ce9-2959c2ba2fef', 'company_name_ar', 'Ø§Ø³Ù… Ø§Ù„Ù…Ø·Ø¹Ù…', 'string', 'Company name in Arabic', false, NULL, '2025-12-11 17:07:15.618745+02');
INSERT INTO public.system_settings VALUES ('e0978960-0007-4b83-a87f-046448de66f3', 'currency', 'EGP', 'string', 'Currency', false, NULL, '2025-12-11 17:07:15.618745+02');
INSERT INTO public.system_settings VALUES ('8e6bb7f3-139e-4e54-bcd1-14a9a9d88f64', 'tax_rate', '14', 'number', 'Tax rate percentage', false, NULL, '2025-12-11 17:07:15.618745+02');
INSERT INTO public.system_settings VALUES ('37d85851-8701-4cea-86d2-d25009bf8372', 'low_stock_threshold_days', '7', 'number', 'Days before low stock alert', false, NULL, '2025-12-11 17:07:15.618745+02');
INSERT INTO public.system_settings VALUES ('5be1e0f7-c4aa-4bde-817a-41471dd33c62', 'expiry_warning_days', '30', 'number', 'Days before expiry warning', false, NULL, '2025-12-11 17:07:15.618745+02');
INSERT INTO public.system_settings VALUES ('4712aa46-8101-4a3e-8db9-98a59624698d', 'order_number_prefix', 'ORD', 'string', 'Order number prefix', false, NULL, '2025-12-11 17:07:15.618745+02');
INSERT INTO public.system_settings VALUES ('a045153b-5e81-4218-8f4c-be1abde59b30', 'supply_number_prefix', 'SUP', 'string', 'Supply number prefix', false, NULL, '2025-12-11 17:07:15.618745+02');
INSERT INTO public.system_settings VALUES ('cd8dc49a-b1f8-4b93-be2b-991c6da2df83', 'transfer_number_prefix', 'TRF', 'string', 'Transfer number prefix', false, NULL, '2025-12-11 17:07:15.618745+02');
INSERT INTO public.system_settings VALUES ('6db4c313-0e3c-48ec-a8a4-858c60a2a663', 'damage_number_prefix', 'DMG', 'string', 'Damage number prefix', false, NULL, '2025-12-11 17:07:15.618745+02');
INSERT INTO public.system_settings VALUES ('1327122f-4c38-4318-8219-38748797422f', 'return_number_prefix', 'RET', 'string', 'Return number prefix', false, NULL, '2025-12-11 17:07:15.618745+02');
INSERT INTO public.system_settings VALUES ('5b89859c-43ae-4c4d-9d35-23f710eee02b', 'purchase_request_prefix', 'PR', 'string', 'Purchase request number prefix', false, NULL, '2025-12-11 18:21:00.373059+02');
INSERT INTO public.system_settings VALUES ('59cae260-d49f-4d82-842e-2cf79cac7dc7', 'purchase_order_prefix', 'PO', 'string', 'Purchase order number prefix', false, NULL, '2025-12-11 18:21:00.373059+02');
INSERT INTO public.system_settings VALUES ('89b76132-2961-4d32-96c4-582b3de4dbfa', 'branch_return_prefix', 'BRT', 'string', 'Branch return number prefix', false, NULL, '2025-12-11 18:28:13.483943+02');


--
-- Data for Name: transfer_items; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.transfer_items VALUES ('ccb377b8-e87c-4694-b8ea-09c9096d69dd', 'eee5bdc4-5c73-4772-9d87-57c8bc28041e', '9194f596-622a-46e7-bcd8-537b322083d2', 10.000, 10.000, 10.000, 10.000, 'Urgent need', '2025-12-11 17:25:43.035584+02');
INSERT INTO public.transfer_items VALUES ('847fe7ff-8574-496c-97a4-2fe8f9d68fbb', 'eee5bdc4-5c73-4772-9d87-57c8bc28041e', 'c4394116-cc14-4a0b-ba16-13189361429e', 5.000, 5.000, 5.000, 5.000, NULL, '2025-12-11 17:25:43.041201+02');
INSERT INTO public.transfer_items VALUES ('11fff82e-a53a-44c6-b768-2c6830c58247', 'eee5bdc4-5c73-4772-9d87-57c8bc28041e', 'dd165c16-b9b3-476c-8309-47a08dfacca9', 20.000, 20.000, 20.000, 20.000, NULL, '2025-12-11 17:25:43.043089+02');
INSERT INTO public.transfer_items VALUES ('31bb32aa-446d-4505-b75c-d6489b4864e9', 'c6979441-1577-4090-9874-3761a95c9d42', '9194f596-622a-46e7-bcd8-537b322083d2', 30.000, 25.000, 25.000, NULL, 'Need for weekend rush', '2025-12-11 17:36:51.192879+02');
INSERT INTO public.transfer_items VALUES ('964e56d7-810e-47e7-b645-824d454bd9aa', 'c6979441-1577-4090-9874-3761a95c9d42', 'c4394116-cc14-4a0b-ba16-13189361429e', 15.000, 10.000, 10.000, NULL, NULL, '2025-12-11 17:36:51.19631+02');
INSERT INTO public.transfer_items VALUES ('aa3beee0-15ce-43f3-87a2-1c2d7db68004', 'c6979441-1577-4090-9874-3761a95c9d42', 'dd165c16-b9b3-476c-8309-47a08dfacca9', 100.000, 30.000, 30.000, NULL, 'For salads', '2025-12-11 17:36:51.198022+02');
INSERT INTO public.transfer_items VALUES ('646fd18f-b24a-4b3e-abe5-082aee401b52', 'c6979441-1577-4090-9874-3761a95c9d42', '718d6492-8a33-409f-8939-373649df220a', 50.000, 50.000, 50.000, NULL, NULL, '2025-12-11 17:36:51.200021+02');
INSERT INTO public.transfer_items VALUES ('95777a4f-5d28-4c75-949e-f13e75cef048', '14c9e910-1b7e-4d26-890a-b132505bd818', '9194f596-622a-46e7-bcd8-537b322083d2', 20.000, 20.000, 20.000, 20.000, 'Running low', '2025-12-11 18:58:00.629118+02');
INSERT INTO public.transfer_items VALUES ('beea79da-6812-40d9-b3a7-6e6cef5092af', '14c9e910-1b7e-4d26-890a-b132505bd818', 'c4394116-cc14-4a0b-ba16-13189361429e', 10.000, 10.000, 10.000, 10.000, 'Weekend prep', '2025-12-11 18:58:00.634729+02');
INSERT INTO public.transfer_items VALUES ('8d318636-e4db-4b2c-92eb-31b91dbe8f45', '14c9e910-1b7e-4d26-890a-b132505bd818', '718d6492-8a33-409f-8939-373649df220a', 50.000, 40.000, 40.000, 40.000, 'High demand', '2025-12-11 18:58:00.63769+02');


--
-- Data for Name: transfers; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.transfers VALUES ('eee5bdc4-5c73-4772-9d87-57c8bc28041e', 'TRF-2024-001', '0375f387-cb50-46ff-b41d-d60fe932addf', '393fdf52-1982-481b-a254-11ba0edc1d8b', 'received', 1, 'Weekly supply for Branch 1', 'eff3e90d-dbf6-4536-baa5-1ff53e82c659', '2025-12-11 17:24:12.272422+02', '0bd55267-11ed-4a77-aa37-8a990e94dd31', '2025-12-11 17:24:12.280604+02', NULL, NULL, NULL, '2025-12-11 17:24:12.283842+02', 'eff3e90d-dbf6-4536-baa5-1ff53e82c659', '2025-12-11 17:24:12.283842+02', '2025-12-11 17:24:12.272422+02', '2025-12-11 17:24:12.272422+02');
INSERT INTO public.transfers VALUES ('c6979441-1577-4090-9874-3761a95c9d42', 'TRF-2024-002', '0375f387-cb50-46ff-b41d-d60fe932addf', '7a5e81b1-5777-425c-968a-ccac5f43fcae', 'approved', 2, 'Urgent request for Branch 2', 'a0ada47f-f5ff-43b3-8c3e-68492f870fc1', '2025-12-11 17:36:51.190023+02', '0bd55267-11ed-4a77-aa37-8a990e94dd31', '2025-12-11 17:36:51.202012+02', NULL, NULL, NULL, NULL, NULL, NULL, '2025-12-11 17:36:51.190023+02', '2025-12-11 17:36:51.190023+02');
INSERT INTO public.transfers VALUES ('14c9e910-1b7e-4d26-890a-b132505bd818', 'TRF-2024-003', '0375f387-cb50-46ff-b41d-d60fe932addf', '393fdf52-1982-481b-a254-11ba0edc1d8b', 'received', 1, 'Weekly stock replenishment for Branch 1', 'eff3e90d-dbf6-4536-baa5-1ff53e82c659', '2025-12-11 18:58:00.626028+02', '0bd55267-11ed-4a77-aa37-8a990e94dd31', '2025-12-11 18:58:00.64007+02', NULL, NULL, NULL, NULL, 'eff3e90d-dbf6-4536-baa5-1ff53e82c659', '2025-12-11 18:58:00.645442+02', '2025-12-11 18:58:00.626028+02', '2025-12-11 18:58:00.626028+02');


--
-- Data for Name: units; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.units VALUES ('e6672057-ac2c-4cca-b054-89fc377fdb5c', 'KG', 'Kilogram', 'ÙƒÙŠÙ„ÙˆØ¬Ø±Ø§Ù…', true, '2025-12-11 17:04:13.277406+02');
INSERT INTO public.units VALUES ('69108ae3-bdae-4893-849e-98e9cd90f2d5', 'G', 'Gram', 'Ø¬Ø±Ø§Ù…', true, '2025-12-11 17:04:13.277406+02');
INSERT INTO public.units VALUES ('876adef7-7f0e-41ec-b42c-aa629728c37e', 'L', 'Liter', 'Ù„ØªØ±', true, '2025-12-11 17:04:13.277406+02');
INSERT INTO public.units VALUES ('abe42089-4c22-4f54-b0bf-b5ab66530560', 'ML', 'Milliliter', 'Ù…Ù„Ù„ÙŠ Ù„ØªØ±', true, '2025-12-11 17:04:13.277406+02');
INSERT INTO public.units VALUES ('a3a43a13-f3c7-4517-a1ff-702c662e49da', 'PC', 'Piece', 'Ù‚Ø·Ø¹Ø©', true, '2025-12-11 17:04:13.277406+02');
INSERT INTO public.units VALUES ('71a42258-6e5f-479f-9b85-4a1ffb19a3d7', 'BOX', 'Box', 'Ø¹Ù„Ø¨Ø©', true, '2025-12-11 17:04:13.277406+02');
INSERT INTO public.units VALUES ('4a515bc9-3075-454b-a9fc-e83cbd66333c', 'PKT', 'Packet', 'Ø¨Ø§ÙƒØª', true, '2025-12-11 17:04:13.277406+02');
INSERT INTO public.units VALUES ('44d9b3a5-3cff-4f4d-a96c-dc45bf4eed07', 'BTL', 'Bottle', 'Ø²Ø¬Ø§Ø¬Ø©', true, '2025-12-11 17:04:13.277406+02');
INSERT INTO public.units VALUES ('aefb866b-86e5-4360-878a-67324927e4f8', 'CAN', 'Can', 'Ø¹Ù„Ø¨Ø© Ù…Ø¹Ø¯Ù†ÙŠØ©', true, '2025-12-11 17:04:13.277406+02');
INSERT INTO public.units VALUES ('a663d89e-3612-4b59-a0b4-5618286ef040', 'BAG', 'Bag', 'ÙƒÙŠØ³', true, '2025-12-11 17:04:13.277406+02');
INSERT INTO public.units VALUES ('ffad80ba-86e9-4a86-bee6-07a033a869e7', 'CTN', 'Carton', 'ÙƒØ±ØªÙˆÙ†Ø©', true, '2025-12-11 17:04:13.277406+02');
INSERT INTO public.units VALUES ('682756b2-72be-42b2-80d4-97fdfd224271', 'DOZ', 'Dozen', 'Ø¯Ø±Ø²Ù†', true, '2025-12-11 17:04:13.277406+02');


--
-- Data for Name: user_sessions; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.user_sessions VALUES ('e4c32189-ffe5-4415-b241-b003c751c611', 'a0ada47f-f5ff-43b3-8c3e-68492f870fc1', 'hash_token_abc123', 'Chrome on Windows', '192.168.1.100', true, '2025-12-11 17:24:12.38388+02', '2025-12-12 17:24:12.38388+02', '2025-12-11 17:24:12.38388+02');
INSERT INTO public.user_sessions VALUES ('206006b2-b03d-4151-8944-79cb703b41d5', '53c3ad83-b852-4386-9a69-afdb98a4d9c9', 'hash_token_def456', 'Firefox on Windows', '192.168.1.101', true, '2025-12-11 17:24:12.387771+02', '2025-12-12 17:24:12.387771+02', '2025-12-11 17:24:12.387771+02');
INSERT INTO public.user_sessions VALUES ('bcb98256-5245-4ecb-a5ea-9f8cbf9e4975', '0bd55267-11ed-4a77-aa37-8a990e94dd31', 'hash_token_ghi789', 'Chrome on Windows', '192.168.1.102', true, '2025-12-11 17:36:51.397222+02', '2025-12-12 17:36:51.397222+02', '2025-12-11 17:36:51.397222+02');
INSERT INTO public.user_sessions VALUES ('ec262268-d44f-46b5-a7ca-85fcc1c6c4ff', 'eff3e90d-dbf6-4536-baa5-1ff53e82c659', 'hash_token_jkl012', 'Safari on iPad', '192.168.1.103', true, '2025-12-11 17:36:51.400579+02', '2025-12-12 17:36:51.400579+02', '2025-12-11 17:36:51.400579+02');
INSERT INTO public.user_sessions VALUES ('9eb032b2-13e7-444e-8913-8c2efdecd2d6', 'aaee8a92-fce0-4a57-9569-852ad211d873', 'hash_token_mno345', 'Chrome on Android', '192.168.1.104', true, '2025-12-11 17:36:51.40243+02', '2025-12-12 17:36:51.40243+02', '2025-12-11 17:36:51.40243+02');
INSERT INTO public.user_sessions VALUES ('cd67f3d6-1e29-46f9-bcc0-fc1c9c182620', 'a0ada47f-f5ff-43b3-8c3e-68492f870fc1', 'hash_token_old001', 'Firefox on Windows', '192.168.1.50', false, '2025-12-11 17:36:51.404148+02', '2025-12-09 17:36:51.404148+02', '2025-12-08 17:36:51.404148+02');
INSERT INTO public.user_sessions VALUES ('dccb9692-b169-4a4e-bad2-307fd223b199', '53c3ad83-b852-4386-9a69-afdb98a4d9c9', 'hash_token_old002', 'Chrome on Mac', '192.168.1.51', false, '2025-12-11 17:36:51.406065+02', '2025-12-10 17:36:51.406065+02', '2025-12-09 17:36:51.406065+02');


--
-- Data for Name: users; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.users VALUES ('a0ada47f-f5ff-43b3-8c3e-68492f870fc1', 'EMP001', 'admin', 'admin@restaurant.com', 'hashed_password_123', 'System Admin', 'Ù…Ø¯ÙŠØ± Ø§Ù„Ù†Ø¸Ø§Ù…', '01000000001', '989aa75b-61a1-44c4-9279-fd183df84979', '0375f387-cb50-46ff-b41d-d60fe932addf', 'active', NULL, NULL, 0, NULL, '2025-12-11 17:24:12.191398+02', '2025-12-11 17:24:12.191398+02', NULL);
INSERT INTO public.users VALUES ('0bd55267-11ed-4a77-aa37-8a990e94dd31', 'EMP002', 'warehouse_mgr', 'warehouse@restaurant.com', 'hashed_password_123', 'Ahmed Mohamed', 'Ø£Ø­Ù…Ø¯ Ù…Ø­Ù…Ø¯', '01000000002', 'fda5287b-f3a4-44f4-9d29-83441895610f', '0375f387-cb50-46ff-b41d-d60fe932addf', 'active', NULL, NULL, 0, NULL, '2025-12-11 17:24:12.213897+02', '2025-12-11 17:24:12.213897+02', NULL);
INSERT INTO public.users VALUES ('eff3e90d-dbf6-4536-baa5-1ff53e82c659', 'EMP003', 'branch1_sup', 'branch1@restaurant.com', 'hashed_password_123', 'Mohamed Ali', 'Ù…Ø­Ù…Ø¯ Ø¹Ù„ÙŠ', '01000000003', '2263c054-7645-48dd-b4a9-c536563ed8a7', '393fdf52-1982-481b-a254-11ba0edc1d8b', 'active', NULL, NULL, 0, NULL, '2025-12-11 17:24:12.216294+02', '2025-12-11 17:24:12.216294+02', NULL);
INSERT INTO public.users VALUES ('53c3ad83-b852-4386-9a69-afdb98a4d9c9', 'EMP004', 'cashier1', 'cashier1@restaurant.com', 'hashed_password_123', 'Sara Ahmed', 'Ø³Ø§Ø±Ø© Ø£Ø­Ù…Ø¯', '01000000004', 'a3658e54-8797-4730-a228-8d233bfbaa9c', '393fdf52-1982-481b-a254-11ba0edc1d8b', 'active', NULL, NULL, 0, NULL, '2025-12-11 17:24:12.219234+02', '2025-12-11 17:24:12.219234+02', NULL);
INSERT INTO public.users VALUES ('aaee8a92-fce0-4a57-9569-852ad211d873', 'EMP005', 'chef1', 'chef1@restaurant.com', 'hashed_password_123', 'Hassan Ibrahim', 'Ø­Ø³Ù† Ø¥Ø¨Ø±Ø§Ù‡ÙŠÙ…', '01000000005', '5f43ee8f-f827-447f-b69a-7c60c6e41f42', '393fdf52-1982-481b-a254-11ba0edc1d8b', 'active', NULL, NULL, 0, NULL, '2025-12-11 17:24:12.221457+02', '2025-12-11 17:24:12.221457+02', NULL);
INSERT INTO public.users VALUES ('6c4746c9-75c7-4d40-bd3f-309dc6b5968a', 'EMP006', 'branch2_sup', 'branch2@restaurant.com', 'hashed_password_123', 'Khaled Omar', 'Khaled Omar', '01000000006', '2263c054-7645-48dd-b4a9-c536563ed8a7', '7a5e81b1-5777-425c-968a-ccac5f43fcae', 'active', NULL, NULL, 0, NULL, '2025-12-11 17:36:51.323997+02', '2025-12-11 17:36:51.323997+02', NULL);
INSERT INTO public.users VALUES ('f34679bc-52fa-4b0f-9e95-0b7306af2468', 'EMP007', 'cashier2', 'cashier2@restaurant.com', 'hashed_password_123', 'Nour Mohamed', 'Nour Mohamed', '01000000007', 'a3658e54-8797-4730-a228-8d233bfbaa9c', '7a5e81b1-5777-425c-968a-ccac5f43fcae', 'active', NULL, NULL, 0, NULL, '2025-12-11 17:36:51.327283+02', '2025-12-11 17:36:51.327283+02', NULL);
INSERT INTO public.users VALUES ('d99706bb-c485-4767-abdd-19ec90c448e8', 'EMP008', 'chef2', 'chef2@restaurant.com', 'hashed_password_123', 'Youssef Ahmed', 'Youssef Ahmed', '01000000008', '5f43ee8f-f827-447f-b69a-7c60c6e41f42', '7a5e81b1-5777-425c-968a-ccac5f43fcae', 'active', NULL, NULL, 0, NULL, '2025-12-11 17:36:51.330328+02', '2025-12-11 17:36:51.330328+02', NULL);
INSERT INTO public.users VALUES ('576d7ede-d0bb-4e96-a09c-6665a7e5b2a2', 'EMP009', 'purchase_mgr', 'purchase@restaurant.com', 'hashed_password_123', 'Omar Mahmoud', 'Omar Mahmoud', '01000000009', 'cd5f1c71-218e-4d28-b501-4d84a85367f6', '0375f387-cb50-46ff-b41d-d60fe932addf', 'active', NULL, NULL, 0, NULL, '2025-12-11 18:22:37.647035+02', '2025-12-11 18:22:37.647035+02', NULL);


--
-- Name: auth_group_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.auth_group_id_seq', 1, false);


--
-- Name: auth_group_permissions_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.auth_group_permissions_id_seq', 1, false);


--
-- Name: auth_permission_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.auth_permission_id_seq', 1, false);


--
-- Name: django_content_type_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.django_content_type_id_seq', 1, false);


--
-- Name: django_migrations_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.django_migrations_id_seq', 16, true);


--
-- Name: alert_settings alert_settings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.alert_settings
    ADD CONSTRAINT alert_settings_pkey PRIMARY KEY (id);


--
-- Name: audit_logs audit_logs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audit_logs
    ADD CONSTRAINT audit_logs_pkey PRIMARY KEY (id);


--
-- Name: auth_group auth_group_name_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.auth_group
    ADD CONSTRAINT auth_group_name_key UNIQUE (name);


--
-- Name: auth_group_permissions auth_group_permissions_group_id_permission_id_0cd325b0_uniq; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.auth_group_permissions
    ADD CONSTRAINT auth_group_permissions_group_id_permission_id_0cd325b0_uniq UNIQUE (group_id, permission_id);


--
-- Name: auth_group_permissions auth_group_permissions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.auth_group_permissions
    ADD CONSTRAINT auth_group_permissions_pkey PRIMARY KEY (id);


--
-- Name: auth_group auth_group_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.auth_group
    ADD CONSTRAINT auth_group_pkey PRIMARY KEY (id);


--
-- Name: auth_permission auth_permission_content_type_id_codename_01ab375a_uniq; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.auth_permission
    ADD CONSTRAINT auth_permission_content_type_id_codename_01ab375a_uniq UNIQUE (content_type_id, codename);


--
-- Name: auth_permission auth_permission_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.auth_permission
    ADD CONSTRAINT auth_permission_pkey PRIMARY KEY (id);


--
-- Name: branch_return_items branch_return_items_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.branch_return_items
    ADD CONSTRAINT branch_return_items_pkey PRIMARY KEY (id);


--
-- Name: branch_return_reasons branch_return_reasons_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.branch_return_reasons
    ADD CONSTRAINT branch_return_reasons_code_key UNIQUE (code);


--
-- Name: branch_return_reasons branch_return_reasons_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.branch_return_reasons
    ADD CONSTRAINT branch_return_reasons_pkey PRIMARY KEY (id);


--
-- Name: branch_returns branch_returns_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.branch_returns
    ADD CONSTRAINT branch_returns_pkey PRIMARY KEY (id);


--
-- Name: branch_returns branch_returns_return_number_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.branch_returns
    ADD CONSTRAINT branch_returns_return_number_key UNIQUE (return_number);


--
-- Name: branch_settings branch_settings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.branch_settings
    ADD CONSTRAINT branch_settings_pkey PRIMARY KEY (id);


--
-- Name: branches branches_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.branches
    ADD CONSTRAINT branches_code_key UNIQUE (code);


--
-- Name: branches branches_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.branches
    ADD CONSTRAINT branches_pkey PRIMARY KEY (id);


--
-- Name: categories categories_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.categories
    ADD CONSTRAINT categories_code_key UNIQUE (code);


--
-- Name: categories categories_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.categories
    ADD CONSTRAINT categories_pkey PRIMARY KEY (id);


--
-- Name: daily_inventory_count_items daily_inventory_count_items_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.daily_inventory_count_items
    ADD CONSTRAINT daily_inventory_count_items_pkey PRIMARY KEY (id);


--
-- Name: daily_inventory_counts daily_inventory_counts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.daily_inventory_counts
    ADD CONSTRAINT daily_inventory_counts_pkey PRIMARY KEY (id);


--
-- Name: damage_reasons damage_reasons_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.damage_reasons
    ADD CONSTRAINT damage_reasons_code_key UNIQUE (code);


--
-- Name: damage_reasons damage_reasons_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.damage_reasons
    ADD CONSTRAINT damage_reasons_pkey PRIMARY KEY (id);


--
-- Name: damages damages_damage_number_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.damages
    ADD CONSTRAINT damages_damage_number_key UNIQUE (damage_number);


--
-- Name: damages damages_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.damages
    ADD CONSTRAINT damages_pkey PRIMARY KEY (id);


--
-- Name: django_content_type django_content_type_app_label_model_76bd3d3b_uniq; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.django_content_type
    ADD CONSTRAINT django_content_type_app_label_model_76bd3d3b_uniq UNIQUE (app_label, model);


--
-- Name: django_content_type django_content_type_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.django_content_type
    ADD CONSTRAINT django_content_type_pkey PRIMARY KEY (id);


--
-- Name: django_migrations django_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.django_migrations
    ADD CONSTRAINT django_migrations_pkey PRIMARY KEY (id);


--
-- Name: inventory_batches inventory_batches_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.inventory_batches
    ADD CONSTRAINT inventory_batches_pkey PRIMARY KEY (id);


--
-- Name: inventory inventory_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.inventory
    ADD CONSTRAINT inventory_pkey PRIMARY KEY (id);


--
-- Name: inventory_transactions inventory_transactions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.inventory_transactions
    ADD CONSTRAINT inventory_transactions_pkey PRIMARY KEY (id);


--
-- Name: items items_barcode_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.items
    ADD CONSTRAINT items_barcode_key UNIQUE (barcode);


--
-- Name: items items_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.items
    ADD CONSTRAINT items_code_key UNIQUE (code);


--
-- Name: items items_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.items
    ADD CONSTRAINT items_pkey PRIMARY KEY (id);


--
-- Name: menu_categories menu_categories_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.menu_categories
    ADD CONSTRAINT menu_categories_code_key UNIQUE (code);


--
-- Name: menu_categories menu_categories_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.menu_categories
    ADD CONSTRAINT menu_categories_pkey PRIMARY KEY (id);


--
-- Name: menu_item_ingredients menu_item_ingredients_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.menu_item_ingredients
    ADD CONSTRAINT menu_item_ingredients_pkey PRIMARY KEY (id);


--
-- Name: menu_items menu_items_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.menu_items
    ADD CONSTRAINT menu_items_code_key UNIQUE (code);


--
-- Name: menu_items menu_items_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.menu_items
    ADD CONSTRAINT menu_items_pkey PRIMARY KEY (id);


--
-- Name: notifications notifications_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notifications
    ADD CONSTRAINT notifications_pkey PRIMARY KEY (id);


--
-- Name: order_items order_items_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.order_items
    ADD CONSTRAINT order_items_pkey PRIMARY KEY (id);


--
-- Name: orders orders_order_number_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.orders
    ADD CONSTRAINT orders_order_number_key UNIQUE (order_number);


--
-- Name: orders orders_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.orders
    ADD CONSTRAINT orders_pkey PRIMARY KEY (id);


--
-- Name: purchase_order_items purchase_order_items_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.purchase_order_items
    ADD CONSTRAINT purchase_order_items_pkey PRIMARY KEY (id);


--
-- Name: purchase_orders purchase_orders_order_number_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.purchase_orders
    ADD CONSTRAINT purchase_orders_order_number_key UNIQUE (order_number);


--
-- Name: purchase_orders purchase_orders_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.purchase_orders
    ADD CONSTRAINT purchase_orders_pkey PRIMARY KEY (id);


--
-- Name: purchase_request_items purchase_request_items_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.purchase_request_items
    ADD CONSTRAINT purchase_request_items_pkey PRIMARY KEY (id);


--
-- Name: purchase_requests purchase_requests_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.purchase_requests
    ADD CONSTRAINT purchase_requests_pkey PRIMARY KEY (id);


--
-- Name: purchase_requests purchase_requests_request_number_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.purchase_requests
    ADD CONSTRAINT purchase_requests_request_number_key UNIQUE (request_number);


--
-- Name: roles roles_name_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.roles
    ADD CONSTRAINT roles_name_key UNIQUE (name);


--
-- Name: roles roles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.roles
    ADD CONSTRAINT roles_pkey PRIMARY KEY (id);


--
-- Name: supplier_items supplier_items_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_items
    ADD CONSTRAINT supplier_items_pkey PRIMARY KEY (id);


--
-- Name: supplier_payments supplier_payments_payment_number_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_payments
    ADD CONSTRAINT supplier_payments_payment_number_key UNIQUE (payment_number);


--
-- Name: supplier_payments supplier_payments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_payments
    ADD CONSTRAINT supplier_payments_pkey PRIMARY KEY (id);


--
-- Name: supplier_returns supplier_returns_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_returns
    ADD CONSTRAINT supplier_returns_pkey PRIMARY KEY (id);


--
-- Name: supplier_returns supplier_returns_return_number_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_returns
    ADD CONSTRAINT supplier_returns_return_number_key UNIQUE (return_number);


--
-- Name: suppliers suppliers_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.suppliers
    ADD CONSTRAINT suppliers_code_key UNIQUE (code);


--
-- Name: suppliers suppliers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.suppliers
    ADD CONSTRAINT suppliers_pkey PRIMARY KEY (id);


--
-- Name: supplies supplies_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplies
    ADD CONSTRAINT supplies_pkey PRIMARY KEY (id);


--
-- Name: supplies supplies_supply_number_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplies
    ADD CONSTRAINT supplies_supply_number_key UNIQUE (supply_number);


--
-- Name: supply_items supply_items_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supply_items
    ADD CONSTRAINT supply_items_pkey PRIMARY KEY (id);


--
-- Name: system_settings system_settings_key_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.system_settings
    ADD CONSTRAINT system_settings_key_key UNIQUE (key);


--
-- Name: system_settings system_settings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.system_settings
    ADD CONSTRAINT system_settings_pkey PRIMARY KEY (id);


--
-- Name: transfer_items transfer_items_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.transfer_items
    ADD CONSTRAINT transfer_items_pkey PRIMARY KEY (id);


--
-- Name: transfers transfers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.transfers
    ADD CONSTRAINT transfers_pkey PRIMARY KEY (id);


--
-- Name: transfers transfers_transfer_number_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.transfers
    ADD CONSTRAINT transfers_transfer_number_key UNIQUE (transfer_number);


--
-- Name: alert_settings uk_alert_setting; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.alert_settings
    ADD CONSTRAINT uk_alert_setting UNIQUE (branch_id, alert_type);


--
-- Name: branch_settings uk_branch_setting; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.branch_settings
    ADD CONSTRAINT uk_branch_setting UNIQUE (branch_id, key);


--
-- Name: daily_inventory_count_items uk_count_item; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.daily_inventory_count_items
    ADD CONSTRAINT uk_count_item UNIQUE (count_id, item_id);


--
-- Name: daily_inventory_counts uk_daily_count; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.daily_inventory_counts
    ADD CONSTRAINT uk_daily_count UNIQUE (branch_id, count_date, count_type);


--
-- Name: inventory uk_inventory_branch_item; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.inventory
    ADD CONSTRAINT uk_inventory_branch_item UNIQUE (branch_id, item_id);


--
-- Name: menu_item_ingredients uk_menu_ingredient; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.menu_item_ingredients
    ADD CONSTRAINT uk_menu_ingredient UNIQUE (menu_item_id, item_id);


--
-- Name: purchase_request_items uk_request_item; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.purchase_request_items
    ADD CONSTRAINT uk_request_item UNIQUE (request_id, item_id);


--
-- Name: branch_return_items uk_return_item; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.branch_return_items
    ADD CONSTRAINT uk_return_item UNIQUE (return_id, item_id);


--
-- Name: supplier_items uk_supplier_item; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_items
    ADD CONSTRAINT uk_supplier_item UNIQUE (supplier_id, item_id);


--
-- Name: units units_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.units
    ADD CONSTRAINT units_code_key UNIQUE (code);


--
-- Name: units units_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.units
    ADD CONSTRAINT units_pkey PRIMARY KEY (id);


--
-- Name: user_sessions user_sessions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_sessions
    ADD CONSTRAINT user_sessions_pkey PRIMARY KEY (id);


--
-- Name: users users_email_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_email_key UNIQUE (email);


--
-- Name: users users_employee_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_employee_code_key UNIQUE (employee_code);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: users users_username_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_username_key UNIQUE (username);


--
-- Name: auth_group_name_a6ea08ec_like; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX auth_group_name_a6ea08ec_like ON public.auth_group USING btree (name varchar_pattern_ops);


--
-- Name: auth_group_permissions_group_id_b120cbf9; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX auth_group_permissions_group_id_b120cbf9 ON public.auth_group_permissions USING btree (group_id);


--
-- Name: auth_group_permissions_permission_id_84c5c92e; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX auth_group_permissions_permission_id_84c5c92e ON public.auth_group_permissions USING btree (permission_id);


--
-- Name: auth_permission_content_type_id_2f476e4b; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX auth_permission_content_type_id_2f476e4b ON public.auth_permission USING btree (content_type_id);


--
-- Name: idx_audit_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_audit_date ON public.audit_logs USING btree (created_at);


--
-- Name: idx_audit_table; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_audit_table ON public.audit_logs USING btree (table_name);


--
-- Name: idx_audit_user; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_audit_user ON public.audit_logs USING btree (user_id);


--
-- Name: idx_batches_expiry; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_batches_expiry ON public.inventory_batches USING btree (expiry_date);


--
-- Name: idx_batches_inventory; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_batches_inventory ON public.inventory_batches USING btree (inventory_id);


--
-- Name: idx_br_items_item; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_br_items_item ON public.branch_return_items USING btree (item_id);


--
-- Name: idx_br_items_return; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_br_items_return ON public.branch_return_items USING btree (return_id);


--
-- Name: idx_branch_returns_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_branch_returns_date ON public.branch_returns USING btree (return_date);


--
-- Name: idx_branch_returns_from; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_branch_returns_from ON public.branch_returns USING btree (from_branch_id);


--
-- Name: idx_branch_returns_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_branch_returns_status ON public.branch_returns USING btree (status);


--
-- Name: idx_branch_returns_to; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_branch_returns_to ON public.branch_returns USING btree (to_branch_id);


--
-- Name: idx_branch_settings_branch; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_branch_settings_branch ON public.branch_settings USING btree (branch_id);


--
-- Name: idx_branches_is_main; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_branches_is_main ON public.branches USING btree (is_main_warehouse);


--
-- Name: idx_branches_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_branches_status ON public.branches USING btree (status);


--
-- Name: idx_categories_parent; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_categories_parent ON public.categories USING btree (parent_id);


--
-- Name: idx_count_items_count; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_count_items_count ON public.daily_inventory_count_items USING btree (count_id);


--
-- Name: idx_daily_counts_branch_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_daily_counts_branch_date ON public.daily_inventory_counts USING btree (branch_id, count_date);


--
-- Name: idx_damages_branch; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_damages_branch ON public.damages USING btree (branch_id);


--
-- Name: idx_damages_item; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_damages_item ON public.damages USING btree (item_id);


--
-- Name: idx_damages_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_damages_status ON public.damages USING btree (status);


--
-- Name: idx_inv_trans_branch; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_inv_trans_branch ON public.inventory_transactions USING btree (branch_id);


--
-- Name: idx_inv_trans_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_inv_trans_date ON public.inventory_transactions USING btree (created_at);


--
-- Name: idx_inv_trans_item; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_inv_trans_item ON public.inventory_transactions USING btree (item_id);


--
-- Name: idx_inv_trans_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_inv_trans_type ON public.inventory_transactions USING btree (operation_type);


--
-- Name: idx_inventory_branch; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_inventory_branch ON public.inventory USING btree (branch_id);


--
-- Name: idx_inventory_document; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_inventory_document ON public.inventory USING btree (document_number);


--
-- Name: idx_inventory_entry_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_inventory_entry_date ON public.inventory USING btree (entry_date);


--
-- Name: idx_inventory_item; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_inventory_item ON public.inventory USING btree (item_id);


--
-- Name: idx_items_category; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_items_category ON public.items USING btree (category_id);


--
-- Name: idx_items_code; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_items_code ON public.items USING btree (code);


--
-- Name: idx_items_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_items_status ON public.items USING btree (status);


--
-- Name: idx_menu_categories_active; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_menu_categories_active ON public.menu_categories USING btree (is_active);


--
-- Name: idx_menu_categories_parent; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_menu_categories_parent ON public.menu_categories USING btree (parent_id);


--
-- Name: idx_menu_ingredients_item; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_menu_ingredients_item ON public.menu_item_ingredients USING btree (item_id);


--
-- Name: idx_menu_ingredients_menu; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_menu_ingredients_menu ON public.menu_item_ingredients USING btree (menu_item_id);


--
-- Name: idx_menu_items_category; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_menu_items_category ON public.menu_items USING btree (category_id);


--
-- Name: idx_notifications_branch; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_notifications_branch ON public.notifications USING btree (branch_id);


--
-- Name: idx_notifications_user; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_notifications_user ON public.notifications USING btree (user_id);


--
-- Name: idx_order_items_menu; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_order_items_menu ON public.order_items USING btree (menu_item_id);


--
-- Name: idx_order_items_order; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_order_items_order ON public.order_items USING btree (order_id);


--
-- Name: idx_orders_branch; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_orders_branch ON public.orders USING btree (branch_id);


--
-- Name: idx_orders_cashier; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_orders_cashier ON public.orders USING btree (cashier_id);


--
-- Name: idx_orders_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_orders_date ON public.orders USING btree (created_at);


--
-- Name: idx_orders_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_orders_status ON public.orders USING btree (status);


--
-- Name: idx_po_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_po_date ON public.purchase_orders USING btree (order_date);


--
-- Name: idx_po_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_po_status ON public.purchase_orders USING btree (status);


--
-- Name: idx_po_supplier; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_po_supplier ON public.purchase_orders USING btree (supplier_id);


--
-- Name: idx_poi_item; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_poi_item ON public.purchase_order_items USING btree (item_id);


--
-- Name: idx_poi_order; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_poi_order ON public.purchase_order_items USING btree (order_id);


--
-- Name: idx_pr_items_item; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_pr_items_item ON public.purchase_request_items USING btree (item_id);


--
-- Name: idx_pr_items_request; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_pr_items_request ON public.purchase_request_items USING btree (request_id);


--
-- Name: idx_pr_items_supplier; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_pr_items_supplier ON public.purchase_request_items USING btree (supplier_id);


--
-- Name: idx_purchase_requests_branch; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_purchase_requests_branch ON public.purchase_requests USING btree (branch_id);


--
-- Name: idx_purchase_requests_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_purchase_requests_date ON public.purchase_requests USING btree (request_date);


--
-- Name: idx_purchase_requests_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_purchase_requests_status ON public.purchase_requests USING btree (status);


--
-- Name: idx_returns_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_returns_status ON public.supplier_returns USING btree (status);


--
-- Name: idx_returns_supplier; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_returns_supplier ON public.supplier_returns USING btree (supplier_id);


--
-- Name: idx_returns_supply; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_returns_supply ON public.supplier_returns USING btree (supply_id);


--
-- Name: idx_roles_name; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_roles_name ON public.roles USING btree (name);


--
-- Name: idx_sessions_token; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_sessions_token ON public.user_sessions USING btree (token_hash);


--
-- Name: idx_sessions_user; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_sessions_user ON public.user_sessions USING btree (user_id);


--
-- Name: idx_settings_key; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_settings_key ON public.system_settings USING btree (key);


--
-- Name: idx_supplier_items_item; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_supplier_items_item ON public.supplier_items USING btree (item_id);


--
-- Name: idx_supplier_items_supplier; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_supplier_items_supplier ON public.supplier_items USING btree (supplier_id);


--
-- Name: idx_supplier_payments_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_supplier_payments_date ON public.supplier_payments USING btree (payment_date);


--
-- Name: idx_supplier_payments_supplier; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_supplier_payments_supplier ON public.supplier_payments USING btree (supplier_id);


--
-- Name: idx_suppliers_code; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_suppliers_code ON public.suppliers USING btree (code);


--
-- Name: idx_suppliers_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_suppliers_status ON public.suppliers USING btree (status);


--
-- Name: idx_supplies_branch; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_supplies_branch ON public.supplies USING btree (branch_id);


--
-- Name: idx_supplies_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_supplies_date ON public.supplies USING btree (received_at);


--
-- Name: idx_supplies_supplier; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_supplies_supplier ON public.supplies USING btree (supplier_id);


--
-- Name: idx_supply_items_item; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_supply_items_item ON public.supply_items USING btree (item_id);


--
-- Name: idx_supply_items_supply; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_supply_items_supply ON public.supply_items USING btree (supply_id);


--
-- Name: idx_transfer_items_item; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_transfer_items_item ON public.transfer_items USING btree (item_id);


--
-- Name: idx_transfer_items_transfer; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_transfer_items_transfer ON public.transfer_items USING btree (transfer_id);


--
-- Name: idx_transfers_from_branch; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_transfers_from_branch ON public.transfers USING btree (from_branch_id);


--
-- Name: idx_transfers_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_transfers_status ON public.transfers USING btree (status);


--
-- Name: idx_transfers_to_branch; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_transfers_to_branch ON public.transfers USING btree (to_branch_id);


--
-- Name: idx_users_branch; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_users_branch ON public.users USING btree (branch_id);


--
-- Name: idx_users_role; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_users_role ON public.users USING btree (role_id);


--
-- Name: idx_users_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_users_status ON public.users USING btree (status);


--
-- Name: inventory trg_calc_inventory_total; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_calc_inventory_total BEFORE INSERT OR UPDATE OF partial_quantity, content_quantity ON public.inventory FOR EACH ROW EXECUTE FUNCTION public.calculate_branch_inventory_total();


--
-- Name: branch_return_items trg_update_br_totals; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_update_br_totals AFTER INSERT OR DELETE OR UPDATE ON public.branch_return_items FOR EACH ROW EXECUTE FUNCTION public.update_branch_return_totals();


--
-- Name: purchase_request_items trg_update_pr_totals; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_update_pr_totals AFTER INSERT OR DELETE OR UPDATE ON public.purchase_request_items FOR EACH ROW EXECUTE FUNCTION public.update_purchase_request_totals();


--
-- Name: menu_categories update_menu_categories_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER update_menu_categories_updated_at BEFORE UPDATE ON public.menu_categories FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: alert_settings alert_settings_branch_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.alert_settings
    ADD CONSTRAINT alert_settings_branch_id_fkey FOREIGN KEY (branch_id) REFERENCES public.branches(id) ON DELETE CASCADE;


--
-- Name: audit_logs audit_logs_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audit_logs
    ADD CONSTRAINT audit_logs_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: auth_group_permissions auth_group_permissio_permission_id_84c5c92e_fk_auth_perm; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.auth_group_permissions
    ADD CONSTRAINT auth_group_permissio_permission_id_84c5c92e_fk_auth_perm FOREIGN KEY (permission_id) REFERENCES public.auth_permission(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: auth_group_permissions auth_group_permissions_group_id_b120cbf9_fk_auth_group_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.auth_group_permissions
    ADD CONSTRAINT auth_group_permissions_group_id_b120cbf9_fk_auth_group_id FOREIGN KEY (group_id) REFERENCES public.auth_group(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: auth_permission auth_permission_content_type_id_2f476e4b_fk_django_co; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.auth_permission
    ADD CONSTRAINT auth_permission_content_type_id_2f476e4b_fk_django_co FOREIGN KEY (content_type_id) REFERENCES public.django_content_type(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: branch_return_items branch_return_items_batch_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.branch_return_items
    ADD CONSTRAINT branch_return_items_batch_id_fkey FOREIGN KEY (batch_id) REFERENCES public.inventory_batches(id) ON DELETE SET NULL;


--
-- Name: branch_return_items branch_return_items_item_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.branch_return_items
    ADD CONSTRAINT branch_return_items_item_id_fkey FOREIGN KEY (item_id) REFERENCES public.items(id) ON DELETE RESTRICT;


--
-- Name: branch_return_items branch_return_items_return_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.branch_return_items
    ADD CONSTRAINT branch_return_items_return_id_fkey FOREIGN KEY (return_id) REFERENCES public.branch_returns(id) ON DELETE CASCADE;


--
-- Name: branch_returns branch_returns_approved_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.branch_returns
    ADD CONSTRAINT branch_returns_approved_by_fkey FOREIGN KEY (approved_by) REFERENCES public.users(id);


--
-- Name: branch_returns branch_returns_from_branch_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.branch_returns
    ADD CONSTRAINT branch_returns_from_branch_id_fkey FOREIGN KEY (from_branch_id) REFERENCES public.branches(id) ON DELETE RESTRICT;


--
-- Name: branch_returns branch_returns_received_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.branch_returns
    ADD CONSTRAINT branch_returns_received_by_fkey FOREIGN KEY (received_by) REFERENCES public.users(id);


--
-- Name: branch_returns branch_returns_rejected_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.branch_returns
    ADD CONSTRAINT branch_returns_rejected_by_fkey FOREIGN KEY (rejected_by) REFERENCES public.users(id);


--
-- Name: branch_returns branch_returns_requested_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.branch_returns
    ADD CONSTRAINT branch_returns_requested_by_fkey FOREIGN KEY (requested_by) REFERENCES public.users(id);


--
-- Name: branch_returns branch_returns_to_branch_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.branch_returns
    ADD CONSTRAINT branch_returns_to_branch_id_fkey FOREIGN KEY (to_branch_id) REFERENCES public.branches(id) ON DELETE RESTRICT;


--
-- Name: branch_settings branch_settings_branch_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.branch_settings
    ADD CONSTRAINT branch_settings_branch_id_fkey FOREIGN KEY (branch_id) REFERENCES public.branches(id) ON DELETE CASCADE;


--
-- Name: branch_settings branch_settings_updated_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.branch_settings
    ADD CONSTRAINT branch_settings_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES public.users(id);


--
-- Name: categories categories_parent_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.categories
    ADD CONSTRAINT categories_parent_id_fkey FOREIGN KEY (parent_id) REFERENCES public.categories(id) ON DELETE SET NULL;


--
-- Name: daily_inventory_count_items daily_inventory_count_items_count_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.daily_inventory_count_items
    ADD CONSTRAINT daily_inventory_count_items_count_id_fkey FOREIGN KEY (count_id) REFERENCES public.daily_inventory_counts(id) ON DELETE CASCADE;


--
-- Name: daily_inventory_count_items daily_inventory_count_items_item_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.daily_inventory_count_items
    ADD CONSTRAINT daily_inventory_count_items_item_id_fkey FOREIGN KEY (item_id) REFERENCES public.items(id) ON DELETE RESTRICT;


--
-- Name: daily_inventory_counts daily_inventory_counts_approved_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.daily_inventory_counts
    ADD CONSTRAINT daily_inventory_counts_approved_by_fkey FOREIGN KEY (approved_by) REFERENCES public.users(id);


--
-- Name: daily_inventory_counts daily_inventory_counts_branch_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.daily_inventory_counts
    ADD CONSTRAINT daily_inventory_counts_branch_id_fkey FOREIGN KEY (branch_id) REFERENCES public.branches(id) ON DELETE RESTRICT;


--
-- Name: daily_inventory_counts daily_inventory_counts_counted_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.daily_inventory_counts
    ADD CONSTRAINT daily_inventory_counts_counted_by_fkey FOREIGN KEY (counted_by) REFERENCES public.users(id);


--
-- Name: damages damages_approved_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.damages
    ADD CONSTRAINT damages_approved_by_fkey FOREIGN KEY (approved_by) REFERENCES public.users(id);


--
-- Name: damages damages_batch_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.damages
    ADD CONSTRAINT damages_batch_id_fkey FOREIGN KEY (batch_id) REFERENCES public.inventory_batches(id) ON DELETE SET NULL;


--
-- Name: damages damages_branch_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.damages
    ADD CONSTRAINT damages_branch_id_fkey FOREIGN KEY (branch_id) REFERENCES public.branches(id) ON DELETE RESTRICT;


--
-- Name: damages damages_item_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.damages
    ADD CONSTRAINT damages_item_id_fkey FOREIGN KEY (item_id) REFERENCES public.items(id) ON DELETE RESTRICT;


--
-- Name: damages damages_reason_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.damages
    ADD CONSTRAINT damages_reason_id_fkey FOREIGN KEY (reason_id) REFERENCES public.damage_reasons(id) ON DELETE RESTRICT;


--
-- Name: damages damages_registered_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.damages
    ADD CONSTRAINT damages_registered_by_fkey FOREIGN KEY (registered_by) REFERENCES public.users(id);


--
-- Name: damages damages_rejected_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.damages
    ADD CONSTRAINT damages_rejected_by_fkey FOREIGN KEY (rejected_by) REFERENCES public.users(id);


--
-- Name: inventory_batches fk_batch_supply; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.inventory_batches
    ADD CONSTRAINT fk_batch_supply FOREIGN KEY (supply_id) REFERENCES public.supplies(id) ON DELETE SET NULL;


--
-- Name: inventory_batches inventory_batches_inventory_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.inventory_batches
    ADD CONSTRAINT inventory_batches_inventory_id_fkey FOREIGN KEY (inventory_id) REFERENCES public.inventory(id) ON DELETE CASCADE;


--
-- Name: inventory inventory_branch_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.inventory
    ADD CONSTRAINT inventory_branch_id_fkey FOREIGN KEY (branch_id) REFERENCES public.branches(id) ON DELETE RESTRICT;


--
-- Name: inventory inventory_item_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.inventory
    ADD CONSTRAINT inventory_item_id_fkey FOREIGN KEY (item_id) REFERENCES public.items(id) ON DELETE RESTRICT;


--
-- Name: inventory_transactions inventory_transactions_batch_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.inventory_transactions
    ADD CONSTRAINT inventory_transactions_batch_id_fkey FOREIGN KEY (batch_id) REFERENCES public.inventory_batches(id) ON DELETE SET NULL;


--
-- Name: inventory_transactions inventory_transactions_branch_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.inventory_transactions
    ADD CONSTRAINT inventory_transactions_branch_id_fkey FOREIGN KEY (branch_id) REFERENCES public.branches(id) ON DELETE RESTRICT;


--
-- Name: inventory_transactions inventory_transactions_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.inventory_transactions
    ADD CONSTRAINT inventory_transactions_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.users(id);


--
-- Name: inventory_transactions inventory_transactions_item_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.inventory_transactions
    ADD CONSTRAINT inventory_transactions_item_id_fkey FOREIGN KEY (item_id) REFERENCES public.items(id) ON DELETE RESTRICT;


--
-- Name: items items_category_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.items
    ADD CONSTRAINT items_category_id_fkey FOREIGN KEY (category_id) REFERENCES public.categories(id) ON DELETE SET NULL;


--
-- Name: items items_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.items
    ADD CONSTRAINT items_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.users(id);


--
-- Name: items items_unit_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.items
    ADD CONSTRAINT items_unit_id_fkey FOREIGN KEY (unit_id) REFERENCES public.units(id) ON DELETE RESTRICT;


--
-- Name: menu_categories menu_categories_parent_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.menu_categories
    ADD CONSTRAINT menu_categories_parent_id_fkey FOREIGN KEY (parent_id) REFERENCES public.menu_categories(id) ON DELETE SET NULL;


--
-- Name: menu_item_ingredients menu_item_ingredients_item_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.menu_item_ingredients
    ADD CONSTRAINT menu_item_ingredients_item_id_fkey FOREIGN KEY (item_id) REFERENCES public.items(id) ON DELETE RESTRICT;


--
-- Name: menu_item_ingredients menu_item_ingredients_menu_item_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.menu_item_ingredients
    ADD CONSTRAINT menu_item_ingredients_menu_item_id_fkey FOREIGN KEY (menu_item_id) REFERENCES public.menu_items(id) ON DELETE CASCADE;


--
-- Name: menu_item_ingredients menu_item_ingredients_unit_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.menu_item_ingredients
    ADD CONSTRAINT menu_item_ingredients_unit_id_fkey FOREIGN KEY (unit_id) REFERENCES public.units(id) ON DELETE RESTRICT;


--
-- Name: menu_items menu_items_category_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.menu_items
    ADD CONSTRAINT menu_items_category_id_fkey FOREIGN KEY (category_id) REFERENCES public.menu_categories(id) ON DELETE SET NULL;


--
-- Name: notifications notifications_branch_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notifications
    ADD CONSTRAINT notifications_branch_id_fkey FOREIGN KEY (branch_id) REFERENCES public.branches(id) ON DELETE CASCADE;


--
-- Name: notifications notifications_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notifications
    ADD CONSTRAINT notifications_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: order_items order_items_menu_item_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.order_items
    ADD CONSTRAINT order_items_menu_item_id_fkey FOREIGN KEY (menu_item_id) REFERENCES public.menu_items(id) ON DELETE RESTRICT;


--
-- Name: order_items order_items_order_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.order_items
    ADD CONSTRAINT order_items_order_id_fkey FOREIGN KEY (order_id) REFERENCES public.orders(id) ON DELETE CASCADE;


--
-- Name: orders orders_branch_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.orders
    ADD CONSTRAINT orders_branch_id_fkey FOREIGN KEY (branch_id) REFERENCES public.branches(id) ON DELETE RESTRICT;


--
-- Name: orders orders_cancelled_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.orders
    ADD CONSTRAINT orders_cancelled_by_fkey FOREIGN KEY (cancelled_by) REFERENCES public.users(id);


--
-- Name: orders orders_cashier_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.orders
    ADD CONSTRAINT orders_cashier_id_fkey FOREIGN KEY (cashier_id) REFERENCES public.users(id);


--
-- Name: orders orders_chef_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.orders
    ADD CONSTRAINT orders_chef_id_fkey FOREIGN KEY (chef_id) REFERENCES public.users(id);


--
-- Name: purchase_order_items purchase_order_items_item_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.purchase_order_items
    ADD CONSTRAINT purchase_order_items_item_id_fkey FOREIGN KEY (item_id) REFERENCES public.items(id) ON DELETE RESTRICT;


--
-- Name: purchase_order_items purchase_order_items_order_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.purchase_order_items
    ADD CONSTRAINT purchase_order_items_order_id_fkey FOREIGN KEY (order_id) REFERENCES public.purchase_orders(id) ON DELETE CASCADE;


--
-- Name: purchase_order_items purchase_order_items_request_item_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.purchase_order_items
    ADD CONSTRAINT purchase_order_items_request_item_id_fkey FOREIGN KEY (request_item_id) REFERENCES public.purchase_request_items(id) ON DELETE SET NULL;


--
-- Name: purchase_orders purchase_orders_approved_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.purchase_orders
    ADD CONSTRAINT purchase_orders_approved_by_fkey FOREIGN KEY (approved_by) REFERENCES public.users(id);


--
-- Name: purchase_orders purchase_orders_branch_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.purchase_orders
    ADD CONSTRAINT purchase_orders_branch_id_fkey FOREIGN KEY (branch_id) REFERENCES public.branches(id) ON DELETE RESTRICT;


--
-- Name: purchase_orders purchase_orders_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.purchase_orders
    ADD CONSTRAINT purchase_orders_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.users(id);


--
-- Name: purchase_orders purchase_orders_request_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.purchase_orders
    ADD CONSTRAINT purchase_orders_request_id_fkey FOREIGN KEY (request_id) REFERENCES public.purchase_requests(id) ON DELETE SET NULL;


--
-- Name: purchase_orders purchase_orders_supplier_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.purchase_orders
    ADD CONSTRAINT purchase_orders_supplier_id_fkey FOREIGN KEY (supplier_id) REFERENCES public.suppliers(id) ON DELETE RESTRICT;


--
-- Name: purchase_request_items purchase_request_items_item_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.purchase_request_items
    ADD CONSTRAINT purchase_request_items_item_id_fkey FOREIGN KEY (item_id) REFERENCES public.items(id) ON DELETE RESTRICT;


--
-- Name: purchase_request_items purchase_request_items_request_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.purchase_request_items
    ADD CONSTRAINT purchase_request_items_request_id_fkey FOREIGN KEY (request_id) REFERENCES public.purchase_requests(id) ON DELETE CASCADE;


--
-- Name: purchase_request_items purchase_request_items_supplier_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.purchase_request_items
    ADD CONSTRAINT purchase_request_items_supplier_id_fkey FOREIGN KEY (supplier_id) REFERENCES public.suppliers(id) ON DELETE SET NULL;


--
-- Name: purchase_requests purchase_requests_approved_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.purchase_requests
    ADD CONSTRAINT purchase_requests_approved_by_fkey FOREIGN KEY (approved_by) REFERENCES public.users(id);


--
-- Name: purchase_requests purchase_requests_branch_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.purchase_requests
    ADD CONSTRAINT purchase_requests_branch_id_fkey FOREIGN KEY (branch_id) REFERENCES public.branches(id) ON DELETE RESTRICT;


--
-- Name: purchase_requests purchase_requests_rejected_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.purchase_requests
    ADD CONSTRAINT purchase_requests_rejected_by_fkey FOREIGN KEY (rejected_by) REFERENCES public.users(id);


--
-- Name: purchase_requests purchase_requests_requested_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.purchase_requests
    ADD CONSTRAINT purchase_requests_requested_by_fkey FOREIGN KEY (requested_by) REFERENCES public.users(id);


--
-- Name: supplier_items supplier_items_item_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_items
    ADD CONSTRAINT supplier_items_item_id_fkey FOREIGN KEY (item_id) REFERENCES public.items(id) ON DELETE CASCADE;


--
-- Name: supplier_items supplier_items_supplier_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_items
    ADD CONSTRAINT supplier_items_supplier_id_fkey FOREIGN KEY (supplier_id) REFERENCES public.suppliers(id) ON DELETE CASCADE;


--
-- Name: supplier_payments supplier_payments_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_payments
    ADD CONSTRAINT supplier_payments_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.users(id);


--
-- Name: supplier_payments supplier_payments_supplier_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_payments
    ADD CONSTRAINT supplier_payments_supplier_id_fkey FOREIGN KEY (supplier_id) REFERENCES public.suppliers(id) ON DELETE RESTRICT;


--
-- Name: supplier_payments supplier_payments_supply_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_payments
    ADD CONSTRAINT supplier_payments_supply_id_fkey FOREIGN KEY (supply_id) REFERENCES public.supplies(id) ON DELETE SET NULL;


--
-- Name: supplier_returns supplier_returns_approved_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_returns
    ADD CONSTRAINT supplier_returns_approved_by_fkey FOREIGN KEY (approved_by) REFERENCES public.users(id);


--
-- Name: supplier_returns supplier_returns_item_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_returns
    ADD CONSTRAINT supplier_returns_item_id_fkey FOREIGN KEY (item_id) REFERENCES public.items(id) ON DELETE RESTRICT;


--
-- Name: supplier_returns supplier_returns_registered_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_returns
    ADD CONSTRAINT supplier_returns_registered_by_fkey FOREIGN KEY (registered_by) REFERENCES public.users(id);


--
-- Name: supplier_returns supplier_returns_rejected_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_returns
    ADD CONSTRAINT supplier_returns_rejected_by_fkey FOREIGN KEY (rejected_by) REFERENCES public.users(id);


--
-- Name: supplier_returns supplier_returns_supplier_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_returns
    ADD CONSTRAINT supplier_returns_supplier_id_fkey FOREIGN KEY (supplier_id) REFERENCES public.suppliers(id) ON DELETE RESTRICT;


--
-- Name: supplier_returns supplier_returns_supply_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_returns
    ADD CONSTRAINT supplier_returns_supply_id_fkey FOREIGN KEY (supply_id) REFERENCES public.supplies(id) ON DELETE RESTRICT;


--
-- Name: suppliers suppliers_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.suppliers
    ADD CONSTRAINT suppliers_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.users(id);


--
-- Name: supplies supplies_approved_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplies
    ADD CONSTRAINT supplies_approved_by_fkey FOREIGN KEY (approved_by) REFERENCES public.users(id);


--
-- Name: supplies supplies_branch_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplies
    ADD CONSTRAINT supplies_branch_id_fkey FOREIGN KEY (branch_id) REFERENCES public.branches(id) ON DELETE RESTRICT;


--
-- Name: supplies supplies_received_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplies
    ADD CONSTRAINT supplies_received_by_fkey FOREIGN KEY (received_by) REFERENCES public.users(id);


--
-- Name: supplies supplies_supplier_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplies
    ADD CONSTRAINT supplies_supplier_id_fkey FOREIGN KEY (supplier_id) REFERENCES public.suppliers(id) ON DELETE RESTRICT;


--
-- Name: supply_items supply_items_item_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supply_items
    ADD CONSTRAINT supply_items_item_id_fkey FOREIGN KEY (item_id) REFERENCES public.items(id) ON DELETE RESTRICT;


--
-- Name: supply_items supply_items_supply_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supply_items
    ADD CONSTRAINT supply_items_supply_id_fkey FOREIGN KEY (supply_id) REFERENCES public.supplies(id) ON DELETE CASCADE;


--
-- Name: system_settings system_settings_updated_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.system_settings
    ADD CONSTRAINT system_settings_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES public.users(id);


--
-- Name: transfer_items transfer_items_item_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.transfer_items
    ADD CONSTRAINT transfer_items_item_id_fkey FOREIGN KEY (item_id) REFERENCES public.items(id) ON DELETE RESTRICT;


--
-- Name: transfer_items transfer_items_transfer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.transfer_items
    ADD CONSTRAINT transfer_items_transfer_id_fkey FOREIGN KEY (transfer_id) REFERENCES public.transfers(id) ON DELETE CASCADE;


--
-- Name: transfers transfers_approved_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.transfers
    ADD CONSTRAINT transfers_approved_by_fkey FOREIGN KEY (approved_by) REFERENCES public.users(id);


--
-- Name: transfers transfers_from_branch_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.transfers
    ADD CONSTRAINT transfers_from_branch_id_fkey FOREIGN KEY (from_branch_id) REFERENCES public.branches(id) ON DELETE RESTRICT;


--
-- Name: transfers transfers_received_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.transfers
    ADD CONSTRAINT transfers_received_by_fkey FOREIGN KEY (received_by) REFERENCES public.users(id);


--
-- Name: transfers transfers_rejected_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.transfers
    ADD CONSTRAINT transfers_rejected_by_fkey FOREIGN KEY (rejected_by) REFERENCES public.users(id);


--
-- Name: transfers transfers_requested_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.transfers
    ADD CONSTRAINT transfers_requested_by_fkey FOREIGN KEY (requested_by) REFERENCES public.users(id);


--
-- Name: transfers transfers_to_branch_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.transfers
    ADD CONSTRAINT transfers_to_branch_id_fkey FOREIGN KEY (to_branch_id) REFERENCES public.branches(id) ON DELETE RESTRICT;


--
-- Name: user_sessions user_sessions_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_sessions
    ADD CONSTRAINT user_sessions_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: users users_branch_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_branch_id_fkey FOREIGN KEY (branch_id) REFERENCES public.branches(id) ON DELETE SET NULL;


--
-- Name: users users_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.users(id);


--
-- Name: users users_role_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_role_id_fkey FOREIGN KEY (role_id) REFERENCES public.roles(id) ON DELETE RESTRICT;


--
-- PostgreSQL database dump complete
--


