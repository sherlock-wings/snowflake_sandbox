use role data_engineer;
use schema pimco_poc_db.pimco_poc_bronze;
use warehouse compute_wh;

create table if not exists tick_data_synthetic_lg
(
    DATE VARCHAR,
    TIME VARCHAR,
    SYM STRING,
    PIMCOINTERNALKEY STRING,
    MDSID STRING,
    FEEDSEQNUM INTEGER,
    FEEDAPP STRING,
    VENDORUPDATETIME VARCHAR,
    MDSRECEIVETIME VARCHAR,
    MDSPUBLISHTIME VARCHAR,
    TYPE STRING,
    GMTOFFSET FLOAT,
    EXCHTIME VARCHAR,
    SEQNUM STRING,
    PRICE FLOAT,
    VOLUME INTEGER,
    ACCVOLUME INTEGER,
    MARKETVWAP FLOAT,
    OPEN FLOAT,
    HIGH FLOAT,
    LOW FLOAT,
    BLOCKTRD VARCHAR,
    TICKDIR VARCHAR,
    TURNOVER VARCHAR,
    BIDPRICE FLOAT,
    BIDSIZE INTEGER,
    ASKPRICE FLOAT,
    ASKSIZE INTEGER,
    BUYERID VARCHAR,
    NOBUYERS VARCHAR,
    SELLERID VARCHAR,
    NOSELLERS VARCHAR,
    MIDPRICE VARCHAR,
    BIDTIC VARCHAR,
    ASKTONE VARCHAR,
    BIDTONE VARCHAR,
    TRADETONE VARCHAR,
    MKTSTIND VARCHAR,
    IRGCOND VARCHAR,
    LSTSALCOND INTEGER,
    CRSSALCOND VARCHAR,
    TRTRDFLAG VARCHAR,
    ELIGBLTRD VARCHAR,
    PRCQLCD VARCHAR,
    LOWTP1 VARCHAR,
    HIGHTP1 VARCHAR,
    ACTTP1 VARCHAR,
    ACTFLAG1 VARCHAR,
    OFFBKTYPE VARCHAR,
    GV3TEXT VARCHAR,
    GV4TEXT VARCHAR,
    ALIAS VARCHAR,
    MFDTRANTP VARCHAR,
    MMTCLASS VARCHAR,
    SPRDCDN VARCHAR,
    STRGYCDN VARCHAR,
    OFFBKCDN VARCHAR,
    PRCQL2 VARCHAR

);

truncate table tick_data_synthetic_lg;

insert into tick_data_synthetic_lg (
select * from (
WITH RECURSIVE dateseries AS (
    SELECT 0 AS offset_days
    UNION ALL
    SELECT offset_days + 1
    FROM dateseries
    WHERE offset_days < 89 
)

,src as (
select 
 to_date(date) as date
,to_timestamp_ntz(split_part(time, 'D', 1) || ' ' || split_part(time, 'D', 2)) as time
,to_timestamp_ntz(split_part(VENDORUPDATETIME, 'D', 1) || ' ' || split_part(VENDORUPDATETIME, 'D', 2)) as VENDORUPDATETIME
,to_timestamp_ntz(split_part(MDSRECEIVETIME, 'D', 1) || ' ' || split_part(MDSRECEIVETIME, 'D', 2)) as MDSRECEIVETIME
,to_timestamp_ntz(split_part(MDSPUBLISHTIME, 'D', 1) || ' ' || split_part(MDSPUBLISHTIME, 'D', 2)) as MDSPUBLISHTIME
,to_timestamp_ntz(split_part(EXCHTIME, 'D', 1) || ' ' || split_part(EXCHTIME, 'D', 2)) as EXCHTIME
,* exclude(date, time, vendorupdatetime, mdsreceivetime, mdspublishtime, exchtime)
from tick_data_full
)

,xjoin as (
select 
     dateadd(day, b.offset_days, DATE) as DATE
    ,dateadd(day, b.offset_days, TIME) as TIME
    ,dateadd(day, b.offset_days, VENDORUPDATETIME) as VENDORUPDATETIME
    ,dateadd(day, b.offset_days, MDSRECEIVETIME) as MDSRECEIVETIME
    ,dateadd(day, b.offset_days, MDSPUBLISHTIME) as MDSPUBLISHTIME
    ,dateadd(day, b.offset_days, EXCHTIME) as EXCHTIME
    ,* exclude(date, time, vendorupdatetime, mdsreceivetime, mdspublishtime, exchtime)
from src a
cross join dateseries b
)

,to_str as (
select 
     to_char(DATE)                                                                                         as date
    ,split_part(to_char(time), ' ', 1)             || 'D' || split_part(to_char(time), ' ', 2)             as time
    ,split_part(to_char(vendorupdatetime), ' ', 1) || 'D' || split_part(to_char(vendorupdatetime), ' ', 2) as vendorupdatetime
    ,split_part(to_char(mdsreceivetime), ' ', 1)   || 'D' || split_part(to_char(mdsreceivetime), ' ', 2)   as mdsreceivetime
    ,split_part(to_char(mdspublishtime), ' ', 1)   || 'D' || split_part(to_char(mdspublishtime), ' ', 2)   as mdspublishtime
    ,split_part(to_char(exchtime), ' ', 1)         || 'D' || split_part(to_char(exchtime), ' ', 2)         as exchtime
    ,* exclude(date, time, vendorupdatetime, mdsreceivetime, mdspublishtime, exchtime)
from xjoin a
)
-- test
select DATE
      ,TIME
      ,SYM
      ,PIMCOINTERNALKEY
      ,MDSID
      ,FEEDSEQNUM
      ,FEEDAPP
      ,VENDORUPDATETIME
      ,MDSRECEIVETIME
      ,MDSPUBLISHTIME
      ,TYPE
      ,GMTOFFSET
      ,EXCHTIME
      ,SEQNUM
      ,PRICE
      ,VOLUME
      ,ACCVOLUME
      ,MARKETVWAP
      ,OPEN
      ,HIGH
      ,LOW
      ,BLOCKTRD
      ,TICKDIR
      ,TURNOVER
      ,BIDPRICE
      ,BIDSIZE
      ,ASKPRICE
      ,ASKSIZE
      ,BUYERID
      ,NOBUYERS
      ,SELLERID
      ,NOSELLERS
      ,MIDPRICE
      ,BIDTIC
      ,ASKTONE
      ,BIDTONE
      ,TRADETONE
      ,MKTSTIND
      ,IRGCOND
      ,LSTSALCOND
      ,CRSSALCOND
      ,TRTRDFLAG
      ,ELIGBLTRD
      ,PRCQLCD
      ,LOWTP1
      ,HIGHTP1
      ,ACTTP1
      ,ACTFLAG1
      ,OFFBKTYPE
      ,GV3TEXT
      ,GV4TEXT
      ,ALIAS
      ,MFDTRANTP
      ,MMTCLASS
      ,SPRDCDN
      ,STRGYCDN
      ,OFFBKCDN
      ,PRCQL2
from xjoin
)
)
;

select count(*) from tick_data_synthetic_lg;