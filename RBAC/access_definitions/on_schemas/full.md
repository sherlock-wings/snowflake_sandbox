# What is this document? 

This document is meant to provide a clear definition of what "Full" access to a schema means in this data project. This definition will be expressed both in plain english and as executable SQL Statements. For more context on access rights, what they mean, and how they are used in this project, see the project README.

# "Full" Schema Access: Plain-Language Definition

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



# "Full" Schema Access: SQL Definition

```
USE ROLE USERADMIN;

-- Instantiate role and the environment SYSADMIN's inheritance of it
CREATE ROLE IF NOT EXISTS <full_access_role_name>;
GRANT ROLE <full_access_role_name> TO ROLE <environment-sysadmin-role-name>;

USE ROLE SECURITYADMIN;

-- Schema access
GRANT USAGE ON DATABASE <database_name> TO ROLE <full_access_role_name>;
GRANT USAGE ON SCHEMA <schema_name> TO ROLE <full_access_role_name>;

-- Table access
GRANT OWNERSHIP ON ALL TABLES IN SCHEMA <schema_name> TO ROLE <full_access_role_name> COPY CURRENT GRANTS;
GRANT OWNERSHIP ON FUTURE TABLES IN SCHEMA <schema_name> TO ROLE <full_access_role_name>;
GRANT INSERT ON ALL TABLES IN SCHEMA <schema_name> TO ROLE <full_access_role_name>;
GRANT UPDATE ON ALL TABLES IN SCHEMA <schema_name> TO ROLE <full_access_role_name>;
GRANT DELETE ON ALL TABLES IN SCHEMA <schema_name> TO ROLE <full_access_role_name>;
GRANT REFERENCES ON ALL TABLES IN SCHEMA <schema_name> TO ROLE <full_access_role_name>;
GRANT INSERT ON FUTURE TABLES IN SCHEMA <schema_name> TO ROLE <full_access_role_name>;
GRANT UPDATE ON FUTURE TABLES IN SCHEMA <schema_name> TO ROLE <full_access_role_name>;
GRANT DELETE ON FUTURE TABLES IN SCHEMA <schema_name> TO ROLE <full_access_role_name>;
GRANT REFERENCES ON FUTURE TABLES IN SCHEMA <schema_name> TO ROLE <full_access_role_name>;


-- View access
GRANT OWNERSHIP ON ALL VIEWS IN SCHEMA <schema_name> TO ROLE <full_access_role_name> COPY CURRENT GRANTS;
GRANT OWNERSHIP ON FUTURE VIEWS IN SCHEMA <schema_name> TO ROLE <full_access_role_name>;
GRANT OWNERSHIP ON ALL MATERIALIZED VIEWS IN SCHEMA <schema_name> TO ROLE <full_access_role_name> COPY CURRENT GRANTS;
GRANT OWNERSHIP ON FUTURE MATERIALIZED VIEWS IN SCHEMA <schema_name> TO ROLE <full_access_role_name>;


-- Sequence access
GRANT OWNERSHIP ON ALL SEQUENCES IN SCHEMA <schema_name> TO ROLE <full_access_role_name> COPY CURRENT GRANTS;
GRANT OWNERSHIP ON FUTURE SEQUENCES IN SCHEMA <schema_name> TO ROLE <full_access_role_name>;

-- Stage access
GRANT OWNERSHIP ON ALL STAGES IN SCHEMA <schema_name> TO ROLE <full_access_role_name> COPY CURRENT GRANTS;
GRANT OWNERSHIP ON FUTURE STAGES IN SCHEMA <schema_name> TO ROLE <full_access_role_name>;
GRANT WRITE ON FUTURE STAGES IN SCHEMA <schema_name> TO ROLE <full_access_role_name>;
GRANT WRITE ON ALL STAGES IN SCHEMA <schema_name> TO ROLE <full_access_role_name>;

-- File format access
GRANT OWNERSHIP ON ALL FILE FORMATS IN SCHEMA <schema_name> TO ROLE <full_access_role_name> COPY CURRENT GRANTS;
GRANT OWNERSHIP ON FUTURE FILE FORMATS IN SCHEMA <schema_name> TO ROLE <full_access_role_name>;

-- Stream access
GRANT OWNERSHIP ON ALL STREAMS IN SCHEMA <schema_name> TO ROLE <full_access_role_name> COPY CURRENT GRANTS;
GRANT OWNERSHIP ON FUTURE STREAMS IN SCHEMA <schema_name> TO ROLE <full_access_role_name>;

-- Sproc access
GRANT OWNERSHIP ON ALL PROCEDURES IN SCHEMA <schema_name> TO ROLE <full_access_role_name> COPY CURRENT GRANTS;
GRANT OWNERSHIP ON FUTURE PROCEDURES IN SCHEMA <schema_name> TO ROLE <full_access_role_name>;

-- UDF Access
GRANT OWNERSHIP ON ALL FUNCTIONS IN SCHEMA <schema_name> TO ROLE <full_access_role_name> COPY CURRENT GRANTS;
GRANT OWNERSHIP ON FUTURE FUNCTIONS IN SCHEMA <schema_name> TO ROLE <full_access_role_name>;

-- Task access
GRANT OWNERSHIP ON ALL TASKS IN SCHEMA <schema_name> TO ROLE <full_access_role_name> COPY CURRENT GRANTS;
GRANT OWNERSHIP ON FUTURE TASKS IN SCHEMA <schema_name> TO ROLE <full_access_role_name>;
GRANT MONITOR ON ALL TASKS IN SCHEMA <schema_name> TO ROLE <full_access_role_name>;
GRANT OPERATE ON ALL TASKS IN SCHEMA <schema_name> TO ROLE <full_access_role_name>;
GRANT MONITOR ON FUTURE TASKS IN SCHEMA <schema_name> TO ROLE <full_access_role_name>;
GRANT OPERATE ON FUTURE TASKS IN SCHEMA <schema_name> TO ROLE <full_access_role_name>;
GRANT MONITOR ON FUTURE TASKS IN SCHEMA <schema_name> TO ROLE <full_access_role_name>;
GRANT OPERATE ON FUTURE TASKS IN SCHEMA <schema_name> TO ROLE <full_access_role_name>;
```
