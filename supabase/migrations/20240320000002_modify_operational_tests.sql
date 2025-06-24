-- Remove floor_id from operational_tests table
ALTER TABLE operational_tests
    DROP CONSTRAINT IF EXISTS operational_tests_floor_id_fkey,
    DROP COLUMN IF EXISTS floor_id;

-- Drop the index that includes floor_id
DROP INDEX IF EXISTS idx_operational_tests_site_floor;

-- Create a new index for site_id only
CREATE INDEX idx_operational_tests_site ON operational_tests(site_id); 