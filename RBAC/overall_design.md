# Table of Contents 

1. [Project RBAC](#project-rbac)
2. [Data Model](#data-model)
3. [Object Naming Conventions](#object-naming-conventions)

# Project RBAC 
This project will use Role-Based Access Control(RBAC) that mostly leverages [managed schema](https://docs.snowflake.com/en/user-guide/security-access-control-configure#label-managed-access-schemas) in Snowflake. 

## Access Roles and their Types
Grants on these managed schema will be given to one of three types of access roles. These types are
- "Read" Access Role
- "Read-Write" Access Role
- "Full" Access Role

Every functional role in this project will have some combination of read, read-write, and/or full access roles granted to it. Each access role applies to one and only one schema. While the access roles possess grants on data objects and schema children, only the functional roles can access Warehouses. This ensures that only Functional Roles and never Access Roles are used for SQL Statements that require compute of any kind. 

## Access Roles & Functional Roles
For each of the three access types, a specific access role exists for each schema in our Data Models. For example, if you had one schema caleld `EDW_DB.RAW`, for example, you could have three access roles for that:
1. `EDW_DB_RAW_R_AR` ("Read" access role)
1. `EDW_DB_RAW_RW_AR` ("Read-Write" access role)
1. `EDW_DB_RAW_FULL_AR` ("Full" access role)

Each of these roles are combined to create *Functional Roles* (ex. `DEV_ENGINEER_FR`), which can have highly-configurable privileges. The flexibility these roles have is achieved by granting one or more access roles to a functional role. 

## Four Personals/Functional Roles in this Project

We use all the various access roles to sum together four functional roles, each corresponding to one "persona" in this project.

1. `*_ADMIN_FR`
    - This role is dedicated to anyone who serves an administrative role on the project
    - Persons with this role will have ownership over most schema-child objects and will have the the most permissive access out of all Functional Roles
1. `*_ENGINEER_FR`
    - This role is dedicated to anyone who is developing code on the project
    - Persons with this role can create and modify most objects, but they do not have ownership over anything
    - Persons with this role will be able to read from higher environments, but cannot write to any environment but the one that applies to their current role
        - This feature is called "read ups" and will be discussed in detail further below
1. `*_SVCTRANSFORM_FR`
    - Service account role
    - This role should be used by orchestrators or any sort of non-human application that will refresh data pipelines on a regular schedule
    - This role is very similar to the `*_ENGINEER_FR` role, with two important exceptions:
        1. This role does not support read ups
        2. This role *does* have production write access, whereas the human-facing *_ENGINEER_FR` role, for obvious reasons, does not
1. `*_ANALYST_FR`
    - Read-only persona
    - Used for any person or application that needs to query the data but does not need to change it in any way

# Data Model

As mentioned earlier, the rights given to each of the access roles we will use are *schema specific*. To give our schemas a regular structure across environments, we establish our **prototype schemas**. These will describe the naming and purpose for each schema that we will replicate across most environments. 

Our prototype schema are:

1. `RAW`
    - Here we will keep all of our source data
    - Data should be as close to as it existed in the source system as possible
    - Stages and other ingestion constructs (pipes, streams, etc) will be kept here as well
3. `STAGE`
    - Light-touch transforms on source data, (usually) instantiated as views
    - Intermediate persisted tables & views
5. `MODEL`
    - Reporting parent layer
    - Model constructs (as persisted tables) are kept here
    - For kimball, this means your dimensions, facts, fact aggregates, and other entities like bridge/mapping tables are kept here
  
Each of these schemas will exist in each environment. There is one environment per database.

# Object Naming Conventions

## Databases

`<environment-prefix>_EDW_DB`

Examples:
1. `QA_EDW_DB`
2. `PROD_EDW_DB`

## Roles

### Access Roles
`<environment_prefix>_<database-name>_<schema-name>_<access-type>_AR`

Examples:
1. `DEV_EDW_DB_MODEL_RW_AR`
2. `PROD_EDW_RAW_R_AR`

### Functional Roles

`<persona-name>_FR`

Examples:
1. `QA_ADMIN_FR`
2. `SANDBOX_ENGINEER_FR`

### Schema Children

`<object-name>_<object-type-suffix>`

Note that for permanent tables, there is no object type suffix. The trailing `'_'` is omitted from the object name in those cases.

| Object Type    | Suffix |
| -------- | ------- | 
| Permanent Table  | None    | 
| Transient Table  | `TRN`     |
| Temporary Table    | `TMP`   |
| View    | `VW`   |
| Materialized View    | `MVW`   |
| Sequences    | `SQN`   |
| File Formats    | `FFM`   |
| Stages    | `STG`   |
| Streams    | `STM`   |
| Stored Procedures    | `STP`   |
| User Defined Functions (UDFs)    | `UDF`   |
| Tasks | `TSK` |


![Fig 1. Basic Access rights by Schema and Functional Role](https://github.com/sherlock-wings/snowflake_sandbox/blob/bug_fix/reconfigure_rbac_scripts/RBAC/miro/functional_role_diagram.jpg)
![Fig 2. Environment Structure and Data Flow](https://github.com/sherlock-wings/snowflake_sandbox/blob/bug_fix/reconfigure_rbac_scripts/RBAC/miro/environment_structure.jpg)
![Fig 3. Role Distribution across Environments](https://github.com/sherlock-wings/snowflake_sandbox/blob/bug_fix/reconfigure_rbac_scripts/RBAC/miro/roles_across_environments.jpg)
