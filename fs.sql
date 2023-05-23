--- PGFs

CREATE TABLE IF NOT EXISTS fs
(
    id     UUID PRIMARY KEY      DEFAULT gen_random_uuid(),
    name   VARCHAR(255) NOT NULL,
    dir    BOOL         NOT NULL DEFAULT FALSE,
    atime  TIMESTAMP    NOT NULL DEFAULT NOW(),
    mtime  TIMESTAMP    NOT NULL DEFAULT NOW(),
    parent UUID REFERENCES fs (id) ON DELETE CASCADE,
    UNIQUE (name, parent) -- This means that in the same directory, two files or directories cannot have the same name.
);

COMMENT ON TABLE fs IS 'The table is designed to store metadata about files and directories in our virtual file system. Here is a detailed breakdown of the columns in the fs table';
COMMENT ON COLUMN fs.id IS 'This column serves as a unique identifier for each file and directory. The UUID is automatically generated by default.';
COMMENT ON COLUMN fs.name IS 'This is a VARCHAR column used to store the name of the file or directory. The maximum length of the name is 255 characters.';
COMMENT ON COLUMN fs.dir IS 'This is a BOOLEAN column that indicates whether the record is a directory.';
COMMENT ON COLUMN fs.atime IS 'This column stores the last access time of the file or directory.';
COMMENT ON COLUMN fs.mtime IS 'This column stores the last modification time of the file or directory.';
COMMENT ON COLUMN fs.parent IS 'This UUID column stores the id of the parent directory of the current file or directory.It has a foreign key constraint referencing the ''id'' column of the same ''fs'' table. when a directory is deleted, all of its contents (files and directories) are also deleted.';



-- Creating index idx_fs_parent on 'parent' column.
-- This index is useful to quickly find all files and directories within a specific parent directory.
CREATE INDEX idx_fs_parent ON fs (parent);
-- Creating index idx_fs_name on 'name' column.
-- This index is useful to quickly find a file or directory by its name.
CREATE INDEX idx_fs_name ON fs (name);



-- Inserting the root directory record into the 'fs' table.
-- The root directory is the top-level directory that does not have any parent directory.
-- Its 'id' is a predefined UUID, 'name' is an empty string, and 'dir' is set to TRUE indicating it's a directory.
INSERT INTO fs (id, name, dir, parent)
VALUES ('11111111-1111-1111-1111-111111111111', '', TRUE, NULL);





-- stat: This function returns the metadata of the file or directory specified by the given file path.
CREATE OR REPLACE FUNCTION stat(filepath TEXT)
    RETURNS TABLE
            (
                ID     UUID,
                NAME   VARCHAR(255),
                PATH   TEXT,
                DIR    BOOL,
                ATIME  TIMESTAMP,
                MTIME  TIMESTAMP,
                PARENT UUID
            )
AS
$$
DECLARE
    _id UUID;
BEGIN
    --- sanitize inputs
    PERFORM validfpath(filepath);

    RETURN QUERY
        WITH RECURSIVE vfs
                           AS
                           (SELECT *, fs.name::TEXT AS path
                            FROM fs
                            WHERE fs.parent IS NULL

                            UNION ALL

                            SELECT f.*, p.path || '/' || f.name AS path
                            FROM fs f
                                     JOIN vfs p ON f.parent = p.id)
        SELECT vfs.id,
               vfs.name,
               parseroot(vfs.path) AS path,
               vfs.dir,
               vfs.atime,
               vfs.mtime,
               vfs.parent
        FROM vfs
        WHERE parseroot(vfs.path) = filepath;
END;
$$ LANGUAGE plpgsql;
COMMENT ON FUNCTION stat IS 'This function returns the metadata of the file or directory specified by the given file path.';





-- ls: The ls function lists the contents of a directory specified by the file path.
-- It uses the stat function to get the UUID of the file path, then a recursive CTE
-- to retrieve the files and directories under the specified directory.
CREATE OR REPLACE FUNCTION ls(filepath TEXT)
    RETURNS TABLE
            (
                ID     UUID,
                NAME   VARCHAR(255),
                PATH   TEXT,
                DIR    BOOL,
                ATIME  TIMESTAMP,
                MTIME  TIMESTAMP,
                PARENT UUID
            )
AS
$$
DECLARE
    _id UUID;
BEGIN
    --- sanitize inputs
    PERFORM validfpath(filepath);

    SELECT s.id
    FROM stat(filepath) AS s
    INTO _id;

    IF _id IS NULL THEN
        RAISE EXCEPTION 'path does not exist' USING ERRCODE = 'D0001';
    END IF;

    IF filepath = '/' THEN
        filepath = '';
    END IF;
    RETURN QUERY
        WITH RECURSIVE vfs
                           AS
                           (SELECT *, filepath AS path
                            FROM fs
                            WHERE fs.id = _id

                            UNION ALL

                            SELECT f.*, p.path || '/' || f.name AS path
                            FROM fs f
                                     JOIN vfs p ON f.parent = p.id AND p.id = _id)
        SELECT vfs.id,
               vfs.name,
               parseroot(vfs.path) AS path,
               vfs.dir,
               vfs.atime,
               vfs.mtime,
               vfs.parent
        FROM vfs;
