use role securityadmin;

grant usage on procedure sherlockwings_edw_db.util.grant_to_sandbox(varchar) to role sandbox_sysadmin;
grant usage on procedure sherlockwings_edw_db.util.revoke_current_access(varchar, varchar) to role sandbox_sysadmin;
