-- ==============================================================================
-- SafeHer / SvaShield Database Schema
-- Flyway Migration V6 — Phone Verification, Rate Limiting, OTP & Outbox Engine
-- ==============================================================================

-- 1. Add Legacy and Phone Verification Columns to users
ALTER TABLE users ADD COLUMN IF NOT EXISTS is_legacy_account BOOLEAN DEFAULT FALSE NOT NULL;
ALTER TABLE users ADD COLUMN IF NOT EXISTS phone_verified_at TIMESTAMPTZ;

CREATE INDEX IF NOT EXISTS idx_users_phone_verified_at ON users(phone_verified_at);
CREATE INDEX IF NOT EXISTS idx_users_legacy ON users(is_legacy_account) WHERE is_legacy_account = TRUE;

-- 2. Strict Precondition Check & Approved Legacy Backfill (With Table Lock)
DO $$
DECLARE
    v_legacy_count INT;
    v_user3_exists INT;
    v_unexpected_count INT;
BEGIN
    -- Concurrency Lock: Prevent concurrent user modifications during preflight & backfill
    LOCK TABLE users IN SHARE ROW EXCLUSIVE MODE;

    -- Verify that approved legacy accounts {1, 2} exist, are ACTIVE and is_verified = TRUE
    SELECT COUNT(*) INTO v_legacy_count
    FROM users
    WHERE id IN (1, 2) AND account_status = 'ACTIVE' AND is_verified = TRUE;

    IF v_legacy_count != 2 THEN
        RAISE EXCEPTION 'MIGRATION V6 ABORTED: Expected legacy accounts {1, 2} to be ACTIVE and verified, found %.', v_legacy_count;
    END IF;

    -- Verify that User ID 3 exists (the Phase 2B registration)
    SELECT COUNT(*) INTO v_user3_exists
    FROM users
    WHERE id = 3;

    IF v_user3_exists != 1 THEN
        RAISE EXCEPTION 'MIGRATION V6 ABORTED: Expected User ID 3 to exist in database, found %.', v_user3_exists;
    END IF;

    -- Verify that NO accounts exist beyond the approved set {1, 2, 3}
    SELECT COUNT(*) INTO v_unexpected_count
    FROM users
    WHERE id NOT IN (1, 2, 3);

    IF v_unexpected_count != 0 THEN
        RAISE EXCEPTION 'MIGRATION V6 ABORTED: Unexpected user accounts found beyond approved set {1, 2, 3}. Found % unexpected rows.', v_unexpected_count;
    END IF;

    -- Grandfather ONLY approved legacy accounts {1, 2}
    -- User ID 3 is intentionally NOT grandfathered (is_legacy_account remains FALSE, phone_verified_at remains NULL)
    UPDATE users 
    SET is_legacy_account = TRUE 
    WHERE id IN (1, 2);

    RAISE NOTICE 'Migration V6 successfully grandfathered legacy accounts {1, 2}. User ID 3 preserved as non-legacy with phone_verified_at = NULL.';
END $$;

-- 3. Database-Level Trigger: Prevent Granting OR Revoking is_legacy_account Post-Migration
CREATE OR REPLACE FUNCTION protect_legacy_account_flag() 
RETURNS TRIGGER AS $$
BEGIN
    -- Prevent setting is_legacy_account on new inserts
    IF TG_OP = 'INSERT' AND NEW.is_legacy_account = TRUE THEN
        RAISE EXCEPTION 'SECURITY VIOLATION: is_legacy_account cannot be granted to new accounts.';
    END IF;

    -- Prevent modifying is_legacy_account on existing accounts
    IF TG_OP = 'UPDATE' THEN
        -- Cannot grant legacy flag to a non-legacy account (including User ID 3 or new accounts)
        IF OLD.is_legacy_account = FALSE AND NEW.is_legacy_account = TRUE THEN
            RAISE EXCEPTION 'SECURITY VIOLATION: is_legacy_account cannot be granted post-migration.';
        END IF;
        -- Cannot revoke legacy flag from an existing legacy account (IDs 1 and 2)
        IF OLD.is_legacy_account = TRUE AND NEW.is_legacy_account = FALSE THEN
            RAISE EXCEPTION 'SECURITY VIOLATION: is_legacy_account cannot be removed from a legacy account.';
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_protect_legacy_account_flag ON users;
CREATE TRIGGER trg_protect_legacy_account_flag
BEFORE INSERT OR UPDATE ON users
FOR EACH ROW
EXECUTE FUNCTION protect_legacy_account_flag();

