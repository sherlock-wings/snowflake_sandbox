# What is this document? 

This document is meant to provide a clear definition of what "Read" access means in this data project. This definition will be expressed both in plain english and as executable SQL Statements. For more context on access rights, what they mean, and how they are used in this project, see `*/RBAC/overall_design.md`.

# "Read" Access: SQL Definition

```
USE ROLE USERADMIN;

-- Instantiate role and the environment SYSADMIN's inheritance of it
CREATE ROLE IF NOT EXISTS <read_access_role_name>;
GRANT ROLE <read_access_role_name> TO ROLE <environment_sysadmin_role_name>;

USE ROLE SECURITYADMIN;

-- Schema access
GRANT USAGE ON DATABASE <database_name> TO ROLE <read_access_role_name>;
GRANT USAGE ON SCHEMA <schema_name> TO ROLE <read_access_role_name>;

-- Table access
GRANT SELECT ON ALL TABLES IN SCHEMA <schema_name> TO ROLE <read_access_role_name>;
GRANT SELECT ON FUTURE TABLES IN SCHEMA <schema_name> TO ROLE <read_access_role_name>;

-- View access
GRANT SELECT ON ALL VIEWS IN SCHEMA <schema_name> TO ROLE <read_access_role_name>;
GRANT SELECT ON FUTURE VIEWS IN SCHEMA <schema_name> TO ROLE <read_access_role_name>;
GRANT SELECT ON ALL MATERIALIZED VIEWS IN SCHEMA <schema_name> TO ROLE <read_access_role_name>;
GRANT SELECT ON FUTURE MATERIALIZED VIEWS IN SCHEMA <schema_name> TO ROLE <read_access_role_name>;

-- Sequence access
GRANT USAGE ON ALL SEQUENCES IN SCHEMA <schema_name> TO ROLE <read_access_role_name>;
GRANT USAGE ON FUTURE SEQUENCES IN SCHEMA <schema_name> TO ROLE <read_access_role_name>;

-- Stage access
GRANT USAGE ON ALL STAGES IN SCHEMA <schema_name> TO ROLE <read_access_role_name>;
GRANT READ ON ALL STAGES IN SCHEMA <schema_name> TO ROLE <read_access_role_name>;
GRANT USAGE ON FUTURE STAGES IN SCHEMA <schema_name> TO ROLE <read_access_role_name>;
GRANT READ ON FUTURE STAGES IN SCHEMA <schema_name> TO ROLE <read_access_role_name>;

-- File format access
GRANT USAGE ON ALL FILE FORMATS IN SCHEMA <schema_name> TO ROLE <read_access_role_name>;
GRANT USAGE ON FUTURE FILE FORMATS IN SCHEMA <schema_name> TO ROLE <read_access_role_name>;

-- Stream access
GRANT SELECT ON ALL STREAMS IN SCHEMA <schema_name> TO ROLE <read_access_role_name>;
GRANT SELECT ON FUTURE STREAMS IN SCHEMA <schema_name> TO ROLE <read_access_role_name>;

-- Sproc access
GRANT USAGE ON ALL PROCEDURES IN SCHEMA <schema_name> TO ROLE <read_access_role_name>;
GRANT USAGE ON FUTURE PROCEDURES IN SCHEMA <schema_name> TO ROLE <read_access_role_name>;

-- UDF access
GRANT USAGE ON ALL FUNCTIONS IN SCHEMA <schema_name> TO ROLE <read_access_role_name>;
GRANT USAGE ON FUTURE FUNCTIONS IN SCHEMA <schema_name> TO ROLE <read_access_role_name>;
```
