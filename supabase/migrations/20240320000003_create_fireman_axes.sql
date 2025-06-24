-- Create fireman_axes table
CREATE TABLE fireman_axes (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    floor_id UUID REFERENCES floors(id) ON DELETE CASCADE,
    status TEXT NOT NULL,
    note TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

-- Add RLS policies
ALTER TABLE fireman_axes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Enable read access for all users" ON fireman_axes
    FOR SELECT USING (true);

CREATE POLICY "Enable insert for authenticated users only" ON fireman_axes
    FOR INSERT WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Enable update for authenticated users only" ON fireman_axes
    FOR UPDATE USING (auth.role() = 'authenticated');

CREATE POLICY "Enable delete for authenticated users only" ON fireman_axes
    FOR DELETE USING (auth.role() = 'authenticated');

-- Create trigger for updated_at
CREATE TRIGGER set_updated_at
    BEFORE UPDATE ON fireman_axes
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column(); 