-- 4. Persistent Sliding-Event Rate Limit Table
CREATE TABLE IF NOT EXISTS rate_limit_events (
    id BIGSERIAL PRIMARY KEY,
    scope_key VARCHAR(100) NOT NULL,          -- e.g. "PHONE:+919876543210" or "IP:203.0.113.195"
    action_type VARCHAR(30) NOT NULL,        -- "OTP_DISPATCH", "FAILED_VERIFY", "LOGIN_ATTEMPT"
    event_timestamp TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_rate_limit_sliding 
    ON rate_limit_events (scope_key, action_type, event_timestamp DESC);

-- 5. OTP Verifications Table (Orthogonal Verification Lifecycle)
CREATE TABLE IF NOT EXISTS otp_verifications (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT REFERENCES users(id) ON DELETE CASCADE, -- Nullable to support pre-registration and registration flows
    phone VARCHAR(20) NOT NULL,
    purpose VARCHAR(30) DEFAULT 'REGISTRATION' NOT NULL,
    otp_hash VARCHAR(64) NOT NULL,           -- Context-bound HMAC-SHA256 hex digest
    salt VARCHAR(32) NOT NULL,               -- 16-byte random hex salt
    pepper_version VARCHAR(10) DEFAULT 'v1' NOT NULL,
    status VARCHAR(30) DEFAULT 'PENDING' NOT NULL,
    attempts_count INT DEFAULT 0 NOT NULL,
    max_attempts INT DEFAULT 3 NOT NULL,
    expires_at TIMESTAMPTZ NOT NULL,
    consumed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT chk_otp_status CHECK (
        status IN ('PENDING', 'CONSUMED', 'EXPIRED', 'EXCEEDED', 'SUPERSEDED')
    )
);

-- Database Invariant: Exactly ONE active PENDING code per phone and purpose
CREATE UNIQUE INDEX IF NOT EXISTS idx_unique_active_otp_per_phone 
    ON otp_verifications (phone, purpose) 
    WHERE consumed_at IS NULL AND status = 'PENDING';

CREATE INDEX IF NOT EXISTS idx_otp_user_id ON otp_verifications(user_id);
CREATE INDEX IF NOT EXISTS idx_otp_expires_at ON otp_verifications(expires_at);

-- 6. Transactional SMS Outbox Table (Orthogonal Dispatch Lifecycle)
CREATE TABLE IF NOT EXISTS sms_outbox (
    id BIGSERIAL PRIMARY KEY,
    otp_verification_id BIGINT NOT NULL REFERENCES otp_verifications(id) ON DELETE CASCADE,
    phone VARCHAR(20) NOT NULL,
    correlation_id VARCHAR(64) NOT NULL UNIQUE,
    key_version VARCHAR(10) DEFAULT 'v1' NOT NULL,
    encrypted_payload TEXT,                 -- AES-256-GCM ciphertext (Base64); logically deleted to NULL on resolution
    payload_nonce VARCHAR(32),              -- 12-byte IV (Base64)
    payload_tag VARCHAR(32),                -- 16-byte GCM tag (Base64)
    status VARCHAR(30) DEFAULT 'CREATED' NOT NULL,
    provider_ref VARCHAR(100),              -- MSG91 request ID
    dispatch_started_at TIMESTAMPTZ,
    retry_count INT DEFAULT 0 NOT NULL,
    max_retries INT DEFAULT 3 NOT NULL,
    next_reconcile_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT chk_sms_outbox_status CHECK (
        status IN ('CREATED', 'DISPATCHING', 'ACCEPTED', 'UNCERTAIN', 'REJECTED', 'SUPERSEDED', 'RESOLVED')
    )
);

CREATE INDEX IF NOT EXISTS idx_sms_outbox_worker 
    ON sms_outbox(status, next_reconcile_at) 
    WHERE status IN ('CREATED', 'DISPATCHING', 'UNCERTAIN');

-- 7. Webhook Event Deduplication Receipts Table
CREATE TABLE IF NOT EXISTS webhook_event_receipts (
    id BIGSERIAL PRIMARY KEY,
    provider_event_id VARCHAR(100) NOT NULL UNIQUE,
    request_id VARCHAR(100) NOT NULL,
    correlation_id VARCHAR(64),
    status_code VARCHAR(20) NOT NULL,
    delivery_time TIMESTAMPTZ,
    received_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_webhook_receipts_req ON webhook_event_receipts(request_id);

-- 8. Quarantined Webhook Events Table (Auditing Unmatched/Malformed Callbacks)
CREATE TABLE IF NOT EXISTS quarantined_webhook_events (
    id BIGSERIAL PRIMARY KEY,
    raw_payload TEXT NOT NULL,
    rejection_reason VARCHAR(255) NOT NULL,
    source_ip VARCHAR(50),
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL
);

-- 9. Accurate Terminology & Audit Documentation
COMMENT ON TABLE users IS 'User accounts with is_legacy_account and phone_verified_at flags';
COMMENT ON COLUMN users.phone_verified_at IS 'Explicit timestamp of real telecom SMS verification; NULL for unverified or grandfathered legacy users';
COMMENT ON COLUMN users.is_legacy_account IS 'Database-driven grandfathering flag for pre-V6 active accounts; protected against modification by trigger';
COMMENT ON TABLE otp_verifications IS 'Single-use OTP verification records with context-bound HMAC-SHA256 hashes';
COMMENT ON TABLE sms_outbox IS 'Transactional Outbox for reliable SMS dispatch and reconciliation';
COMMENT ON COLUMN sms_outbox.encrypted_payload IS 'AES-256-GCM encrypted OTP payload. Setting to NULL represents logical deletion, not guaranteed physical zeroization of storage or WAL.';
