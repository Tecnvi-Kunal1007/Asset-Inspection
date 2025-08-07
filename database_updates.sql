-- Database Schema Updates for Assignment System
-- Run these queries in your Supabase SQL editor

-- 1. Add assignments column to premises table
ALTER TABLE premises 
ADD COLUMN IF NOT EXISTS assignments JSONB DEFAULT '{}';

-- 2. Add assignments column to sections table  
ALTER TABLE sections 
ADD COLUMN IF NOT EXISTS assignments JSONB DEFAULT '{}';

-- 3. Add assignments column to subsections table
ALTER TABLE subsections 
ADD COLUMN IF NOT EXISTS assignments JSONB DEFAULT '{}';

-- 4. Create indexes for better performance on assignment queries
CREATE INDEX IF NOT EXISTS idx_premises_assignments ON premises USING GIN (assignments);
CREATE INDEX IF NOT EXISTS idx_sections_assignments ON sections USING GIN (assignments);
CREATE INDEX IF NOT EXISTS idx_subsections_assignments ON subsections USING GIN (assignments);

-- 5. Create a function to sync assignments from premises to sections and subsections
CREATE OR REPLACE FUNCTION sync_premise_assignments()
RETURNS TRIGGER AS $$
BEGIN
    -- Update all sections under this premise with the same assignments
    UPDATE sections 
    SET assignments = NEW.assignments 
    WHERE premise_id = NEW.id;
    
    -- Update all subsections under sections of this premise with the same assignments
    UPDATE subsections 
    SET assignments = NEW.assignments 
    WHERE section_id IN (
        SELECT id FROM sections WHERE premise_id = NEW.id
    );
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 6. Create trigger to automatically sync assignments
DROP TRIGGER IF EXISTS trigger_sync_premise_assignments ON premises;
CREATE TRIGGER trigger_sync_premise_assignments
    AFTER UPDATE OF assignments ON premises
    FOR EACH ROW
    EXECUTE FUNCTION sync_premise_assignments();

-- 7. Create a view for easy assignment reporting
CREATE OR REPLACE VIEW assignment_overview AS
SELECT 
    p.id as premise_id,
    p.name as premise_name,
    p.contractor_id,
    p.assignments as premise_assignments,
    s.id as section_id,
    s.name as section_name,
    s.assignments as section_assignments,
    sub.id as subsection_id,
    sub.name as subsection_name,
    sub.assignments as subsection_assignments,
    c.name as contractor_name
FROM premises p
LEFT JOIN sections s ON p.id = s.premise_id
LEFT JOIN subsections sub ON s.id = sub.section_id
LEFT JOIN contractor c ON p.contractor_id = c.id
WHERE p.assignments IS NOT NULL AND p.assignments != '{}';

-- 8. Create function to get all assignments for a contractor
CREATE OR REPLACE FUNCTION get_contractor_assignments(contractor_uuid UUID)
RETURNS TABLE (
    premise_id UUID,
    premise_name TEXT,
    section_id UUID,
    section_name TEXT,
    subsection_id UUID,
    subsection_name TEXT,
    freelancer_id TEXT,
    freelancer_name TEXT,
    assignment_type TEXT,
    assigned_date TIMESTAMP
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        p.id::UUID as premise_id,
        p.name as premise_name,
        s.id::UUID as section_id,
        s.name as section_name,
        sub.id::UUID as subsection_id,
        sub.name as subsection_name,
        (jsonb_each_text(p.assignments)).key as freelancer_id,
        (jsonb_each_text(p.assignments)).value as freelancer_name,
        'premise' as assignment_type,
        p.created_at as assigned_date
    FROM premises p
    LEFT JOIN sections s ON p.id::TEXT = s.premise_id
    LEFT JOIN subsections sub ON s.id::TEXT = sub.section_id
    WHERE p.contractor_id::TEXT = contractor_uuid::TEXT
    AND p.assignments IS NOT NULL 
    AND p.assignments != '{}';
END;
$$ LANGUAGE plpgsql;

-- 9. Create function to assign freelancer to premise
CREATE OR REPLACE FUNCTION assign_freelancer_to_premise(
    premise_uuid UUID,
    freelancer_uuid UUID,
    freelancer_name_param TEXT,
    assignment_tasks TEXT[]
)
RETURNS BOOLEAN AS $$
DECLARE
    current_assignments JSONB;
    new_assignment JSONB;
BEGIN
    -- Get current assignments
    SELECT assignments INTO current_assignments 
    FROM premises 
    WHERE id = premise_uuid;
    
    -- If assignments is null, initialize as empty object
    IF current_assignments IS NULL THEN
        current_assignments := '{}';
    END IF;
    
    -- Create new assignment object
    new_assignment := jsonb_build_object(
        'freelancer_id', freelancer_uuid::TEXT,
        'freelancer_name', freelancer_name_param,
        'tasks', array_to_json(assignment_tasks),
        'assigned_date', NOW()
    );
    
    -- Add or update the assignment
    current_assignments := current_assignments || jsonb_build_object(freelancer_uuid::TEXT, new_assignment);
    
    -- Update the premise
    UPDATE premises 
    SET assignments = current_assignments 
    WHERE id = premise_uuid;
    
    RETURN TRUE;
EXCEPTION
    WHEN OTHERS THEN
        RETURN FALSE;
END;
$$ LANGUAGE plpgsql;

-- 10. Create function to remove assignment
CREATE OR REPLACE FUNCTION remove_freelancer_assignment(
    premise_uuid UUID,
    freelancer_uuid UUID
)
RETURNS BOOLEAN AS $$
DECLARE
    current_assignments JSONB;
BEGIN
    -- Get current assignments
    SELECT assignments INTO current_assignments 
    FROM premises 
    WHERE id = premise_uuid;
    
    -- Remove the freelancer assignment
    current_assignments := current_assignments - freelancer_uuid::TEXT;
    
    -- Update the premise
    UPDATE premises 
    SET assignments = current_assignments 
    WHERE id = premise_uuid;
    
    RETURN TRUE;
EXCEPTION
    WHEN OTHERS THEN
        RETURN FALSE;
END;
$$ LANGUAGE plpgsql;

-- 11. Sample data insertion (optional - for testing)
-- Uncomment the following lines if you want to test with sample data

/*
-- Insert sample assignment
SELECT assign_freelancer_to_premise(
    (SELECT id FROM premises LIMIT 1),
    (SELECT id FROM freelancers LIMIT 1),
    (SELECT name FROM freelancers LIMIT 1),
    ARRAY['fire inspection', 'security check', 'drainage maintenance']
);
*/

-- 12. Grant necessary permissions (adjust as needed for your setup)
-- GRANT SELECT, INSERT, UPDATE, DELETE ON premises TO authenticated;
-- GRANT SELECT, INSERT, UPDATE, DELETE ON sections TO authenticated;
-- GRANT SELECT, INSERT, UPDATE, DELETE ON subsections TO authenticated;
-- GRANT SELECT ON assignment_overview TO authenticated;
-- GRANT EXECUTE ON FUNCTION get_contractor_assignments(UUID) TO authenticated;
-- GRANT EXECUTE ON FUNCTION assign_freelancer_to_premise(UUID, UUID, TEXT, TEXT[]) TO authenticated;
-- GRANT EXECUTE ON FUNCTION remove_freelancer_assignment(UUID, UUID) TO authenticated;

-- End of database updates