END;
$$ LANGUAGE plpgsql;
COMMENT ON FUNCTION ls IS 'The ls function lists the contents of a directory specified by the file path.';





-- tree: The tree function returns all files and directories under the specified directory recursively.
-- It works similarly to the ls function, but it does not limit its output to the immediate children.
CREATE OR REPLACE FUNCTION tree(filepath TEXT)
    RETURNS TABLE
            (
                ID     UUID,
                NAME   VARCHAR(255),
                PATH   TEXT,
                DIR    BOOL,
                ATIME  TIMESTAMP,
                MTIME  TIMESTAMP,
                PARENT UUID
            )
AS
$$
DECLARE
    _id UUID;
BEGIN
    --- sanitize inputs
    PERFORM validfpath(filepath);

    SELECT s.id
    FROM stat(filepath) AS s
    INTO _id;

    IF _id IS NULL THEN
        RAISE EXCEPTION 'path does not exist' USING ERRCODE = 'D0001';
    END IF;

    IF filepath = '/' THEN
        filepath = '';
    END IF;
    RETURN QUERY
        WITH RECURSIVE vfs
                           AS
                           (SELECT *, filepath AS path
                            FROM fs
                            WHERE fs.id = _id
                            UNION ALL
                            SELECT f.*, p.path || '/' || f.name AS path
                            FROM fs f
                                     JOIN vfs p ON f.parent = p.id)
        SELECT vfs.id,
               vfs.name,
               parseroot(vfs.path) AS path,
               vfs.dir,
               vfs.atime,
               vfs.mtime,
               vfs.parent
        FROM vfs;
END;
$$ LANGUAGE plpgsql;
COMMENT ON FUNCTION tree IS 'The tree function returns all files and directories under the specified directory recursively.';





-- touch: The touch function is used to create a new file.
-- It takes a file path and a name as parameters,
-- then creates a new file with the provided name in the specified directory.
CREATE OR REPLACE FUNCTION touch(filepath TEXT, fname VARCHAR)
    RETURNS SETOF FS
AS
$$
DECLARE
    _id UUID;
BEGIN
    --- sanitize inputs
    PERFORM validfpath(filepath);
    PERFORM validfname(fname::TEXT);

    SELECT s.id
    FROM stat(filepath) AS s
    INTO _id;

    IF _id IS NULL THEN
        RAISE EXCEPTION 'path does not exist' USING ERRCODE = 'D0001';
    END IF;
    RETURN QUERY INSERT INTO fs (name, dir, parent) VALUES (fname, FALSE, _id) RETURNING *;
END;
$$ LANGUAGE plpgsql;
COMMENT ON FUNCTION touch IS 'This function is used to create a new file.';





-- mkdir: The mkdir function creates a new directory.
-- It creates all the directories in the file path that do not exist already.
CREATE OR REPLACE FUNCTION mkdir(filepath TEXT)
    RETURNS SETOF FS
AS
$$
DECLARE
    _id        UUID;
    _parent_id UUID;
    _path      TEXT[] := STRING_TO_ARRAY(filepath, '/');
    _name      TEXT;
BEGIN
    --- sanitize inputs
    PERFORM validfpath(filepath);
    PERFORM denyroot(filepath, 'mkdir');

    -- Iterates over each part of the path
    FOR i IN 1..ARRAY_LENGTH(_path, 1)
        LOOP
            _name := _path[i];

            -- Tries to find the current part of the path in the parent directory
            SELECT id
            INTO _id
            FROM fs
            WHERE name = _name
              AND (i = 1 OR parent = _parent_id);

            -- If the directory doesn't exist, create it
            IF _id IS NULL THEN
                INSERT INTO fs (name, dir, parent) VALUES (_name, TRUE, _parent_id) RETURNING id INTO _id;
            END IF;

            -- Sets the current directory as the parent for the next loop
            _parent_id := _id;
        END LOOP;

    -- Returns the last directory created
    RETURN QUERY SELECT * FROM fs WHERE id = _id;
END;
$$ LANGUAGE plpgsql;
COMMENT ON FUNCTION mkdir IS 'This function creates a new directory recursively. Equivalent to mkdir -p';





-- mv: The mv function is used to move or rename files or directories.
-- It takes an old file path and a new file path as parameters,
-- and moves the file or directory from the old path to the new path.
CREATE OR REPLACE FUNCTION mv(oldpath TEXT, newpath TEXT)
    RETURNS VOID
AS
$$
DECLARE
    _old_id          UUID;
    _new_parent_id   UUID;
    _new_name        TEXT;
    _new_path        TEXT[] := STRING_TO_ARRAY(newpath, '/');
    _new_parent_path TEXT;
