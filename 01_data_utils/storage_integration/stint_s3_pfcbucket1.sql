CREATE OR REPLACE STORAGE INTEGRATION stint_s3_pfcbucket1
  TYPE = EXTERNAL_STAGE
  STORAGE_PROVIDER = S3
  ENABLED = TRUE
  STORAGE_AWS_ROLE_ARN = '***' -- get this from the ARN for the Read-Write S3 role you have in your AWS account (a role, not a user)
  STORAGE_ALLOWED_LOCATIONS = ('s3://pfcbucket1/bluesky_posts/') -- limit access to only the folder being used for bluesky posts
  COMMENT = 'Storage integration used to ingest bluesky post data stored in PFC\'s S3 bucket';