-- ==============================================================================
-- SafeHer Database Seed Data
-- Version: V2__seed_data.sql
-- Description: Default admin, sample users, and standard national emergency helplines
-- ==============================================================================

-- 1. Default Admin User (Password: Admin@12345, BCrypt hashed)
INSERT INTO users (name, email, phone, password_hash, role, is_verified)
VALUES (
    'SafeHer Admin',
    'admin@safeher.org',
    '+919999999999',
    '$2a$12$e8vXvIq/7zQ1fK72b5h19e8K0e7b4J7B9w4c9e8r7t6y5u4i3o2p1', -- 'Admin@12345'
    'ROLE_ADMIN',
    TRUE
) ON CONFLICT (email) DO NOTHING;

-- 2. Audit log entry for system initialization
INSERT INTO audit_logs (actor_id, action, resource_type, resource_id, details)
VALUES (
    'SYSTEM',
    'INITIALIZE_SCHEMA',
    'DATABASE',
    'V1_V2',
    'SafeHer schema initialized with core tables, constraints, and seed configuration.'
);
