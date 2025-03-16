# What is this document? 

This document is meant to provide a clear definition of what "Read-Write" access to a schema means in this data project. This definition will be expressed both in plain english and as executable SQL Statements. For more context on access rights, what they mean, and how they are used in this project, see the project README.

# "Read-Write" Schema Access: Plain-Language Definition

- "Read-Write" access means you generally have the ability to read from or use existing objects, as well as create new objects, in a given schema.
- As with all access on this Data Project, access is granted at the **schema level**. So, anyone with "Read-Write" access will have that acces in the context of a specific schema.

The details of this definition are object-specific and are enumerated below.


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
7. [Stages](https://docs.snowflake.com/en/sql-reference/sql/create-stage)
    - Includes Internal stages (named, user, table) and External stages 


## Other Objects you can NOT read/write with
1. [Pipes](https://docs.snowflake.com/en/user-guide/data-load-snowpipe-intro)
2. [Masking Policies](https://docs.snowflake.com/user-guide/security-column-ddm-intro)
3. [Row-Access Policies](https://docs.snowflake.com/en/user-guide/security-row-intro)
4. [External Functions](https://docs.snowflake.com/en/sql-reference/external-functions-introduction)
5. [Tags](https://docs.snowflake.com/en/user-guide/object-tagging)


# "Read-Write" Schema Access: SQL Definition

```
USE ROLE USERADMIN;

-- Instantiate role and the environment SYSADMIN's inheritance of it
CREATE ROLE IF NOT EXISTS <readwrite-access-role-name>;
GRANT ROLE <readwrite-access-role-name> TO ROLE <environment-sysadmin-role-name>;

USE ROLE SECURITYADMIN;

-- Schema access
GRANT USAGE ON DATABASE SHERLOCKWINGS_EDW_DB TO ROLE <readwrite-access-role-name>;
GRANT USAGE ON SCHEMA <schema-name> TO ROLE <readwrite-access-role-name>;
GRANT CREATE TABLE ON SCHEMA <schema-name> TO ROLE <readwrite-access-role-name>;
GRANT CREATE VIEW ON SCHEMA <schema-name> TO ROLE <readwrite-access-role-name>;
GRANT CREATE SEQUENCE ON SCHEMA <schema-name> TO ROLE <readwrite-access-role-name>;
GRANT CREATE STAGE ON SCHEMA <schema-name> TO ROLE <readwrite-access-role-name>;
GRANT CREATE FILE FORMAT ON SCHEMA <schema-name> TO ROLE <readwrite-access-role-name>;
GRANT CREATE STREAM ON SCHEMA <schema-name> TO ROLE <readwrite-access-role-name>;
GRANT CREATE PROCEDURE ON SCHEMA <schema-name> TO ROLE <readwrite-access-role-name>;
GRANT CREATE FUNCTION ON SCHEMA <schema-name> TO ROLE <readwrite-access-role-name>;
GRANT CREATE TASK ON SCHEMA <schema-name> TO ROLE <readwrite-access-role-name>;


-- Table access
GRANT CREATE TABLE ON SCHEMA <schema-name> TO ROLE <readwrite-access-role-name>;
GRANT SELECT ON ALL TABLES IN SCHEMA <schema-name> TO ROLE <readwrite-access-role-name>;
GRANT SELECT ON FUTURE TABLES IN SCHEMA <schema-name> TO ROLE <readwrite-access-role-name>;
GRANT INSERT ON ALL TABLES IN SCHEMA <schema-name> TO ROLE <readwrite-access-role-name>;
GRANT UPDATE ON ALL TABLES IN SCHEMA <schema-name> TO ROLE <readwrite-access-role-name>;
GRANT DELETE ON ALL TABLES IN SCHEMA <schema-name> TO ROLE <readwrite-access-role-name>;
GRANT REFERENCES ON ALL TABLES IN SCHEMA <schema-name> TO ROLE <readwrite-access-role-name>;
GRANT INSERT ON FUTURE TABLES IN SCHEMA <schema-name> TO ROLE <readwrite-access-role-name>;
GRANT UPDATE ON FUTURE TABLES IN SCHEMA <schema-name> TO ROLE <readwrite-access-role-name>;
GRANT DELETE ON FUTURE TABLES IN SCHEMA <schema-name> TO ROLE <readwrite-access-role-name>;
GRANT REFERENCES ON FUTURE TABLES IN SCHEMA <schema-name> TO ROLE <readwrite-access-role-name>;

-- View access
GRANT SELECT ON ALL VIEWS IN SCHEMA <schema-name> TO ROLE <readwrite-access-role-name>;
GRANT SELECT ON FUTURE VIEWS IN SCHEMA <schema-name> TO ROLE <readwrite-access-role-name>;

-- Sequence access
GRANT USAGE ON ALL SEQUENCES IN SCHEMA <schema-name> TO ROLE <readwrite-access-role-name>;
GRANT USAGE ON FUTURE SEQUENCES IN SCHEMA <schema-name> TO ROLE <readwrite-access-role-name>;

-- Stage access
GRANT USAGE ON ALL STAGES IN SCHEMA <schema-name> TO ROLE <readwrite-access-role-name>;
GRANT READ ON ALL STAGES IN SCHEMA <schema-name> TO ROLE <readwrite-access-role-name>;
GRANT USAGE ON FUTURE STAGES IN SCHEMA <schema-name> TO ROLE <readwrite-access-role-name>;
GRANT READ ON FUTURE STAGES IN SCHEMA <schema-name> TO ROLE <readwrite-access-role-name>;
GRANT WRITE ON FUTURE STAGES IN SCHEMA <schema-name> TO ROLE <readwrite-access-role-name>;
GRANT WRITE ON ALL STAGES IN SCHEMA <schema-name> TO ROLE <readwrite-access-role-name>;


-- File format access
GRANT USAGE ON ALL FILE FORMATS IN SCHEMA <schema-name> TO ROLE <readwrite-access-role-name>;
GRANT USAGE ON FUTURE FILE FORMATS IN SCHEMA <schema-name> TO ROLE <readwrite-access-role-name>;

-- Stream access
GRANT SELECT ON ALL STREAMS IN SCHEMA <schema-name> TO ROLE <readwrite-access-role-name>;
GRANT SELECT ON FUTURE STREAMS IN SCHEMA <schema-name> TO ROLE <readwrite-access-role-name>;

-- Sproc access
GRANT USAGE ON ALL PROCEDURES IN SCHEMA <schema-name> TO ROLE <readwrite-access-role-name>;
GRANT USAGE ON FUTURE PROCEDURES IN SCHEMA <schema-name> TO ROLE <readwrite-access-role-name>;

-- UDF access
GRANT USAGE ON ALL FUNCTIONS IN SCHEMA <schema-name> TO ROLE <readwrite-access-role-name>;
GRANT USAGE ON FUTURE FUNCTIONS IN SCHEMA <schema-name> TO ROLE <readwrite-access-role-name>;

-- Materialized view access
GRANT SELECT ON ALL MATERIALIZED VIEWS IN SCHEMA <schema-name> TO ROLE <readwrite-access-role-name>;
GRANT SELECT ON FUTURE MATERIALIZED VIEWS IN SCHEMA <schema-name> TO ROLE <readwrite-access-role-name>;

-- Task Access
GRANT MONITOR ON ALL TASKS IN SCHEMA <schema-name> TO ROLE <readwrite-access-role-name>;
GRANT OPERATE ON ALL TASKS IN SCHEMA <schema-name> TO ROLE <readwrite-access-role-name>;
GRANT MONITOR ON FUTURE TASKS IN SCHEMA <schema-name> TO ROLE <readwrite-access-role-name>;
GRANT OPERATE ON FUTURE TASKS IN SCHEMA <schema-name> TO ROLE <readwrite-access-role-name>;
```
