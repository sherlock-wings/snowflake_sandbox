use role dev_admin_fr;
use schema dev_edw_db.raw;

copy into DEV_EDW_DB.RAW.ELECTRIC_VEHICLES
from (
select  
 t.$1
,t.$4
,t.$3
,t.$2
,t.$5
,t.$6
,t.$7
,t.$8
,t.$9
,t.$10
,t.$11
,t.$12
,t.$13
,t.$14
,t.$15
,t.$16
,t.$17
from @csv_stg (file_format => datagov_csv) t
);