BEGIN
    --- sanitize inputs
    PERFORM validfpath(oldpath);
    PERFORM denyroot(oldpath, 'mv');
    PERFORM validfpath(newpath);
    PERFORM denyroot(newpath, 'mv');

    -- If old path doesn't exist, raise an error
    SELECT s.id
    FROM stat(oldpath) AS s
    INTO _old_id;

    IF _old_id IS NULL THEN
        RAISE EXCEPTION 'old path does not exist' USING ERRCODE = 'D0003';
    END IF;

    -- Split newpath into parent path and name
    _new_name := _new_path[ARRAY_LENGTH(_new_path, 1)];

    -- Construct the parent path manually
    _new_parent_path := '';
    FOR i IN 1..(ARRAY_LENGTH(_new_path, 1) - 1)
        LOOP
            IF _new_path[i] != '' THEN
                _new_parent_path := _new_parent_path || '/' || _new_path[i];
            END IF;
        END LOOP;

    -- If new parent path doesn't exist, raise an error
    SELECT s.id
    FROM stat(_new_parent_path) AS s
    INTO _new_parent_id;

    IF _new_parent_id IS NULL THEN
        RAISE EXCEPTION 'new parent path does not exist' USING ERRCODE = 'D0004';
    END IF;

    -- Update the parent id and name of the old path
    UPDATE fs SET parent = _new_parent_id, name = _new_name WHERE id = _old_id;
END;
$$ LANGUAGE plpgsql;
COMMENT ON FUNCTION mv IS 'The mv function is used to move or rename files or directories.';





-- rm: The rm function is used to delete a file or directory.
-- It takes a file path as a parameter and deletes the file or directory at that path.
CREATE OR REPLACE FUNCTION rm(filepath TEXT)
    RETURNS VOID
AS
$$
DECLARE
    _id UUID;
BEGIN
    --- sanitize inputs
    PERFORM validfpath(filepath);
    PERFORM denyroot(filepath, 'rm');

    SELECT s.id
    FROM stat(filepath) AS s
    INTO _id;

    IF _id IS NULL THEN
        RAISE EXCEPTION 'path does not exist' USING ERRCODE = 'D0001';
    END IF;

    DELETE FROM fs WHERE id = _id;
END;
$$ LANGUAGE plpgsql;
COMMENT ON FUNCTION rm IS 'The rm function is used to delete a file or directory recursively, Equivalent to rm -rf';





-- reset: The reset function deletes all files and directories except the root.
-- It can be useful when you want to reset the state of the filesystem.
CREATE OR REPLACE FUNCTION reset()
    RETURNS VOID
AS
$$
BEGIN
    DELETE FROM fs WHERE parent IS NOT NULL;
END;
$$ LANGUAGE plpgsql;
COMMENT ON FUNCTION rm IS 'This function deletes all files and directories except the root.';




-- parseroot: This function takes a file path as input. If the file path is an empty string,
-- it returns '/', else it returns the file path itself.
CREATE OR REPLACE FUNCTION parseroot(filepath TEXT)
    RETURNS TEXT
AS
$$
BEGIN
    IF filepath = '' THEN
        RETURN '/';
    ELSE
        RETURN filepath;
    END IF;
END;
$$ LANGUAGE plpgsql;




CREATE OR REPLACE FUNCTION validfname(filename TEXT)
    RETURNS VOID
AS
$$
BEGIN
    -- first, check if the filename is not NULL or an empty string.
    -- next, check if it does not start with a space.
    -- then, check if the filename doesn't contain any invalid characters (like /, <, >, :, ", |, ?, or *).
    -- finally, if all conditions are met, return true; otherwise, return false.
    IF filename IS NOT NULL AND filename != '' AND filename !~ '^ ' AND filename !~ '[/<>"\|\?\*]' THEN
    ELSE
        RAISE EXCEPTION 'invalid filename %', filename USING ERRCODE = 'D0005';
    END IF;
END;
$$
    LANGUAGE plpgsql;




CREATE OR REPLACE FUNCTION validfpath(filepath TEXT)
    RETURNS VOID
AS
$$
BEGIN
    -- first, check if the filepath is not NULL or an empty string.
    -- next, ensure it starts with a slash (/).
    -- then, check if it doesn't contain any null characters or any segment starting with a space.
    -- finally, if all conditions are met, return true; otherwise, return false.
    IF filepath IS NOT NULL AND filepath != '' AND filepath ~ '^\/' AND filepath !~ '[\0]' AND
       filepath !~ '(^|/) [^/]*' THEN
    ELSE
        RAISE EXCEPTION 'invalid filepath %', filepath USING ERRCODE = 'D0006';
    END IF;
END;
$$ LANGUAGE plpgsql;




-- if filepath is / (root) then throw exception. useful for function like rm('/')
CREATE OR REPLACE FUNCTION denyroot(filepath TEXT, op TEXT)
    RETURNS VOID
AS
$$
BEGIN
    IF filepath = '/' THEN
        RAISE EXCEPTION 'operation % not allowed on root directory', op USING ERRCODE = 'D0006';
    END IF;
END ;
$$ LANGUAGE plpgsql;