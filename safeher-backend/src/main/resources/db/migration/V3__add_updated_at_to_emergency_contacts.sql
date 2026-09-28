-- V3 Add updated_at column to emergency_contacts if missing
ALTER TABLE emergency_contacts
ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL;
