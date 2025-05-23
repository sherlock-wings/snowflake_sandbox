use role ADMIN_FR;

create or replace task bluesky_db.main.task_process_firehose_data
warehouse = compute_wh
schedule = 'USING CRON 0 5 * * * UTC'
as 
call bluesky_db.main.process_firehose_data();
ALTER TASK bluesky_db.main.task_process_firehose_data RESUME;