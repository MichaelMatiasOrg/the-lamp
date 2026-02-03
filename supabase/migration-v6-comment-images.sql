-- Migration v6: Add image_url to comments table
-- Run this in Supabase SQL Editor

-- Add image_url column to comments table
ALTER TABLE comments ADD COLUMN IF NOT EXISTS image_url TEXT;

-- Verify
SELECT column_name, data_type FROM information_schema.columns 
WHERE table_name = 'comments' ORDER BY ordinal_position;
