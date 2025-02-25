# What is this document? 

This document is meant to provide a clear definition of what "Full" access means in this data project. This definition will be expressed both in plain english and as executable SQL Statements.

## Context

This project uses Role-based Access Control (RBAC) by creating many *access roles*. An access role grants its holder with "Read" Access, "Read-Write" Access, or "Full" access, depending on the role. 

So if you had one schema caleld `EDW_DB.RAW`, for example, you could have three access roles for that:
1. `EDW_DB_RAW_R_AR` ("Read" access role)
1. `EDW_DB_RAW_RW_AR` ("Read-Write" access role)
1. `EDW_DB_RAW_FULL_AR` ("Full" access role)

Each of these roles are combined to create *Functional Roles* (ex. `DEV_ENGINEER_FR`), which can have highly-configurable privileges. The flexibility these roles have is achieved by granting one or more access roles to a functional role. 

# "Full" Access: Plain-Language Definition

- "Full" access means you generally have the ability to utilize all features that your Account Administrator has approved for usage
    - Note that this does not mean you can automatically do anything. You are only able to create a [Snowpipe](https://docs.snowflake.com/en/user-guide/data-load-snowpipe-intro) or [Iceberg table](https://docs.snowflake.com/en/user-guide/tables-iceberg), for example, if your Account Admin has already approved usage of these objects in general
- It also means that you have direct or indirect `OWNERSHIP` on schema objects in most cases
- As with all access on this Data Project, access is granted at the **schema level**. So, anyone with "Full" access will have that acces in the context of a specific schema.

The details of this definition are object-specific and are enumerated below.


## Tables

For all of the below table types, you have `OWNERSHIP`. You may do any DDL or DML against any table with these types:
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

For all of the below view types, you have `OWNERSHIP`. You may do any DDL or DML against any view with these types:
1. Standard
2. [Materialized](https://docs.snowflake.com/en/user-guide/views-materialized)


## Other objects you own and can read/write with

For all of the below object types, you have `OWNERSHIP`. You may do any DDL or DML against any object with these types:
1. [Sequences](https://docs.snowflake.com/en/user-guide/querying-sequences)
2. [File formats](https://docs.snowflake.com/en/sql-reference/sql/create-file-format)
3. [Streams](https://docs.snowflake.com/en/user-guide/streams-intro)
4. [Stored Procedures](https://docs.snowflake.com/en/developer-guide/stored-procedure/stored-procedures-usage)
5. [Functions (a.k.a. UDFs)](https://docs.snowflake.com/en/developer-guide/udf/udf-overview)
6. [Tasks](https://docs.snowflake.com/en/user-guide/tasks-intro)


## Other Objects you can NOT read/write with
1. [Pipes](https://docs.snowflake.com/en/user-guide/data-load-snowpipe-intro)
2. [Masking Policies](https://docs.snowflake.com/user-guide/security-column-ddm-intro)
3. [Row-Access Policies](https://docs.snowflake.com/en/user-guide/security-row-intro)
4. [External Functions](https://docs.snowflake.com/en/sql-reference/external-functions-introduction)
5. [Tags](https://docs.snowflake.com/en/user-guide/object-tagging)



# "Full" Access: SQL Definition

```
USE ROLE USERADMIN;

-- Instantiate role and the environment SYSADMIN's inheritance of it
CREATE ROLE IF NOT EXISTS "DEV_EDW_DB_MODEL_FULL_AR";
GRANT ROLE "DEV_EDW_DB_MODEL_FULL_AR" TO ROLE "DEV_SYSADMIN";

USE ROLE SECURITYADMIN;

-- Schema access
GRANT USAGE ON DATABASE "DEV_EDW_DB" TO ROLE "DEV_EDW_DB_MODEL_FULL_AR";
GRANT USAGE ON SCHEMA "DEV_EDW_DB"."MODEL" TO ROLE "DEV_EDW_DB_MODEL_FULL_AR";

-- Table access
GRANT OWNERSHIP ON ALL TABLES IN SCHEMA "DEV_EDW_DB"."MODEL" TO ROLE "DEV_EDW_DB_MODEL_FULL_AR" COPY CURRENT GRANTS;
GRANT OWNERSHIP ON FUTURE TABLES IN SCHEMA "DEV_EDW_DB"."MODEL" TO ROLE "DEV_EDW_DB_MODEL_FULL_AR";
GRANT INSERT ON ALL TABLES IN SCHEMA "DEV_EDW_DB"."MODEL" TO ROLE "DEV_EDW_DB_MODEL_FULL_AR";
GRANT UPDATE ON ALL TABLES IN SCHEMA "DEV_EDW_DB"."MODEL" TO ROLE "DEV_EDW_DB_MODEL_FULL_AR";
GRANT DELETE ON ALL TABLES IN SCHEMA "DEV_EDW_DB"."MODEL" TO ROLE "DEV_EDW_DB_MODEL_FULL_AR";
GRANT REFERENCES ON ALL TABLES IN SCHEMA "DEV_EDW_DB"."MODEL" TO ROLE "DEV_EDW_DB_MODEL_FULL_AR";
GRANT INSERT ON FUTURE TABLES IN SCHEMA "DEV_EDW_DB"."MODEL" TO ROLE "DEV_EDW_DB_MODEL_FULL_AR";
GRANT UPDATE ON FUTURE TABLES IN SCHEMA "DEV_EDW_DB"."MODEL" TO ROLE "DEV_EDW_DB_MODEL_FULL_AR";
GRANT DELETE ON FUTURE TABLES IN SCHEMA "DEV_EDW_DB"."MODEL" TO ROLE "DEV_EDW_DB_MODEL_FULL_AR";
GRANT REFERENCES ON FUTURE TABLES IN SCHEMA "DEV_EDW_DB"."MODEL" TO ROLE "DEV_EDW_DB_MODEL_FULL_AR";


-- View access
GRANT OWNERSHIP ON ALL VIEWS IN SCHEMA "DEV_EDW_DB"."MODEL" TO ROLE "DEV_EDW_DB_MODEL_FULL_AR" COPY CURRENT GRANTS;
GRANT OWNERSHIP ON FUTURE VIEWS IN SCHEMA "DEV_EDW_DB"."MODEL" TO ROLE "DEV_EDW_DB_MODEL_FULL_AR";
GRANT OWNERSHIP ON ALL MATERIALIZED VIEWS IN SCHEMA "DEV_EDW_DB"."MODEL" TO ROLE "DEV_EDW_DB_MODEL_FULL_AR" COPY CURRENT GRANTS;
GRANT OWNERSHIP ON FUTURE MATERIALIZED VIEWS IN SCHEMA "DEV_EDW_DB"."MODEL" TO ROLE "DEV_EDW_DB_MODEL_FULL_AR";


-- Sequence access
GRANT OWNERSHIP ON ALL SEQUENCES IN SCHEMA "DEV_EDW_DB"."MODEL" TO ROLE "DEV_EDW_DB_MODEL_FULL_AR" COPY CURRENT GRANTS;
GRANT OWNERSHIP ON FUTURE SEQUENCES IN SCHEMA "DEV_EDW_DB"."MODEL" TO ROLE "DEV_EDW_DB_MODEL_FULL_AR";

-- Stage access
GRANT OWNERSHIP ON ALL STAGES IN SCHEMA "DEV_EDW_DB"."MODEL" TO ROLE "DEV_EDW_DB_MODEL_FULL_AR" COPY CURRENT GRANTS;
GRANT OWNERSHIP ON FUTURE STAGES IN SCHEMA "DEV_EDW_DB"."MODEL" TO ROLE "DEV_EDW_DB_MODEL_FULL_AR";
GRANT WRITE ON FUTURE STAGES IN SCHEMA "DEV_EDW_DB"."MODEL" TO ROLE "DEV_EDW_DB_MODEL_FULL_AR";
GRANT WRITE ON ALL STAGES IN SCHEMA "DEV_EDW_DB"."MODEL" TO ROLE "DEV_EDW_DB_MODEL_FULL_AR";

-- File format access
GRANT OWNERSHIP ON ALL FILE FORMATS IN SCHEMA "DEV_EDW_DB"."MODEL" TO ROLE "DEV_EDW_DB_MODEL_FULL_AR" COPY CURRENT GRANTS;
GRANT OWNERSHIP ON FUTURE FILE FORMATS IN SCHEMA "DEV_EDW_DB"."MODEL" TO ROLE "DEV_EDW_DB_MODEL_FULL_AR";

-- Stream access
GRANT OWNERSHIP ON ALL STREAMS IN SCHEMA "DEV_EDW_DB"."MODEL" TO ROLE "DEV_EDW_DB_MODEL_FULL_AR" COPY CURRENT GRANTS;
GRANT OWNERSHIP ON FUTURE STREAMS IN SCHEMA "DEV_EDW_DB"."MODEL" TO ROLE "DEV_EDW_DB_MODEL_FULL_AR";

-- Sproc access
GRANT OWNERSHIP ON ALL PROCEDURES IN SCHEMA "DEV_EDW_DB"."MODEL" TO ROLE "DEV_EDW_DB_MODEL_FULL_AR" COPY CURRENT GRANTS;
GRANT OWNERSHIP ON FUTURE PROCEDURES IN SCHEMA "DEV_EDW_DB"."MODEL" TO ROLE "DEV_EDW_DB_MODEL_FULL_AR";

-- UDF Access
GRANT OWNERSHIP ON ALL FUNCTIONS IN SCHEMA "DEV_EDW_DB"."MODEL" TO ROLE "DEV_EDW_DB_MODEL_FULL_AR" COPY CURRENT GRANTS;
GRANT OWNERSHIP ON FUTURE FUNCTIONS IN SCHEMA "DEV_EDW_DB"."MODEL" TO ROLE "DEV_EDW_DB_MODEL_FULL_AR";

-- Task access
GRANT OWNERSHIP ON ALL TASKS IN SCHEMA "DEV_EDW_DB"."MODEL" TO ROLE "DEV_EDW_DB_MODEL_FULL_AR" COPY CURRENT GRANTS;
GRANT OWNERSHIP ON FUTURE TASKS IN SCHEMA "DEV_EDW_DB"."MODEL" TO ROLE "DEV_EDW_DB_MODEL_FULL_AR";
GRANT MONITOR ON ALL TASKS IN SCHEMA "DEV_EDW_DB"."MODEL" TO ROLE "DEV_EDW_DB_MODEL_FULL_AR";
GRANT OPERATE ON ALL TASKS IN SCHEMA "DEV_EDW_DB"."MODEL" TO ROLE "DEV_EDW_DB_MODEL_FULL_AR";
GRANT MONITOR ON FUTURE TASKS IN SCHEMA "DEV_EDW_DB"."MODEL" TO ROLE "DEV_EDW_DB_MODEL_FULL_AR";
GRANT OPERATE ON FUTURE TASKS IN SCHEMA "DEV_EDW_DB"."MODEL" TO ROLE "DEV_EDW_DB_MODEL_FULL_AR";
GRANT MONITOR ON FUTURE TASKS IN SCHEMA "DEV_EDW_DB"."MODEL" TO ROLE "DEV_EDW_DB_MODEL_FULL_AR";
GRANT OPERATE ON FUTURE TASKS IN SCHEMA "DEV_EDW_DB"."MODEL" TO ROLE "DEV_EDW_DB_MODEL_FULL_AR";
```
