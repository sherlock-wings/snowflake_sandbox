use role data_engineer;
use database pcallahan_sandbox;
create schema if not exists raw;
use schema raw;

create table if not exists arbyswaifu_feed (
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
);

create or replace stage stg_arbyswaifu_feed
  URL = 'azure://pfcstack1.blob.core.windows.net/sfsandbox/bluesky_posts/'
    CREDENTIALS = (  AZURE_SAS_TOKEN = '***' );

list @stg_arbyswaifu_feed;