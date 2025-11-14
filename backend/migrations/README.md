# Database Migrations

This directory contains SQL migration files for the art.kubus backend database.

## Migration Files

### 008_wallet_address_schema.sql ⭐ **CURRENT PRODUCTION SCHEMA**
**Wallet Address Schema (Updated)**
- Creates/updates `collections` table with `wallet_address` (instead of `owner_id`)
- Creates/updates `notifications` table with `user_wallet`, `sender_wallet` (instead of `user_id`, `sender_id`)
- Creates/updates `search_history` table with `user_wallet` (instead of `user_id`)
- Creates `collection_artworks` junction table
- Includes migration logic to convert from UUID-based schema to wallet_address schema
- Auto-updates triggers for collection counts and timestamps
- Full-text search indexes on collections

**Run (Fresh Installation):**
```bash
# For Docker container:
docker exec -i artkubus-postgres psql -U artkubus -d artkubus < migrations/008_wallet_address_schema.sql

# For direct PostgreSQL:
psql -U artkubus -d artkubus -f migrations/008_wallet_address_schema.sql
```

**Run (Existing Database - with UUID schema):**
```bash
# This migration includes conversion logic:
docker exec -i artkubus-postgres psql -U artkubus -d artkubus < migrations/008_wallet_address_schema.sql
# It will automatically:
# - Add wallet_address columns
# - Migrate data from user_id/owner_id to wallet addresses
# - Drop old UUID columns
# - Rename artwork_count → artworks_count, thumbnail_url → cover_image_url
```

**Verification:**
```bash
# Check table structures
docker exec -i artkubus-postgres psql -U artkubus -d artkubus -c "\d collections"
docker exec -i artkubus-postgres psql -U artkubus -d artkubus -c "\d notifications"
docker exec -i artkubus-postgres psql -U artkubus -d artkubus -c "\d search_history"

# Check indexes
docker exec -i artkubus-postgres psql -U artkubus -d artkubus -c "SELECT indexname FROM pg_indexes WHERE tablename IN ('collections', 'notifications', 'search_history') ORDER BY tablename, indexname;"
```

**Rollback:**
```bash
docker exec -i artkubus-postgres psql -U artkubus -d artkubus -c "DROP TABLE IF EXISTS collection_artworks CASCADE;"
docker exec -i artkubus-postgres psql -U artkubus -d artkubus -c "DROP TABLE IF EXISTS collections CASCADE;"
docker exec -i artkubus-postgres psql -U artkubus -d artkubus -c "DROP TABLE IF EXISTS notifications CASCADE;"
docker exec -i artkubus-postgres psql -U artkubus -d artkubus -c "DROP TABLE IF EXISTS search_history CASCADE;"
```

---

### 005_collections.sql ⚠️ **DEPRECATED - Use 008 instead**
**Old Collections Schema (UUID-based)**
- Uses `owner_id` foreign key to `users(id)`
- Column names: `artwork_count`, `thumbnail_url`
- **DO NOT USE** - Replaced by 008_wallet_address_schema.sql

---

### 006_notifications.sql ⚠️ **DEPRECATED - Use 008 instead**
**Old Notifications Schema (UUID-based)**
- Uses `user_id`, `sender_id` foreign keys to `users(id)`
- **DO NOT USE** - Replaced by 008_wallet_address_schema.sql

---

### 007_search_indexes.sql ⚠️ **DEPRECATED - Use 008 instead**
**Old Search History Schema (UUID-based)**
- Uses `user_id` foreign key
- **DO NOT USE** - Replaced by 008_wallet_address_schema.sql

---

## Running Migrations

**Fresh Installation (New Server):**
```bash
cd backend

# 1. Ensure PostgreSQL has uuid-ossp extension
docker exec -i artkubus-postgres psql -U artkubus -d artkubus -c "CREATE EXTENSION IF NOT EXISTS \"uuid-ossp\";"

# 2. Run base schema (001-004) - if you have them
# psql -d artkubus -f migrations/001_init.sql
# ... etc

# 3. Run wallet address schema (current production schema)
docker exec -i artkubus-postgres psql -U artkubus -d artkubus < migrations/008_wallet_address_schema.sql

# 4. Verify tables were created
docker exec -i artkubus-postgres psql -U artkubus -d artkubus -c "\dt"
docker exec -i artkubus-postgres psql -U artkubus -d artkubus -c "SELECT tablename FROM pg_tables WHERE schemaname='public' AND tablename IN ('collections', 'collection_artworks', 'notifications', 'search_history');"
```

