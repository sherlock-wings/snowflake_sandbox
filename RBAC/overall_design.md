# Project RBAC 
This project will use Role-Based Access Control(RBAC) that mostly leverages [managed schema](https://docs.snowflake.com/en/user-guide/security-access-control-configure#label-managed-access-schemas) in Snowflake. Grants on these managed schema will be given to one of three types of access roles. These types are
- "Read" Access Role
- "Read-Write" Access Role
- "Full" Access Role

Every functional role in this project will have some combination of read, read-write, and/or full access roles granted to it. Each access role applies to one and only one schema. While the access roles possess grants on data objects and schema children, only the functional roles can access Warehouses. This ensures that only Functional Roles and never Access Roles are used for SQL Statements that require compute of any kind. 

Each type of access has its own dedicated access role for each schema in our Data Models. For example, if you had one schema caleld `EDW_DB.RAW`, for example, you could have three access roles for that:
1. `EDW_DB_RAW_R_AR` ("Read" access role)
1. `EDW_DB_RAW_RW_AR` ("Read-Write" access role)
1. `EDW_DB_RAW_FULL_AR` ("Full" access role)

Each of these roles are combined to create *Functional Roles* (ex. `DEV_ENGINEER_FR`), which can have highly-configurable privileges. The flexibility these roles have is achieved by granting one or more access roles to a functional role. 

![Fig 1. Basic Access rights by Schema and Functional Role](https://github.com/sherlock-wings/snowflake_sandbox/blob/bug_fix/reconfigure_rbac_scripts/RBAC/miro/functional_role_diagram.jpg)
![Fig 2. Environment Structure and Data Flow](https://github.com/sherlock-wings/snowflake_sandbox/blob/bug_fix/reconfigure_rbac_scripts/RBAC/miro/environment_structure.jpg)
![Fig 3. Role Distribution across Environments](https://github.com/sherlock-wings/snowflake_sandbox/blob/bug_fix/reconfigure_rbac_scripts/RBAC/miro/roles_across_environments.jpg)
