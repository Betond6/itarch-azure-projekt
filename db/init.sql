CREATE TABLE items (
  id SERIAL PRIMARY KEY,
  name TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now()
);
INSERT INTO items(name) VALUES ('Azure VM'), ('Docker'), ('VNet peering');
