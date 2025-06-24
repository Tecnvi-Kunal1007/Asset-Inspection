-- Modify engine_inspections table to remove auth.users references
ALTER TABLE engine_inspections
    DROP CONSTRAINT IF EXISTS engine_inspections_created_by_fkey,
    DROP CONSTRAINT IF EXISTS engine_inspections_updated_by_fkey;

-- Add new columns without foreign key constraints
ALTER TABLE engine_inspections
    ADD COLUMN IF NOT EXISTS created_by_new UUID,
    ADD COLUMN IF NOT EXISTS updated_by_new UUID;

-- Copy data from old columns to new ones
UPDATE engine_inspections
SET created_by_new = created_by,
    updated_by_new = updated_by;

-- Drop old columns
ALTER TABLE engine_inspections
    DROP COLUMN IF EXISTS created_by,
    DROP COLUMN IF EXISTS updated_by;

-- Rename new columns to original names
ALTER TABLE engine_inspections
    RENAME COLUMN created_by_new TO created_by,
    RENAME COLUMN updated_by_new TO updated_by; 