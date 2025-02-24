use role sysadmin;
use schema sherlock_wings.util;

create table if not exists user_procedure_query_history (
 log_id varchar(40)
,logged_timestamp timestamp_tz(9)
,user_name varchar(150)
,role_name varchar(150)
,statement varchar
,procedure_name varchar(150)
);
