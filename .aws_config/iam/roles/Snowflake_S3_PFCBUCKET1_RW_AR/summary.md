# Role name
`Snowflake_S3_PFCBUCKET1_RW_AR`

# Description
This is a role that will be invoked by Snowflake to do read/write actions against the S3 bucket called pfcbucket1

# Permissions
Policy -> `S3_pfcbucket1_RW`

# Notes

Remember you have to configure a trust policy for this role to work in Snowflake for read/write 
S3 operations. For details on how to do that, check [this article](https://docs.snowflake.com/user-guide/data-load-s3-config-storage-integration). 