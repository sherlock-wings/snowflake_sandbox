# What is this document? 

This document is meant to provide a clear definition of what "Owner" access to a Warehouse means in this data project. This definition will be expressed both in plain english and as executable SQL Statements. For more context on access rights, what they mean, and how they are used in this project, see the project README.

# "Owner" Schema Access: Plain-Language Definition

- "Owner" means you have these privileges on the given warehouse:
    1. `USAGE`
        -  Grants the ability to use the warehouse for executing queries. A role with `USAGE` can start and stop the warehouse and can execute queries using the warehouse, provided the queries are related to objects (e.g., tables, schemas) that the role has access to.
    1. `MONITOR`
        - Allows the role to view and monitor usage statistics and performance metrics related to the warehouse. This includes querying warehouse activity (e.g., through views like `WAREHOUSE_LOAD_HISTORY`), monitoring the credits consumed, and viewing other warehouse-related metadata.  
    1. `OWNERSHIP`
        - Transfer ownership of the warehouse to another role.
        - Modify all warehouse properties, including resizing the warehouse or changing its suspend time.
        - Drop the warehouse.
        - Rename the warehouse.

# "Owner" Schema Access: SQL Definition

```sql
USE ROLE USERADMIN;
CREATE ROLE IF NOT EXISTS <owner-access-role-name>;
USE ROLE SECURITYADMIN;
GRANT OWNERSHIP ON WAREHOUSE <environment-warehouse-name> TO ROLE <owner-access-role-name>;
GRANT ROLE <owner-access-role-name> TO ROLE <environment-sysadmin-role-name>;
```
