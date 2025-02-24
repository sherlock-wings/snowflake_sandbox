--
-- DEV Environment
--

USE ROLE USERADMIN;
CREATE ROLE IF NOT EXISTS "DEV_ADMIN_FR";
GRANT ROLE "DEV_ADMIN_FR" TO ROLE "DEV_SYSADMIN";
CREATE ROLE IF NOT EXISTS "DEV_ANALYST_FR";
GRANT ROLE "DEV_ANALYST_FR" TO ROLE "DEV_SYSADMIN";
CREATE ROLE IF NOT EXISTS "DEV_ENGINEER_FR";
GRANT ROLE "DEV_ENGINEER_FR" TO ROLE "DEV_SYSADMIN";

--
-- PROD Environment
--

USE ROLE USERADMIN;
CREATE ROLE IF NOT EXISTS "PROD_ADMIN_FR";
GRANT ROLE "PROD_ADMIN_FR" TO ROLE "PROD_SYSADMIN";
CREATE ROLE IF NOT EXISTS "PROD_ANALYST_FR";
GRANT ROLE "PROD_ANALYST_FR" TO ROLE "PROD_SYSADMIN";
CREATE ROLE IF NOT EXISTS "PROD_ENGINEER_FR";
GRANT ROLE "PROD_ENGINEER_FR" TO ROLE "PROD_SYSADMIN";

--
-- QA Environment
--

USE ROLE USERADMIN;
CREATE ROLE IF NOT EXISTS "QA_ADMIN_FR";
GRANT ROLE "QA_ADMIN_FR" TO ROLE "QA_SYSADMIN";
CREATE ROLE IF NOT EXISTS "QA_ANALYST_FR";
GRANT ROLE "QA_ANALYST_FR" TO ROLE "QA_SYSADMIN";
CREATE ROLE IF NOT EXISTS "QA_ENGINEER_FR";
GRANT ROLE "QA_ENGINEER_FR" TO ROLE "QA_SYSADMIN";