**Upgrading Existing Database (UUID schema → Wallet Address schema):**
```bash
cd backend

# 1. Backup database first!
docker exec artkubus-postgres pg_dump -U artkubus artkubus > backup_$(date +%Y%m%d_%H%M%S).sql

# 2. Run migration (includes automatic conversion)
docker exec -i artkubus-postgres psql -U artkubus -d artkubus < migrations/008_wallet_address_schema.sql

# 3. Verify migration
docker exec -i artkubus-postgres psql -U artkubus -d artkubus -c "\d collections"
docker exec -i artkubus-postgres psql -U artkubus -d artkubus -c "\d notifications"

# 4. Check that old columns are gone
docker exec -i artkubus-postgres psql -U artkubus -d artkubus -c "SELECT column_name FROM information_schema.columns WHERE table_name='collections' AND column_name IN ('owner_id', 'artwork_count', 'thumbnail_url');"
# Should return 0 rows

# 5. Restart backend to use new schema
docker-compose restart backend
```

**Production Deployment:**
```bash
cd backend

# 1. Always backup before production migrations!
pg_dump -U postgres art_kubus_prod > backup_$(date +%Y%m%d_%H%M%S).sql

# 2. Test migration on staging first
psql -U postgres -d art_kubus_staging -f migrations/008_wallet_address_schema.sql

# 3. Run on production (in transaction)
psql -U postgres -d art_kubus_prod << EOF
BEGIN;
\i migrations/008_wallet_address_schema.sql
-- Verify critical tables
SELECT COUNT(*) FROM collections;
SELECT COUNT(*) FROM notifications;
-- If all looks good:
COMMIT;
-- If there are issues:
-- ROLLBACK;
EOF

# 4. Verify
psql -U postgres -d art_kubus_prod -c "\dt"
psql -U postgres -d art_kubus_prod -c "\di+"
```

---

## Verification Commands

**Check if tables exist:**
```bash
docker exec -i artkubus-postgres psql -U artkubus -d artkubus -c "SELECT tablename FROM pg_tables WHERE schemaname='public' AND tablename IN ('collections', 'collection_artworks', 'notifications', 'search_history');"
```

**Check table structures (verify wallet_address columns):**
```bash
# Collections table
docker exec -i artkubus-postgres psql -U artkubus -d artkubus -c "SELECT column_name, data_type FROM information_schema.columns WHERE table_name='collections' ORDER BY ordinal_position;"

# Notifications table
docker exec -i artkubus-postgres psql -U artkubus -d artkubus -c "SELECT column_name, data_type FROM information_schema.columns WHERE table_name='notifications' ORDER BY ordinal_position;"

# Search history table
docker exec -i artkubus-postgres psql -U artkubus -d artkubus -c "SELECT column_name, data_type FROM information_schema.columns WHERE table_name='search_history' ORDER BY ordinal_position;"
```

**Check indexes:**
```bash
docker exec -i artkubus-postgres psql -U artkubus -d artkubus -c "SELECT indexname, indexdef FROM pg_indexes WHERE tablename IN ('collections', 'notifications', 'search_history') ORDER BY tablename, indexname;"
```

**Check triggers:**
```bash
docker exec -i artkubus-postgres psql -U artkubus -d artkubus -c "SELECT tgname, tgrelid::regclass, tgtype FROM pg_trigger WHERE tgrelid::regclass::text IN ('collections', 'collection_artworks', 'notifications') AND tgisinternal = false;"
```

**Check foreign key constraints:**
```bash
docker exec -i artkubus-postgres psql -U artkubus -d artkubus -c "SELECT conname, conrelid::regclass, confrelid::regclass FROM pg_constraint WHERE conrelid::regclass::text IN ('collections', 'collection_artworks', 'notifications', 'search_history');"
```

**Verify data migration (if upgrading from UUID schema):**
```bash
# Check that wallet addresses were populated
docker exec -i artkubus-postgres psql -U artkubus -d artkubus -c "SELECT COUNT(*) as total, COUNT(wallet_address) as with_wallet FROM collections;"
docker exec -i artkubus-postgres psql -U artkubus -d artkubus -c "SELECT COUNT(*) as total, COUNT(user_wallet) as with_wallet FROM notifications;"

# Check that old columns are gone
docker exec -i artkubus-postgres psql -U artkubus -d artkubus -c "SELECT column_name FROM information_schema.columns WHERE table_name='collections' AND column_name IN ('owner_id', 'artwork_count', 'thumbnail_url');"
# Should return 0 rows

docker exec -i artkubus-postgres psql -U artkubus -d artkubus -c "SELECT column_name FROM information_schema.columns WHERE table_name='notifications' AND column_name IN ('user_id', 'sender_id');"
# Should return 0 rows
```

---

## Migration Best Practices

