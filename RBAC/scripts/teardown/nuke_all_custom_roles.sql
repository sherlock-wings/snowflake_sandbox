/*
WARNING: THIS SCRIPT IS DESCTRUCTIVE. IT IS DESIGNED TO DESTROY ALL CUSTOM RBAC CONFIGURATIONS ON THIS PROJECT.
RUNNING THIS MEANS ANY USER WHO DID NOT ORIGINALLY CREATE THE SNOWFLAKE ACCOUNT NO LONGER HAS ACCESS POST-EXECUTION.

To restore your Snowflake account's Custom RBAC, rerun the script under root/RBAC/scripts/`04 - RBAC.sql`
*/

use role securityadmin;

-- UTIL
    -- sysadmin
    -- engineer
    -- full ARs
    -- RW ARs
    -- R ARs
drop role if exists util_sysadmin;
drop role if exists util_engineer_fr;
drop role if exists sherlock_wings_util_rw_ar;
grant ownership on all tables in schema sherlock_wings.util to role securityadmin revoke current grants;
grant ownership on all procedures in schema sherlock_wings.util to role securityadmin revoke current grants;
grant ownership on schema sherlock_wings.util to role securityadmin revoke current grants;
grant ownership on database sherlock_wings to role securityadmin revoke current grants;


-- SANDBOX
    -- sysadmin
    -- engineer
    -- full ARs
    -- RW ARs
    -- R ARs
drop role if exists sandbox_sysadmin;
drop role if exists sandbox_engineer_fr;
drop role if exists sandbox_edw_db_full_ar;
grant ownership on all tables in schema sandbox_edw_db.raw to role securityadmin revoke current grants;
grant ownership on all file formats in schema sandbox_edw_db.raw to role securityadmin revoke current grants;
grant ownership on schema sandbox_edw_db.raw to role securityadmin revoke current grants;
grant ownership on database sandbox_edw_db to role securityadmin revoke current grants;

    -- warehouses
drop role if exists sandbox_compute_wh_full_ar;
grant ownership on warehouse sandbox_compute_wh to role securityadmin revoke current grants;

-- DEV
    -- sysadmin
    -- admin
    -- engineer
    -- svctransform
    -- analyst
    -- full ARs
    -- RW ARs
    -- R ARs
drop role if exists dev_sysadmin;
drop role if exists dev_admin_fr;
drop role if exists dev_engineer_fr;
drop role if exists dev_analyst_fr;
drop role if exists dev_edw_db_model_full_ar;
drop role if exists dev_edw_db_model_r_ar;
drop role if exists dev_edw_db_model_rw_ar;
drop role if exists dev_edw_db_stage_r_ar;
drop role if exists dev_edw_db_stage_rw_ar;
drop role if exists dev_edw_db_stage_full_ar;
drop role if exists dev_edw_db_raw_full_ar;
drop role if exists dev_edw_db_raw_r_ar;
drop role if exists dev_edw_db_raw_rw_ar;

    -- warehouses
drop role if exists dev_compute_wh_u_ar;
drop role if exists dev_compute_wh_um_ar;
drop role if exists dev_compute_wh_full_ar;
grant ownership on warehouse dev_compute_wh to role securityadmin revoke current grants;


-- QA
    -- sysadmin
    -- admin
    -- engineer
    -- svctransform
    -- analyst
    -- full ARs
    -- RW ARs
    -- R ARs

drop role if exists qa_sysadmin;
drop role if exists qa_admin_fr;
drop role if exists qa_engineer_fr;
drop role if exists qa_analyst_fr;
drop role if exists qa_edw_db_model_full_ar;
drop role if exists qa_edw_db_model_r_ar;
drop role if exists qa_edw_db_model_rw_ar;
drop role if exists qa_edw_db_stage_r_ar;
drop role if exists qa_edw_db_stage_rw_ar;
drop role if exists qa_edw_db_stage_full_ar;
drop role if exists qa_edw_db_raw_full_ar;
drop role if exists qa_edw_db_raw_r_ar;
drop role if exists qa_edw_db_raw_rw_ar;

    -- warehouses
drop role if exists qa_compute_wh_u_ar;
drop role if exists qa_compute_wh_um_ar;
drop role if exists qa_compute_wh_full_ar;
grant ownership on warehouse qa_compute_wh to role securityadmin revoke current grants;
    
-- PROD
    -- sysadmin
    -- admin
    -- engineer
    -- svctransform
    -- analyst
    -- full ARs
    -- RW ARs
    -- R ARs

drop role if exists prod_sysadmin;
drop role if exists prod_admin_fr;
drop role if exists prod_engineer_fr;
drop role if exists prod_analyst_fr;
drop role if exists prod_edw_db_model_full_ar;
drop role if exists prod_edw_db_model_r_ar;
drop role if exists prod_edw_db_model_rw_ar;
drop role if exists prod_edw_db_stage_r_ar;
drop role if exists prod_edw_db_stage_rw_ar;
drop role if exists prod_edw_db_stage_full_ar;
drop role if exists prod_edw_db_raw_full_ar;
drop role if exists prod_edw_db_raw_r_ar;
drop role if exists prod_edw_db_raw_rw_ar;

    -- warehouses
drop role if exists prod_compute_wh_u_ar;
drop role if exists prod_compute_wh_um_ar;
drop role if exists prod_compute_wh_full_ar;
grant ownership on warehouse prod_compute_wh to role securityadmin revoke current grants;

