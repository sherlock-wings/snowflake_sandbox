CREATE STAGE stg_thehippus_feed
  STORAGE_INTEGRATION = stint_s3_pfcbucket1
  URL = 's3://pfcbucket1/bluesky_posts/';