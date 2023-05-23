---- list root directory with immediate children
SELECT * FROM ls('/');

---- create new file under root directory
SELECT * FROM touch('/', 'file1');

---- create recursive directories under root. (mkdir -p)
SELECT * FROM mkdir('/data/d1/d2/d3');

---- list all directories under data recursively
SELECT * FROM tree('/data');

---- move from /data/d1/d2/d3 to /data/d3
SELECT * FROM mv('/data/d1/d2/d3', '/data/d3');

---- get file info about /data
SELECT * FROM stat('/data');

---- delete /data/d1 recursively, will delete d2 under /data/d1 as well.
SELECT * FROM rm('/data/d1');

---- reset fs table except root dir record
SELECT * FROM reset();