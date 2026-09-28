-- V4 Add updated_at column to emergency_events if missing
ALTER TABLE emergency_events
ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL;
