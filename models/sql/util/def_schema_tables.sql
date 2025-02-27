use role sherlockwings_admin_fr;
use warehouse sherlockwings_compute_wh;
use schema sherlockwings_edw_db.util;

create or replace table def_schema_read (
 command_id varchar(40)
,command_ordinal number(10)
,command_text varchar(1000)
,access_type varchar(10)
,first_time_setup_ind boolean
,created_at_timestamp timestamp_ltz(9)
,created_by_user varchar(150)
,updated_at_timestamp timestamp_ltz(9)
,updated_by_user varchar(150)
);


create or replace table def_schema_readwrite like def_schema_read;
create or replace table def_schema_full like def_schema_read;


/* STOP SCRIPT HERE. UPLOAD DATA FROM CSV. 
   See project dir root/RBAC/access_definitions/on_schema/def_sources/

   Uncomment the below AFTER uploading!   
*/




-- update def_schema_read
-- set command_id = sha1(command_text)
--    ,created_at_timestamp = current_timestamp()
--    ,created_by_user = current_user();


-- update def_schema_readwrite
-- set command_id = sha1(command_text)
--    ,created_at_timestamp = current_timestamp()
--    ,created_by_user = current_user();

   
-- update def_schema_full
-- set command_id = sha1(command_text)
--    ,created_at_timestamp = current_timestamp()
--    ,created_by_user = current_user();
