/*
THIS SCRIPT IS AS DESTRUCTIVE AS IT GETS.

AFTER THIS SCRIPT RUNS, EVERYTHING YOU HAVE IN YOUR ACCOUNT IS GONE. 

DO NOT RUN THIS UNLESS YOU KNOW WHAT YOU ARE DOING.

YOU HAVE BEEN WARNED.
*/
use role accountadmin;

drop database if exists prod_edw_db;
drop database if exists qa_edw_db;
drop database if exists dev_edw_db;
drop database if exists sandbox_edw_db;
drop database if exists sherlockwings_edw_db;

drop role if exists sherlockwings_sysadmin;
drop role if exists sandbox_sysadmin;
drop role if exists dev_sysadmin;
drop role if exists qa_sysadmin;
drop role if exists prod_sysadmin;

drop warehouse if exists sherlockwings_compute_wh;
drop warehouse if exists sandbox_compute_wh;
drop warehouse if exists dev_compute_wh;
drop warehouse if exists qa_compute_wh;
drop warehouse if exists prod_compute_wh;

drop role if exists sherlockwings_admin_fr;
drop role if exists sherlockwings_engineer_fr;

drop role if exists sandbox_admin_fr;
drop role if exists sandbox_engineer_fr;

drop role if exists dev_admin_fr;
drop role if exists dev_engineer_fr;
drop role if exists dev_svctransform_fr;
drop role if exists dev_analyst_fr;

drop role if exists qa_admin_fr;
drop role if exists qa_engineer_fr;
drop role if exists qa_svctransform_fr;
drop role if exists qa_analyst_fr;

drop role if exists qa_svctransform_fr;
drop role if exists qa_analyst_fr;

drop role if exists sherlockwings_edw_db_util_r_ar;
drop role if exists sherlockwings_edw_db_util_rw_ar;
drop role if exists sherlockwings_edw_db_util_full_ar;

drop role if exists sherlockwings_compute_wh_u_ar;
drop role if exists sherlockwings_compute_wh_uw_ar;
drop role if exists sherlockwings_compute_wh_o_ar;

drop role if exists sandbox_edw_db_r_ar;
drop role if exists sandbox_edw_db_rw_ar;
drop role if exists sandbox_edw_db_full_ar;

drop role if exists sandbox_compute_wh_u_ar;
drop role if exists sandbox_compute_wh_uw_ar;
drop role if exists sandbox_compute_wh_o_ar;

drop role if exists dev_edw_db_raw_r_ar;
drop role if exists dev_edw_db_raw_rw_ar;
drop role if exists dev_edw_db_raw_full_ar;

drop role if exists dev_edw_db_stage_r_ar;
drop role if exists dev_edw_db_stage_rw_ar;
drop role if exists dev_edw_db_stage_full_ar;

drop role if exists dev_edw_db_model_r_ar;
drop role if exists dev_edw_db_model_rw_ar;
drop role if exists dev_edw_db_model_full_ar;

drop role if exists dev_compute_wh_u_ar;
drop role if exists dev_compute_wh_uw_ar;
drop role if exists dev_compute_wh_o_ar;

drop role if exists qa_edw_db_raw_r_ar;
drop role if exists qa_edw_db_raw_rw_ar;
drop role if exists qa_edw_db_raw_full_ar;

drop role if exists qa_edw_db_stage_r_ar;
drop role if exists qa_edw_db_stage_rw_ar;
drop role if exists qa_edw_db_stage_full_ar;

drop role if exists qa_edw_db_model_r_ar;
drop role if exists qa_edw_db_model_rw_ar;
drop role if exists qa_edw_db_model_full_ar;

drop role if exists qa_compute_wh_u_ar;
drop role if exists qa_compute_wh_uw_ar;
drop role if exists qa_compute_wh_o_ar;

drop role if exists prod_edw_db_raw_r_ar;
drop role if exists prod_edw_db_raw_rw_ar;
drop role if exists prod_edw_db_raw_full_ar;

drop role if exists prod_edw_db_stage_r_ar;
drop role if exists prod_edw_db_stage_rw_ar;
drop role if exists prod_edw_db_stage_full_ar;

drop role if exists prod_edw_db_model_r_ar;
drop role if exists prod_edw_db_model_rw_ar;
drop role if exists prod_edw_db_model_full_ar;

drop role if exists prod_compute_wh_u_ar;
drop role if exists prod_compute_wh_uw_ar;
drop role if exists prod_compute_wh_o_ar;