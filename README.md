# Goal

1. To get better at RBAC
    - For this I'm gonna try [Roleout](https://github.com/Snowflake-Labs/roleout?tab=readme-ov-file) 
1. To get [that sproc](https://hakkoda.atlassian.net/wiki/x/AYB5Pw) working better
2. Maybe figure out how to make a Snowflake-native data pipeline

# Notes

## Using [Roleout](https://github.com/Snowflake-Labs/roleout)

Getting started is super easy! It basically divides privs into three groups:

1. Read
     - Every FR in this group gets the `*_R_AR` access role
     - Pretty much just `SELECT` and `USAGE` privs only
2. Read-Write
     - Every FR in this group gets the `*_RW_AR` access role
     - Includes the ability to `UPDATE`, `INSERT`, etc
3. Full
     - Every FR in this group gets the `*_FULL_AR` access role
     - This is the `OWNERSHIP` role
  
So Roleout will make a bunch of ARs for each schema. The Read ARs go to my `ANALYST_FR`. The Read-Write ARs go to my `ENGINEER_FR`. And the full ARs go to my `ADMIN_FR`.

Only catch is that Roleout does not give `CREATE TABLE` privs to my Read-Write roles out of the box. So I modified the RBAC to allow for that


## Places where we need to improve on Roleout

### Read-write Roles in PROD
Can't have these-- at least not ones meant for end-users. We need to tweak the Roleout RBAC so `PROD_ENGINEER_FR` is either removed or has its name changed so that it is clear this role is meant only for service accounts and not end-users.

### `UTIL` DB

Need support for a utilities Database and the RBAC that goes with it. Ths database presents a challenge. This is what we know:

1. The existing RBAC from Roleout triplicates itself over three Environments
    - This makes a lot of sense when you're releasing new features and bug-fixes when buliding out and/or supporting a production data pipeline
1. It is unclear whether doing the same triplication for a Utilities Database makes a lot of sense
    - For example, one application of this db is a sproc that clones data from higher environments to lower ones
    - This is really helpful if you are a developer, since you can just poof your sandbox into existence fresh with cloned Prod data and start working
    - However, outside of a Dev or QA environment, such a sproc has no use
    - This is different from most other features that move through our environments-- a newly created dimension table will get used everywhere, including Prod, not just the Dev environments
    - So what's the point of having a "Production Utlity Database" alongside a Dev or QA Utlity Database?
    - But also think about the lifecycle
    - you are writing this now direct in `SHERLOCK_WINGS.UTIL`. You can do that because you are the account owner
    - What would you do if you were still under someone else?
        - I would just write and test in Sandbox, and confirm against Dev and QA.
        - Once I did that, my sproc would get moved to `UTIL`
        - So yea only need one DB 
