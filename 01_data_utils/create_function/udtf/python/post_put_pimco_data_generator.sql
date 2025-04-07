/*
IN PYTHON LOCAL DIR, RUN THIS IN CMD LINE
>>> import pimco_data_generator as p
>>> df = p.generate_synthetic_pimco_tick_data()
>>> import dask.dataframe as dd
>>> ddf = dd.from_pandas(df, npartitions = 10)
>>> ddf.to_csv('output/ptd_*.csv', index=False)

IN SNOWSQL, RUN THIS CODE

put file://output/ptd*.csv @PIMCO_SYNTHETIC_DATA parallel = 8 auto_compress = true overwrite = true

*/

use role data_engineer;
use schema pimco_poc_db.pimco_poc_bronze;

create stage if not exists pimco_synthetic_data;
grant read on stage pimco_synthetic_data to role public;


create or replace table stg_tick_data_synthetic like tick_data_full;
-- Now load all matching files into the new table
COPY INTO stg_tick_data_synthetic
FROM @pimco_synthetic_data
FILE_FORMAT = (TYPE = CSV, PARSE_HEADER = TRUE)
MATCH_BY_COLUMN_NAME = CASE_INSENSITIVE;

create or replace table tick_data_synthetic
(
    DATE DATE,
    TIME TIMESTAMP_NTZ,
    SYM STRING,
    PIMCOINTERNALKEY STRING,
    MDSID STRING,
    FEEDSEQNUM INTEGER,
    FEEDAPP STRING,
    VENDORUPDATETIME TIMESTAMP_NTZ,
    MDSRECEIVETIME TIMESTAMP_NTZ,
    MDSPUBLISHTIME TIMESTAMP_NTZ,
    TYPE STRING,
    GMTOFFSET FLOAT,
    EXCHTIME TIMESTAMP_NTZ,
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

insert into tick_data_synthetic
select 
    to_date(DATE) as date,
    to_timestamp_ntz(replace(TIME, 'D', ' ')) as time,
    SYM,
    PIMCOINTERNALKEY,
    MDSID,
    cast(FEEDSEQNUM as NUMBER(38,0)) as FEEDSEQNUM,
    FEEDAPP,
    VENDORUPDATETIME,
    MDSRECEIVETIME,
    MDSPUBLISHTIME,
    TYPE,
    GMTOFFSET,
    EXCHTIME,
    cast(SEQNUM as NUMBER(38,0)) AS SEQNUM,
    cast(PRICE as NUMBER(38,0)) AS PRICE,
    cast(VOLUME as NUMBER(38,0)) AS VOLUME,
    cast(ACCVOLUME as NUMBER(38,0)) AS ACCVOLUME,
    cast(MARKETVWAP as NUMBER(38,0)) AS MARKETVWAP,
    cast(OPEN as NUMBER(38,0)) AS OPEN,
    cast(HIGH as NUMBER(38,0)) AS HIGH,
    cast(LOW as NUMBER(38,0)) AS LOW,
    BLOCKTRD,
    TICKDIR,
    TURNOVER,
    BIDPRICE,
    BIDSIZE,
    ASKPRICE,
    ASKSIZE,
    BUYERID,
    NOBUYERS,
    SELLERID,
    NOSELLERS,
    MIDPRICE,
    BIDTIC,
    ASKTONE,
    BIDTONE,
    TRADETONE,
    CASE WHEN MKTSTIND = 'nan' THEN NULL ELSE MKTSTIND END AS MKTSTIND,
    IRGCOND,
    LSTSALCOND,
    CRSSALCOND,
    TRTRDFLAG,
    ELIGBLTRD,
    CASE WHEN PRCQLCD = 'nan' THEN NULL ELSE PRCQLCD END AS PRCQLCD,
    LOWTP1,
    HIGHTP1,
    ACTTP1,
    ACTFLAG1,
    OFFBKTYPE,
    GV3TEXT,
    GV4TEXT,
    ALIAS,
    MFDTRANTP,
    MMTCLASS,
    SPRDCDN,
    STRGYCDN,
    OFFBKCDN,
    PRCQL2
FROM STG_TICK_DATA_SYNTHETIC;


SELECT TOP 10 * FROM TICK_DATA_SYNTHETIC;