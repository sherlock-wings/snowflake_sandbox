# What is this document? 

This document is meant to provide a clear definition of what "Read" access means in this data project. This definition will be expressed both in plain english and as executable SQL Statements.

# Plain-Language Definition

A) "Read" access means you generally have the ability to read from or use existing objects, but you may not alter existing objects in any way. You also may not create new objects of your own.  

B) As with all access on this Data Project, access is granted at the **schema level**. So, anyone with "Read" access will have that acces in the context of a specific schema.

Unlike with Read-write access, there are not many fine details with this definition. So long as an object exists within a schema, and you have "Read" access on that schema, you can read from or use any existing object without altering it.

# SQL Definition

```
-- Create and Grant Privileges to Access Role DEV_EDW_DB_MODEL_R_AR
USE ROLE USERADMIN;

-- Instantiate role and the environment SYSADMIN's inheritance of it
CREATE ROLE IF NOT EXISTS <read_access_role_name>;
GRANT ROLE <read_access_role_name> TO ROLE <environment_sysadmin_role_name>;

USE ROLE SECURITYADMIN;

-- Schema access
GRANT USAGE ON DATABASE "DEV_EDW_DB" TO ROLE <read_access_role_name>;
GRANT USAGE ON SCHEMA "DEV_EDW_DB"."MODEL" TO ROLE <read_access_role_name>;

-- Table access
GRANT SELECT ON ALL TABLES IN SCHEMA "DEV_EDW_DB"."MODEL" TO ROLE <read_access_role_name>;
GRANT SELECT ON FUTURE TABLES IN SCHEMA "DEV_EDW_DB"."MODEL" TO ROLE <read_access_role_name>;

-- View access
GRANT SELECT ON ALL VIEWS IN SCHEMA "DEV_EDW_DB"."MODEL" TO ROLE <read_access_role_name>;
GRANT SELECT ON FUTURE VIEWS IN SCHEMA "DEV_EDW_DB"."MODEL" TO ROLE <read_access_role_name>;
GRANT SELECT ON ALL MATERIALIZED VIEWS IN SCHEMA "DEV_EDW_DB"."MODEL" TO ROLE <read_access_role_name>;
GRANT SELECT ON FUTURE MATERIALIZED VIEWS IN SCHEMA "DEV_EDW_DB"."MODEL" TO ROLE <read_access_role_name>;

-- Sequence access
GRANT USAGE ON ALL SEQUENCES IN SCHEMA "DEV_EDW_DB"."MODEL" TO ROLE <read_access_role_name>;
GRANT USAGE ON FUTURE SEQUENCES IN SCHEMA "DEV_EDW_DB"."MODEL" TO ROLE <read_access_role_name>;

-- Stage access
GRANT USAGE ON ALL STAGES IN SCHEMA "DEV_EDW_DB"."MODEL" TO ROLE <read_access_role_name>;
GRANT READ ON ALL STAGES IN SCHEMA "DEV_EDW_DB"."MODEL" TO ROLE <read_access_role_name>;
GRANT USAGE ON FUTURE STAGES IN SCHEMA "DEV_EDW_DB"."MODEL" TO ROLE <read_access_role_name>;
GRANT READ ON FUTURE STAGES IN SCHEMA "DEV_EDW_DB"."MODEL" TO ROLE <read_access_role_name>;

-- File format access
GRANT USAGE ON ALL FILE FORMATS IN SCHEMA "DEV_EDW_DB"."MODEL" TO ROLE <read_access_role_name>;
GRANT USAGE ON FUTURE FILE FORMATS IN SCHEMA "DEV_EDW_DB"."MODEL" TO ROLE <read_access_role_name>;

-- Stream access
GRANT SELECT ON ALL STREAMS IN SCHEMA "DEV_EDW_DB"."MODEL" TO ROLE <read_access_role_name>;
GRANT SELECT ON FUTURE STREAMS IN SCHEMA "DEV_EDW_DB"."MODEL" TO ROLE <read_access_role_name>;

-- Sproc access
GRANT USAGE ON ALL PROCEDURES IN SCHEMA "DEV_EDW_DB"."MODEL" TO ROLE <read_access_role_name>;
GRANT USAGE ON FUTURE PROCEDURES IN SCHEMA "DEV_EDW_DB"."MODEL" TO ROLE <read_access_role_name>;

-- UDF access
GRANT USAGE ON ALL FUNCTIONS IN SCHEMA "DEV_EDW_DB"."MODEL" TO ROLE <read_access_role_name>;
GRANT USAGE ON FUTURE FUNCTIONS IN SCHEMA "DEV_EDW_DB"."MODEL" TO ROLE <read_access_role_name>;
```
