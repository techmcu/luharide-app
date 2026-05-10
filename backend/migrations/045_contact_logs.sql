-- Contact logs: tracks when passengers click call/whatsapp on union drivers
CREATE TABLE IF NOT EXISTS contact_logs (
    id BIGSERIAL PRIMARY KEY,
    caller_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    driver_id INT NOT NULL REFERENCES union_drivers(id) ON DELETE CASCADE,
    union_id UUID NOT NULL REFERENCES unions(id) ON DELETE CASCADE,
    contact_type VARCHAR(10) NOT NULL CHECK (contact_type IN ('call', 'whatsapp')),
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_contact_logs_union ON contact_logs(union_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_contact_logs_driver ON contact_logs(driver_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_contact_logs_caller_driver ON contact_logs(caller_id, driver_id, created_at DESC);
