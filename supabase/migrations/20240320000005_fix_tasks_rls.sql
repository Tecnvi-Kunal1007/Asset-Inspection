-- Temporarily disable RLS on the tasks table to resolve the immediate issue
ALTER TABLE IF EXISTS "public"."tasks" DISABLE ROW LEVEL SECURITY;

-- Drop existing policies if any
DROP POLICY IF EXISTS "Enable all operations for authenticated users" ON "public"."tasks";
DROP POLICY IF EXISTS "Allow contractors to manage tasks" ON "public"."tasks";
DROP POLICY IF EXISTS "Allow assigned users to view and update tasks" ON "public"."tasks";

-- Create a simple policy that allows all authenticated users to perform all operations
-- This is a temporary solution until a more restrictive policy can be implemented
CREATE POLICY "Enable all operations for authenticated users"
ON "public"."tasks"
FOR ALL
TO authenticated
USING (true);

-- Note: This is a temporary solution. In a production environment,
-- you should implement more restrictive policies based on user roles. 