# What is this document? 

This document is meant to provide a clear definition of what "Read" access means in this data project. This definition will be expressed both in plain english and as executable SQL Statements.

## Context

This project applies Role-based Access Control (RBAC) by creating a series of *access roles*, each of which apply to a specific schema. An access role creates the its holder with Read Access, Read-Write Access, or Full access, to the given schema.

So if you had one schema caleld `EDW_DB.RAW`, for example, you could have three access roles for that:
1. `EDW_DB_RAW_R_AR` ("Read" access role)
1. `EDW_DB_RAW_RW_AR` ("Read-Write" access role)
1. `EDW_DB_RAW_FULL_AR` ("Full" access role)

Each of these roles are combined to create *Functional Roles* (ex. `DEV_ENGINEER_FR`), which can have complex and highly-configurable privileges. The flexibility these roles have comes out of the ability to grant (or withhold granting) many access roles to the functional role. 

# "Read" Access: Plain-Language Definition

A) "Read" access means you generally have the ability to read from or use existing objects, but you may not alter existing objects in any way. You also may not create new objects of your own.  

B) As with all access on this Data Project, access is granted at the **schema level**. So, anyone with "Read" access will have that acces in the context of a specific schema.

Unlike with Read-write access, there are not many fine details with this definition. So long as an object exists within a schema, and you have "Read" access on that schema, you can read from or use any existing object without altering it.

# "Read" Access: SQL Definition

```
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
