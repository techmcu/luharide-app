-- Add whatsapp_number to users for Chat redirect
ALTER TABLE users ADD COLUMN IF NOT EXISTS whatsapp_number VARCHAR(20);
