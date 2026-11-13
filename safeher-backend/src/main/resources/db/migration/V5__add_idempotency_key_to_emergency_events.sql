-- Migration V5: Add idempotency_key column and index to emergency_events for idempotent SOS start
ALTER TABLE emergency_events ADD COLUMN IF NOT EXISTS idempotency_key VARCHAR(100);

-- Backfill idempotency_key from client_event_uuid for existing rows if any
UPDATE emergency_events SET idempotency_key = client_event_uuid WHERE idempotency_key IS NULL AND client_event_uuid IS NOT NULL;

-- Create composite index on user_id and idempotency_key for fast idempotency lookups
CREATE INDEX IF NOT EXISTS idx_events_user_idempotency ON emergency_events(user_id, idempotency_key);
