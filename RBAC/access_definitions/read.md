# What is this document? 

This document is meant to provide a clear definition of what "ReadWrite" access means in this data project. This definition will be expressed both in plain english and as executable SQL Statements.

# Plain-Language Definition

*As with all access on this Data Project, access is granted at the **schema level**. So, anyone with "Read" access will have that acces in the context of a specific schema.*

"Read" access means you generally have the ability to read from or use existing objects, but you may not alter existing objects in any way. You also may not create new objects of your own. 

## Tables

You may apply any DDL or DML to tables of the following types:
1. Permanent
2. [Transient](https://docs.snowflake.com/en/user-guide/tables-temp-transient)
3. [Temporary](https://docs.snowflake.com/en/user-guide/tables-temp-transient)

***You do not have access*** to the following table types:
1. [External](https://docs.snowflake.com/en/user-guide/tables-external-intro)
2. [Dynamic](https://docs.snowflake.com/en/user-guide/dynamic-tables-intro)
3. [Event](https://docs.snowflake.com/en/developer-guide/logging-tracing/event-table-setting-up)
4. [Hybrid](https://docs.snowflake.com/en/user-guide/tables-hybrid)
5. [Iceberg](https://docs.snowflake.com/en/user-guide/tables-iceberg)

## Views

You may apply any DDL or DML to views of the following types:
1. Standard
2. [Materialized](https://docs.snowflake.com/en/user-guide/views-materialized)

## Other objects you can read/write with

You may also apply any DDL or DML to any of the following objects:
1. [Sequences](https://docs.snowflake.com/en/user-guide/querying-sequences)
2. [File formats](https://docs.snowflake.com/en/sql-reference/sql/create-file-format)
3. [Streams](https://docs.snowflake.com/en/user-guide/streams-intro)
4. [Stored Procedures](https://docs.snowflake.com/en/developer-guide/stored-procedure/stored-procedures-usage)
5. [Functions (a.k.a. UDFs)](https://docs.snowflake.com/en/developer-guide/udf/udf-overview)
6. [Tasks](https://docs.snowflake.com/en/user-guide/tasks-intro)

## Other Objects you can NOT read/write with
1. [Masking Policies](https://docs.snowflake.com/user-guide/security-column-ddm-intro)
2. [Row-Access Policies](https://docs.snowflake.com/en/user-guide/security-row-intro)
3. [External Functions](https://docs.snowflake.com/en/sql-reference/external-functions-introduction)
4. [Tags](https://docs.snowflake.com/en/user-guide/object-tagging)

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
