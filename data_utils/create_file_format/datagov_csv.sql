use role dev_admin_fr;
use schema dev_edw_db.raw;

create or replace file format datagov_csv 
type = csv
FIELD_DELIMITER  = ','
skip_header = 1
null_if = ('NULL', 'null')
empty_field_as_null = true
compression = gzip
field_optionally_enclosed_by = '"';
