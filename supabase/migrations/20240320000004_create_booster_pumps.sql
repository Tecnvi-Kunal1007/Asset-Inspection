-- Create booster_pumps table
CREATE TABLE booster_pumps (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    floor_id UUID REFERENCES floors(id) ON DELETE CASCADE,
    status TEXT NOT NULL,
    note TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

-- Create trigger for updated_at
CREATE TRIGGER set_updated_at
    BEFORE UPDATE ON booster_pumps
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column(); 