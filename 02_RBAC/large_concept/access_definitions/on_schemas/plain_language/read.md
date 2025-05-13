# What is this document? 

This document is meant to provide a clear definition of what "Read" access to a schema means in this data project. This definition will be expressed both in plain english and as executable SQL Statements. For more context on access rights, what they mean, and how they are used in this project, see the project README.

# "Read" Schema Access: Plain-Language Definition

- "Read" access means you generally have the ability to read from or use existing objects, but you may not alter existing objects in any way. You also may not create new objects of your own.
- As with all access on this Data Project, access is granted at the **schema level**. So, anyone with "Read" access will have that acces in the context of a specific schema.

# "Read" Schema Access: SQL Definition

```sql
-- Instantiate role and the environment SYSADMIN's inheritance of it
CREATE ROLE IF NOT EXISTS <read-access-role-name>;
GRANT ROLE <read-access-role-name> TO ROLE <environment-sysadmin-role-name>;

USE ROLE SECURITYADMIN;

-- Schema access
GRANT USAGE ON DATABASE <database-name> TO ROLE <read-access-role-name>;
GRANT USAGE ON SCHEMA <schema-name> TO ROLE <read-access-role-name>;

-- Table access
GRANT SELECT ON ALL TABLES IN SCHEMA <schema-name> TO ROLE <read-access-role-name>;
GRANT SELECT ON FUTURE TABLES IN SCHEMA <schema-name> TO ROLE <read-access-role-name>;

-- View access
GRANT SELECT ON ALL VIEWS IN SCHEMA <schema-name> TO ROLE <read-access-role-name>;
GRANT SELECT ON FUTURE VIEWS IN SCHEMA <schema-name> TO ROLE <read-access-role-name>;
GRANT SELECT ON ALL MATERIALIZED VIEWS IN SCHEMA <schema-name> TO ROLE <read-access-role-name>;
GRANT SELECT ON FUTURE MATERIALIZED VIEWS IN SCHEMA <schema-name> TO ROLE <read-access-role-name>;

-- Sequence access
GRANT USAGE ON ALL SEQUENCES IN SCHEMA <schema-name> TO ROLE <read-access-role-name>;
GRANT USAGE ON FUTURE SEQUENCES IN SCHEMA <schema-name> TO ROLE <read-access-role-name>;

-- Stage access
GRANT USAGE ON ALL STAGES IN SCHEMA <schema-name> TO ROLE <read-access-role-name>;
GRANT READ ON ALL STAGES IN SCHEMA <schema-name> TO ROLE <read-access-role-name>;
GRANT USAGE ON FUTURE STAGES IN SCHEMA <schema-name> TO ROLE <read-access-role-name>;
GRANT READ ON FUTURE STAGES IN SCHEMA <schema-name> TO ROLE <read-access-role-name>;

-- File format access
GRANT USAGE ON ALL FILE FORMATS IN SCHEMA <schema-name> TO ROLE <read-access-role-name>;
GRANT USAGE ON FUTURE FILE FORMATS IN SCHEMA <schema-name> TO ROLE <read-access-role-name>;

-- Stream access
GRANT SELECT ON ALL STREAMS IN SCHEMA <schema-name> TO ROLE <read-access-role-name>;
GRANT SELECT ON FUTURE STREAMS IN SCHEMA <schema-name> TO ROLE <read-access-role-name>;

-- Sproc access
GRANT USAGE ON ALL PROCEDURES IN SCHEMA <schema-name> TO ROLE <read-access-role-name>;
GRANT USAGE ON FUTURE PROCEDURES IN SCHEMA <schema-name> TO ROLE <read-access-role-name>;

-- UDF access
GRANT USAGE ON ALL FUNCTIONS IN SCHEMA <schema-name> TO ROLE <read-access-role-name>;
GRANT USAGE ON FUTURE FUNCTIONS IN SCHEMA <schema-name> TO ROLE <read-access-role-name>;
```
