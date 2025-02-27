use role dev_admin_fr;
use schema dev_edw_db.raw;
CREATE STAGE IF NOT EXISTS csv_stg DIRECTORY = ( ENABLE = true );
