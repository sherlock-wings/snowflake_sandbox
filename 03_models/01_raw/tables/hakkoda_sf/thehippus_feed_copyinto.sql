use role data_engineer;
use database pcallahan_sandbox;
use warehouse compute_wh;
create schema if not exists raw;
use schema raw;

COPY INTO thehippus_feed
FROM @stg_thehippus_feed
FILE_FORMAT = (TYPE = CSV 
               PARSE_HEADER = TRUE
               FIELD_OPTIONALLY_ENCLOSED_BY = '"'
              )
MATCH_BY_COLUMN_NAME = CASE_INSENSITIVE;