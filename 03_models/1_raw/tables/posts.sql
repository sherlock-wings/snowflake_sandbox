use role dev_engineer_fr;
use dev_edw_db.raw;

create table if not exists posts (
 content_id                       varchar
,post_uri                         varchar
,like_count                       varchar
,quote_count                      varchar
,reply_count                      varchar
,repost_count                     varchar
,post_created_timestamp           timestamp_tz(9)
,text                             varchar
,tags                             varchar
,embedded_link_title              varchar
,embedded_link_description        varchar
,embedded_link_uri                varchar
,author_username                  varchar
,author_displayname               varchar
,author_account_created_timestamp timestamp_tz(9)
,record_captured_timestamp        timestamp_tz(9)
);