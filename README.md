# Table of Contents 

1. [Data Model](#data-model)
1. [Project RBAC](#project-rbac)
3. [Environment Summary Diagram](#environment-summary-diagram)
4. [Role Distribution by Enviornment](#role-distribution-by-environment)
5. [Object Naming Conventions](#object-naming-conventions)

# Data Model

Our data model consists of three simple schema. This schema-triplet will exist across multiple environments, and each environment will be held in a single database.

When referring to these schema outside of the context of any specific environment, we refer to them as "Prototype schema".

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
  

## Access rights within a single Environment

The below diagram depicts the typical architecture for environments like Dev, QA, and Prod. 

![Fig. 1: Access Types for all Functional Roles across Prototype Schema](https://github.com/sherlock-wings/snowflake_sandbox/blob/bug_fix/realign_rbac/RBAC/miro/structure_within_an_environment.jpg)

*Exceptions to this general architecture for specific environments such as Prod, Sandbox, etc. are detailed in further sections.


# Project RBAC 
The above Role-access Control (RBAC) setup will be achieved with `GRANT` statements that leverage [managed schema](https://docs.snowflake.com/en/user-guide/security-access-control-configure#label-managed-access-schemas) in Snowflake. 

## Schema Access Roles and their Types
Grants on these managed schema will be given to one of three types of schema-based access roles. These types are
- "Read" Access Role
- "Read-Write" Access Role
- "Full" Access Role

Every functional role in this project will have some combination of read, read-write, and/or full access roles granted to it. Each schema-based access role applies to one and only one schema. 

## Warehouse Access Roles and their Types
To use compute to process any data in the above-mentioned schemas, a warehouse is required. Like with schema-based access roles, warehouse-based access roles come in three types: 

- "Use" Access Role
    - This access role grants `USAGE` on the warehouse 
- "Use-Watch" Access Role
    - This access role grants both `USAGE` and `MONITOR` on the warehouse 
- "Owner" Access Role
    - This access role grants ultimate `OWNERSHIP` on the warehouse 


## Access Roles & Functional Roles
For each of the three access types, a specific access role exists for each schema in our Data Models. For example, if you had one schema caleld `EDW_DB.RAW`, for example, you would have three access roles for that:
1. `EDW_DB_RAW_R_AR` ("Read" access role)
1. `EDW_DB_RAW_RW_AR` ("Read-Write" access role)
1. `EDW_DB_RAW_FULL_AR` ("Full" access role)

For the warehouses, you would have roles like:
1. `COMPUTE_WH_U_AR` ("Use" access role)
1. `COMPUTE_WH_UW_AR` ("Use-Watch" access role)
1. `COMPUTE_WH_O_AR` ("Owner" access role)
 

Each of these roles are combined to create *Functional Roles* (ex. `DEV_ENGINEER_FR`), which can have highly-configurable privileges. The flexibility these roles have is achieved by granting one or more access roles to a functional role. 

## Access rights definitions

For detailed documentation on what "Read", "Read-Write", "Full", etc. access actually means, and how specifically it is implemented for warehouses and schemas, see the directory `*RBAC/access_definitions`. 

## Personas/Functional Roles in this Project

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
  
### One `*_SYSADMIN` to own them all

To consolidate high-level privileges for a single environment, we establish one final "persona" called `*_SYSADMIN`. This is analogous to the Snowflake system role called [`SYSADMIN`](https://docs.snowflake.com/en/user-guide/security-access-control-overview#label-access-control-overview-roles-system), except that its permissions apply to a single environment. 

Each environment will have such a role. This role will ultimately inherit:
1. All the read, read-write, and full-access roles in the environment
2. Ownership of the Warehouse dedicated to that environment

To complete the inheritance cycle, all `*_SYSADMIN` roles are granted to the Snowflake-default `SYSADMIN` role.  

## On Warehouses

I try to keep the approach for warehouses as simple as possible. The only rules we follow on this project with respect to warehouses are:

1. Warehouses should be sized appropriately.
    - Anything bigger than an X-Small ought to have a documented justification for why the extra compute is necessary
3. One warehouse per environment
    - Warehouses are where most daily compute is spent. If you're spending money, you ought to know what environments are costing you the most
    - Splitting Warehouses by enviornment achieves this 


## Environment Structure

Each of the prototype schemas and their associated functional roles are duplicated across each of our environments. We have four "full" environments:
1. SANDBOX
    - When the team sets out to deliver a new feature or fix a bug, the first lines of code and the first SQL statements executed always happen here
    - Each developer has their own **set of sandbox schemas**, where each schema's name contains the name of the developer the schema is meant for
    - More details on this in the following section 
1. DEV
    - This is where integration testing takes place
    - After several Pull requests have been approved and merged, this is the environment they will "land" in
    - Here, all those features are tested together to ensure they are compatible with each other
3. QA
   - This is where User-Acceptance testing takes place
   - After a new feature or bug fix makes it to QA, it should already have been thoroughly tested for bugs by the developer
   - QA is where some sort of stakeholder, such as the person who requested the feature in the first place, can inspect the latest changes and ensure they fit expectations and requirements
5. PROD
   - This is where the final product of all our work lives for the whole world (or at least the business) to see 

### UTIL Environment

I said we have four "full" environments because we sort of technically have a fifth environment, but it doesn't work like the other four. 

This environment consists of a single database containing a schema called `UTIL`. In diagrams, I refer to this database as `NAMED_DATABASE` because its exact name is arbitrary. In practice, I usually just name it after whatever company I'm doing the given project for. For this project, I decided to name it after my github account-- `SHERLOCK_WINGS`. 

The point of this database and schema is to hold all important quality-of-life objects that are not actual business data. Things like stored procedures (such as the one used to populate the Sandbox environment-- see below), data definitions, etc. will be kept here. 

## How the Sandbox works

The point of the sandbox is to give developers a place where they can execute even the most destructive of SQL operations without causing any problems in any other environment. We enable this by giving each developer their own "workspace". This is done by running many `CREATE SCHEMA... CLONE` statements, essentially. 

### Sandbox Schema Naming Conventions

`<sandbox-db-name>.<developer-name>_<prototype-schema-name>`

Example:
1. `SANDBOX_EDW_DB.PCALLAHAN_STAGE`
2. `SANDBOX_EDW_DB.BJONES_MODEL`

### Multiple schemas

While its tempting to think of "your sandbox" as a single object, your Sandbox is actually 3 objects (at least when using our Project's data model). In my case, "my Sandbox" would be a triplet of schemas named like: 

1. `SANDBOX_EDW_DB.PCALLAHAN_RAW`
1. `SANDBOX_EDW_DB.PCALLAHAN_STAGE`
2. `SANDBOX_EDW_DB.PCALLAHAN_MODEL`

### Populating the Sandbox

This is never done manually. It is done by using a stored procedure (name TBD). The sproc works by cloning from a target environment (specified by the caller) and into the Sandbox. The sproc knows automatically to generate the schemas as clones, using the correct name. Also, it correctly "rebuilds" the RBAC so the schema is is usable as expected post-execution. 

# Environment Summary Diagram

For a summary of how the roles, schemas, and environments discussed above all work together, see Figure 2 below:

![Fig 2. Environment Summary Diagram](https://github.com/sherlock-wings/snowflake_sandbox/blob/bug_fix/realign_rbac/RBAC/miro/structure_between_environments.jpg)

# Role Distribution by Enviornment

Supporting this architecture the right way means that the role for a given persona has many "copies" of itself. This is so each persona can be implemented in higher or lower environments as needed. However, it is not as simple as one role per persona and environment. In some environments, certain personas should not have access.

These details are summarized in Figure 3 below:

![Fig 3. Role Distribution across Environments](https://github.com/sherlock-wings/snowflake_sandbox/blob/bug_fix/realign_rbac/RBAC/miro/roles_across_environments.jpg)

## Role Access by Environment

***No** single functional role has uniform access across all 5 enviornments!*
1. ANALYST does not need to read access to SANDBOX or UTIL since it is meant only for the consumption of business-data
2. Personas used by humans (i.e. not `SVCTRANSFORMER`) who also generally get read-write access must **not** have any access in Prod for basic security reasons
    - That means no Prod-Facing ENGINEER or ADMIN functional roles    
4. ENGINEER is the only role with support for Readups
    - This is because basic Development often requires reading from a higher environment so data in a lower environment can be compared or overwritten
    - Read downs are never supported, regardless
    - For example, `QA_ENGINEER_FR` can read from Prod and QA but can only write to QA
    - `SANDBOX_ENGINEER_FR` can read from Dev, QA, and Prod, but can only write to Sandbox. It has no access to UTIL
5. SVCTRANFORMER does not need read/write access to SANDBOX or UTIL like ANALYST-- it is only meant for executing orchestrated jobs. These should never be created in SANDBOX or UTIL

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
