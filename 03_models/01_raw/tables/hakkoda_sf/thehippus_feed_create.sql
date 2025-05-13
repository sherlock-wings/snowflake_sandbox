use role data_engineer;
use database pcallahan_sandbox;
create schema if not exists raw;
use schema raw;

create table if not exists thehippus_feed (
 content_id varchar
,post_uri varchar
,like_count varchar
,quote_count varchar
,reply_count varchar
,repost_count varchar
,post_created_timestamp varchar
,text varchar
,tags varchar
,embedded_link_title varchar
,embedded_link_description varchar
,embedded_link_uri varchar
,post_author_did varchar
,post_author_username varchar
,post_author_displayname varchar
,post_author_account_created_timestamp varchar
,bluesky_client_account_did varchar
,bluesky_client_account_username varchar
,bluesky_client_account_displayname varchar
,bluesky_client_account_created_timestamp varchar
,record_captured_timestamp varchar
,s3_bucket_name varchar
,s3_bucket_directory varchar
,s3_bucket_filename varchar
);

list @stg_thehippus_feed;

/*
This side-project began with using Azure, but I couldn't figure out how to get a Function App to work--
at least not fast enough for my liking. The below comments show the code that was in place when this project
used azure, along with some ALTERs that had to be done to change certain fields to the new, AWS specific 
column names.
*/
-- alter table thehippus_feed
-- rename column azure_container_name to s3_bucket_name;
-- alter table thehippus_feed
-- rename column azure_blobpath to s3_bucket_directory;
-- alter table thehippus_feed
-- rename column azure_blobname to s3_bucket_filename;


-- create or replace stage stg_thehippus_feed
--   URL = 'azure://pfcstack1.blob.core.windows.net/sfsandbox/bluesky_posts/'
--     CREDENTIALS = (  AZURE_SAS_TOKEN = '***' );

