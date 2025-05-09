# What is this document? 

This document is meant to provide a clear definition of what "Use-Watch" access to a Warehouse means in this data project. This definition will be expressed both in plain english and as executable SQL Statements. For more context on access rights, what they mean, and how they are used in this project, see the project README.

# "Use-Watch" Schema Access: Plain-Language Definition

- "Use-Watch" means you have these privileges on the given warehouse:
    1. `USAGE`
        -  Grants the ability to use the warehouse for executing queries. A role with `USAGE` can start and stop the warehouse and can execute queries using the warehouse, provided the queries are related to objects (e.g., tables, schemas) that the role has access to.
    1. `MONITOR`
        - Allows the role to view and monitor usage statistics and performance metrics related to the warehouse. This includes querying warehouse activity (e.g., through views like `WAREHOUSE_LOAD_HISTORY`), monitoring the credits consumed, and viewing other warehouse-related metadata.  


# "Use-Watch" Schema Access: SQL Definition

```sql
USE ROLE USERADMIN;
CREATE ROLE IF NOT EXISTS <use-watch-access-role-name>;
GRANT ROLE <use-watch-access-role-name> TO ROLE <environment-sysadmin-role-name>;
USE ROLE SECURITYADMIN;
GRANT USAGE ON WAREHOUSE <environment-warehouse-name> TO ROLE <use-watch-access-role-name>;
GRANT MONITOR ON WAREHOUSE <environment-warehouse-name> TO ROLE <use-watch-access-role-name>;
```
