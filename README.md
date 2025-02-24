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