1. **Always backup before running migrations:**
   ```bash
   pg_dump -U postgres art_kubus_prod > backup.sql
   ```

2. **Run migrations in order:**
   - Migrations have dependencies (e.g., search indexes depend on collections table)
   - Run 005 → 006 → 007 in sequence

3. **Test on development first:**
   - Never run untested migrations on production
   - Verify data integrity after migration

4. **Use transactions for complex migrations:**
   ```sql
   BEGIN;
   -- Your migration SQL here
   COMMIT;  -- or ROLLBACK if errors
   ```

5. **Check for existing objects:**
   - Migrations use `IF NOT EXISTS` to prevent errors
   - Safe to re-run if migration was partially applied

---

## Troubleshooting

**Error: extension "uuid-ossp" does not exist**
- Solution: Enable extension first:
  ```bash
  docker exec -i artkubus-postgres psql -U artkubus -d artkubus -c 'CREATE EXTENSION IF NOT EXISTS "uuid-ossp";'
  ```

**Error: relation "users" does not exist**
- Solution: Run base schema migrations first (001-004)
- Or temporarily disable foreign key checks during development

**Error: column "owner_id" does not exist**
- You're running old migration (005_collections.sql) - use 008_wallet_address_schema.sql instead

**Error: column "user_id" does not exist**
- You're running old migration (006_notifications.sql) - use 008_wallet_address_schema.sql instead

**Error: permission denied**
- Solution: Run as superuser or grant proper permissions:
  ```bash
  docker exec -i artkubus-postgres psql -U postgres -d artkubus -f migrations/008_wallet_address_schema.sql
  ```

**Migration ran but data wasn't migrated**
- Check if users table has wallet_address column:
  ```bash
  docker exec -i artkubus-postgres psql -U artkubus -d artkubus -c "\d users"
  ```
- Migration only works if users.wallet_address exists and is populated

**Slow search performance**
- Check if GIN indexes were created:
  ```bash
  docker exec -i artkubus-postgres psql -U artkubus -d artkubus -c "SELECT indexname, indexdef FROM pg_indexes WHERE indexdef LIKE '%gin%';"
  ```

**Backend routes returning "column does not exist" errors**
- Verify column names match migration:
  - ✅ `artworks_count` (not `artwork_count`)
  - ✅ `cover_image_url` (not `thumbnail_url`)
  - ✅ `user_wallet` (not `user_id`)
  - ✅ `sender_wallet` (not `sender_id`)
- Check backend/src/routes/ files match the schema

---

## Migration History

| Migration | Date | Description | Status |
|-----------|------|-------------|--------|
| 008_wallet_address_schema.sql | 2025-11-14 | **CURRENT** - Collections, notifications, search with wallet_address | ✅ Production |
| 005_collections.sql | 2025-11-14 | DEPRECATED - Old UUID-based collections | ❌ Replaced |
| 006_notifications.sql | 2025-11-14 | DEPRECATED - Old UUID-based notifications | ❌ Replaced |
| 007_search_indexes.sql | 2025-11-14 | DEPRECATED - Old UUID-based search | ❌ Replaced |

---

## Schema Evolution

### Why Wallet Address Schema?

The original schema (005-007) used UUID foreign keys (`user_id`, `owner_id`) to link to the `users` table. This was changed to use `wallet_address` strings directly for several reasons:

1. **Blockchain Integration**: Wallet addresses are the primary identifier in Solana blockchain
2. **Simpler Authentication**: JWT tokens carry `walletAddress`, not user UUIDs
3. **Performance**: Eliminates JOIN with users table in many queries
4. **Flexibility**: Users can exist with just a wallet address (no full profile required)

### Migration Path

If you have existing data with UUID-based schema:
1. Run 008_wallet_address_schema.sql
2. It automatically migrates data from `user_id` → `user_wallet`
3. Old columns are dropped after successful migration
4. All triggers and indexes are recreated

### Column Name Changes

| Old Name | New Name | Table |
|----------|----------|-------|
| `owner_id` | `wallet_address` | collections |
| `artwork_count` | `artworks_count` | collections |
| `thumbnail_url` | `cover_image_url` | collections |
| `user_id` | `user_wallet` | notifications |
| `sender_id` | `sender_wallet` | notifications |
| `user_id` | `user_wallet` | search_history |

---

## Related Documentation

- API Endpoints: `docs/COLLECTIONS_NOTIFICATIONS_SEARCH_IMPLEMENTATION.md`
- Backend Routes: `backend/src/routes/`
- Flutter Integration: `lib/services/backend_api_service.dart`

---

**Contact:** For migration issues, contact Rok Černezel (Founder & Lead Developer)
