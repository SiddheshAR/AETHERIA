CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

ALTER DATABASE aetheria SET timezone TO 'UTC';

DO $$
BEGIN
  RAISE NOTICE 'Aetheria DB initialized!';
END $$;
