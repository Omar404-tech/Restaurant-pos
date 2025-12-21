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


