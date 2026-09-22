-- ==============================================================================
-- SafeHer Database Schema (PostgreSQL)
-- Version: V1__init_schema.sql
-- Description: Core 10 normalized tables with indexes, foreign keys, and constraints
-- ==============================================================================

-- 1. Users Table
CREATE TABLE IF NOT EXISTS users (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(150) UNIQUE NOT NULL,
    phone VARCHAR(20) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    pin_hash VARCHAR(255),
    role VARCHAR(30) DEFAULT 'ROLE_USER' NOT NULL,
    is_verified BOOLEAN DEFAULT FALSE NOT NULL,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_users_phone ON users(phone);

-- 2. Emergency Contacts Table
CREATE TABLE IF NOT EXISTS emergency_contacts (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    contact_name VARCHAR(100) NOT NULL,
    phone VARCHAR(20) NOT NULL,
    relationship VARCHAR(50),
    priority INT DEFAULT 1 NOT NULL,
    notify_sms BOOLEAN DEFAULT TRUE NOT NULL,
    notify_push BOOLEAN DEFAULT TRUE NOT NULL,
    is_verified BOOLEAN DEFAULT FALSE NOT NULL,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT uq_user_contact_phone UNIQUE (user_id, phone)
);

CREATE INDEX IF NOT EXISTS idx_contacts_user_id ON emergency_contacts(user_id);
CREATE INDEX IF NOT EXISTS idx_contacts_priority ON emergency_contacts(user_id, priority);

-- 3. Emergency Events Table
CREATE TABLE IF NOT EXISTS emergency_events (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    event_type VARCHAR(30) NOT NULL, -- SOS, SAFE_WALK, CHECKIN
    status VARCHAR(30) DEFAULT 'ACTIVE' NOT NULL, -- ACTIVE, RESOLVED, CANCELLED
    client_event_uuid VARCHAR(100) UNIQUE,
    started_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL,
    ended_at TIMESTAMPTZ,
    cancellation_reason VARCHAR(255)
);

CREATE INDEX IF NOT EXISTS idx_events_user_status ON emergency_events(user_id, status);
CREATE INDEX IF NOT EXISTS idx_events_active ON emergency_events(status) WHERE status = 'ACTIVE';

-- 4. Location Updates Table
CREATE TABLE IF NOT EXISTS location_updates (
    id BIGSERIAL PRIMARY KEY,
    emergency_event_id BIGINT NOT NULL REFERENCES emergency_events(id) ON DELETE CASCADE,
    latitude DECIMAL(10, 7) NOT NULL,
    longitude DECIMAL(10, 7) NOT NULL,
    accuracy DECIMAL(6, 2), -- Accuracy radius in meters
    recorded_at TIMESTAMPTZ NOT NULL,
    synced_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_location_event_time ON location_updates(emergency_event_id, recorded_at DESC);

-- 5. Safe Journeys Table
CREATE TABLE IF NOT EXISTS safe_journeys (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    destination VARCHAR(255) NOT NULL,
    start_lat DECIMAL(10, 7),
    start_lng DECIMAL(10, 7),
    dest_lat DECIMAL(10, 7),
    dest_lng DECIMAL(10, 7),
    expected_arrival TIMESTAMPTZ NOT NULL,
    grace_period_minutes INT DEFAULT 5 NOT NULL,
    status VARCHAR(30) DEFAULT 'ACTIVE' NOT NULL, -- ACTIVE, COMPLETED, OVERDUE, ESCALATED, CANCELLED
    started_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL,
    completed_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_journeys_user_status ON safe_journeys(user_id, status);
CREATE INDEX IF NOT EXISTS idx_journeys_active_arrival ON safe_journeys(status, expected_arrival) WHERE status = 'ACTIVE';

-- 6. Check-ins Table
CREATE TABLE IF NOT EXISTS checkins (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    scheduled_time TIMESTAMPTZ NOT NULL,
    grace_period_minutes INT DEFAULT 5 NOT NULL,
    status VARCHAR(30) DEFAULT 'PENDING' NOT NULL, -- PENDING, COMPLETED, MISSED, ESCALATED
    last_prompted_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_checkins_user_status ON checkins(user_id, status);
CREATE INDEX IF NOT EXISTS idx_checkins_pending_time ON checkins(status, scheduled_time) WHERE status = 'PENDING';

-- 7. Incidents Table (Evidence & Records)
CREATE TABLE IF NOT EXISTS incidents (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    emergency_event_id BIGINT REFERENCES emergency_events(id) ON DELETE SET NULL,
    description TEXT,
    has_audio BOOLEAN DEFAULT FALSE NOT NULL,
    has_photo BOOLEAN DEFAULT FALSE NOT NULL,
    local_file_uri VARCHAR(500),
    is_encrypted BOOLEAN DEFAULT TRUE NOT NULL,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_incidents_user ON incidents(user_id);

-- 8. Subscriptions Table
CREATE TABLE IF NOT EXISTS subscriptions (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    product_id VARCHAR(100) NOT NULL,
    status VARCHAR(30) DEFAULT 'ACTIVE' NOT NULL, -- ACTIVE, EXPIRED, CANCELLED
    expiry_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_subscriptions_user ON subscriptions(user_id);

-- 9. Notification Deliveries Table (Multi-Channel Audit & Status Tracking)
CREATE TABLE IF NOT EXISTS notification_deliveries (
    id BIGSERIAL PRIMARY KEY,
    emergency_event_id BIGINT REFERENCES emergency_events(id) ON DELETE CASCADE,
    recipient_phone VARCHAR(20) NOT NULL,
    channel VARCHAR(30) NOT NULL, -- NATIVE_SMS, GATEWAY_SMS, FCM_PUSH
    status VARCHAR(30) DEFAULT 'PENDING' NOT NULL, -- PENDING, SENT, DELIVERED, FAILED
    provider_ref VARCHAR(100),
    error_message TEXT,
    sent_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_deliveries_event ON notification_deliveries(emergency_event_id);
CREATE INDEX IF NOT EXISTS idx_deliveries_status ON notification_deliveries(status);

-- 10. Audit Logs Table (Administrative & Sensitive Action Logs)
CREATE TABLE IF NOT EXISTS audit_logs (
    id BIGSERIAL PRIMARY KEY,
    actor_id VARCHAR(100) NOT NULL,
    action VARCHAR(100) NOT NULL,
    resource_type VARCHAR(100) NOT NULL,
    resource_id VARCHAR(100),
    details TEXT,
    timestamp TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_audit_logs_timestamp ON audit_logs(timestamp DESC);
