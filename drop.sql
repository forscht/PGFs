-- Dropping the functions
DROP FUNCTION IF EXISTS stat(TEXT);
DROP FUNCTION IF EXISTS ls(TEXT);
DROP FUNCTION IF EXISTS tree(TEXT);
DROP FUNCTION IF EXISTS touch(TEXT, VARCHAR);
DROP FUNCTION IF EXISTS mkdir(TEXT);
DROP FUNCTION IF EXISTS mv(TEXT, TEXT);
DROP FUNCTION IF EXISTS rm(TEXT);
DROP FUNCTION IF EXISTS reset();
DROP FUNCTION IF EXISTS parseroot(TEXT);
DROP FUNCTION IF EXISTS validfname(TEXT);
DROP FUNCTION IF EXISTS sanitizefpath(TEXT, BOOL, TEXT);

-- Dropping the indexes
DROP INDEX IF EXISTS idx_fs_parent;
DROP INDEX IF EXISTS idx_fs_name;

-- Dropping the table
DROP TABLE IF EXISTS fs CASCADE;
DROP TABLE IF EXISTS node;
DROP TABLE IF EXISTS schema_migrations;
