-- Test fixture: DPDPA-compliant schema.

CREATE TABLE users (
  id BIGSERIAL PRIMARY KEY,
  full_name TEXT NOT NULL,
  contact TEXT NOT NULL UNIQUE,
  is_child BOOLEAN NOT NULL DEFAULT FALSE, -- Section 9: child accounts get differential rules
  parental_consent_verified BOOLEAN NOT NULL DEFAULT FALSE, -- Rule 10
  nominee TEXT,                            -- Section 14: nomination
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE consent_log (
  id BIGSERIAL PRIMARY KEY,
  user_id BIGINT NOT NULL REFERENCES users(id),
  purpose TEXT NOT NULL,
  consent_version TEXT NOT NULL,
  consent_expiry TIMESTAMPTZ,
  withdrawn BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE grievances (
  id BIGSERIAL PRIMARY KEY,
  user_id BIGINT NOT NULL REFERENCES users(id),
  subject TEXT NOT NULL,
  request_status TEXT NOT NULL DEFAULT 'open',
  due_at TIMESTAMPTZ NOT NULL, -- Rule 14(3): respond within 90 days
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
