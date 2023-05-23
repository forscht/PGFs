# PGFs
**PGFs implements a file system using PostgreSQL, adopting the "Adjacency List Model" to store files and directories.**<br>
The aim is to provide a tool that can manipulate a file system like structure (CRUD operations) stored in a Postgres database. The design of this project allows to perform common file system operations like creating files/directories, moving, renaming, and deleting, along with the ability to reset the filesystem. 

### Limitation
It's important to note that the PGFs does not provide an underlying backend to store the actual file data. Instead, it focuses on simulating file system operations and storing metadata in a PostgreSQL database.

PGFs is designed to be used with virtual file systems or libraries like [Afero](https://github.com/spf13/afero) that provide the necessary functionality to handle file data storage, retrieval, and manipulation. These virtual file systems can be integrated with PGFs to leverage the metadata management capabilities provided by the project.
### Database Structure
The `fs` table is used to store the file system's metadata. The structure is as follows:

- **id:** This column serves as a unique identifier for each file and directory.
- **name:** This is used to store the name of the file or directory.
- **dir:** A boolean column that indicates whether the record is a directory.
- **atime:** This column stores the last access time of the file or directory.
- **mtime:** This column stores the last modification time of the file or directory.
- **parent:** This UUID column stores the id of the parent directory of the current file or directory.

### Unix compatible supported operations
```go
// lists the contents of a directory specified by the file path
ls(filepath text) setof fs

// returns the metadata of the file or directory specified by the given file path.
stat(filepath text) setof fs

// creates new file
touch(filepath text, fname text) setof fs 

// creates a new directory recursively. Equivalent to mkdir -p
mkdir(filepath text) setof fs 

// returns all files and directories under the specified directory recursively.
tree(filepath text) setof fs 

// move or rename files or directories.
mv(filepath text, filepath text) void 

// delete a file or directory recursively, Equivalent to rm -rf
rm(filepath text) void 

// deletes all files and directories except the root.
reset() void
```
