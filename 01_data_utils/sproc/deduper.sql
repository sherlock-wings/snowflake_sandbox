create or replace procedure bluesky_db.main.deduper (
 TARGET_DB varchar
,TARGET_SC varchar
,TARGET_TBL varchar
,TARGET_COL varchar
)
returns varchar
language javascript
execute as owner
as 
$$
const target_column = TARGET_COL.toUpperCase();
const target_namespace = TARGET_DB.toUpperCase()+"."+TARGET_SC.toUpperCase()+"."+TARGET_TBL.toUpperCase();
const dupeholder_namespace = TARGET_DB.toUpperCase()+"."+TARGET_SC.toUpperCase()+'.DUPE_HOLDER';
var dupetest_sql = 'select 1 where exists (select '+target_column+', count(*) as row_count from '+target_namespace+' group by 1 having row_count >1)';

try {
// first, check if the target table actually has dupes about the given column. if not, abort
    var stmt = snowflake.createStatement( {sqlText: dupetest_sql} );
    var res = stmt.execute();
    if (!res.next()) {
        return 'No duplicates on column "'+target_column+'" in table "'+ target_namespace+ '". Aborting procedure.'; 
    }
    else {
        // if dupes are detected...
        // 1) make a tmp table and capture the *second* instance of each dupe ONLY 
        var mktbl_sql = 'create or replace temp table '+dupeholder_namespace+' as (select *, row_number() over (partition by '+target_column+' order by '+target_column+') as rownum from '+target_namespace+' qualify rownum = 2)';
        try {
            stmt = snowflake.createStatement( {sqlText: mktbl_sql} );
            res = stmt.execute();
        }
        catch (err) {
            return "Failed executing statement `"+stmt.getSqlText()+"`. Error message: `" + err + "`"; 
        }
        
        // 2) delete all records in the target table that match those in the temp table
        var delete_sql = 'delete from '+target_namespace+' a using '+dupeholder_namespace+' b where a.'+target_column+' = b.'+target_column;
        var deleted_rows = 0;
        try {
            stmt = snowflake.createStatement( {sqlText: delete_sql} );
            res = stmt.execute();
            deleted_rows += res.getNumRowsAffected()
        }
        catch (err) {
            return "Failed executing statement `"+stmt.getSqlText()+"`. Error message: `" + err + "`"; 
        }

        // 3) insert the original records, one per unique ID, back into the target table
        var reinsert_sql = 'insert into '+target_namespace+' (select * exclude(rownum) from '+dupeholder_namespace+')'; 
        var inserted_rows = 0;
        try {
            stmt = snowflake.createStatement( {sqlText: reinsert_sql} );
            res = stmt.execute();
            inserted_rows += res.getNumRowsAffected()
        }
        catch (err) {
            return "Failed executing statement `"+stmt.getSqlText()+"`. Error message: `" + err + "`";  sql
        }

        return "Using '"+target_column+"' as the grain, detected and removed "+(deleted_rows-inserted_rows)+" duplicate records from "+target_namespace;
        
    }
}
catch (err) {
        return "Failed executing statement `"+stmt.getSqlText()+"`. Error message: `" + err + "`";
    }
$$;
