import numpy as np
import pandas as pd
import random

# create a series of numbers that "walk" mostly up or down, starting from a given value
def random_walk(start_value: int | float, n_values: int, step_size: int | float, prob_up: float):
    if prob_up < 0 or prob_up > 1:
        raise ValueError("`prob_up` must be a float between 0 and 1")
    
    # Generate a series of "steps", which can be up or down
    choices = np.random.choice([1, -1], size=n_values-1, p=[prob_up, 1-prob_up])

    # convert a series of steps into a series of running sums 
    # (each element equals the last element plus the value of the current "step")
    steps = np.cumsum(choices) * step_size

    # implement the start_value as an offset added to each element of `steps`
    # also, add the initial start value as an element at the beginning to complete the series
    values = np.concatenate([[start_value], start_value + steps])
    return pd.Series(values, dtype=float)

def jitter_series(input_series: pd.Series
                 ,direction: int = 0
                 ,seed: int | None = None # for reproducible copies of "jittered" series
                 ,size: int | None = None 
                 ,volatility: float = 0.01
                 ,relative: bool = True
                 ,discrete: bool = False) -> pd.Series:
    # validate direction as an int
    if direction not in [-1, 0, 1]:
        raise ValueError("`direction` must be a whole number between -1 and 1, or a list of exactly two floats that sum to 1.0")
   
   # size default value
    if not size:
        size = len(input_series)

    is_datetime = False
    if type(input_series.values[0]) == np.datetime64:
        is_datetime = True

    rng = np.random.default_rng(seed)
    if direction == -1:
        jitters = rng.uniform(-volatility, 0, size)
    elif direction == 1:
        jitters = rng.uniform(0, volatility, size)
    else:  # direction == 0
        jitters = rng.uniform(-volatility, volatility, size)
    
    # allow user to increment by a discrete (integer) or continuous (float) quantity 
    if discrete:
        jitters = jitters.round().astype('int64')

    # cast datetimes to numeric type if needed
    if is_datetime:
        input_series = input_series.astype('int64')

    # allow user to increment by flat addition or by relative percent
    if not relative:
        input_series = input_series + jitters
    else:
        input_series = input_series * (1 + jitters)
    
    if is_datetime:
        return input_series.astype('datetime64[ns]')
    else:
        return input_series

TABLE_COLUMN_SET = ['DATE' ,'TIME' ,'SYM' ,'PIMCOINTERNALKEY' ,'MDSID' ,'FEEDSEQNUM' ,'FEEDAPP' ,'VENDORUPDATETIME' ,'MDSRECEIVETIME' ,'MDSPUBLISHTIME' ,'TYPE' ,'GMTOFFSET' ,'EXCHTIME' ,'SEQNUM' ,'PRICE' ,'VOLUME' ,'ACCVOLUME' ,'MARKETVWAP' ,'OPEN' ,'HIGH' ,'LOW' ,'BLOCKTRD' ,'TICKDIR' ,'TURNOVER' ,'BIDPRICE' ,'BIDPRICE' ,'BIDSIZE' ,'ASKPRICE' ,'BIDPRICE' ,'ASKSIZE' ,'BUYERID' ,'NOBUYERS' ,'SELLERID' ,'NOSELLERS' ,'MIDPRICE' ,'BIDTIC' ,'ASKTONE' ,'BIDTONE' ,'TRADETONE' ,'MKTSTIND' ,'IRGCOND' ,'LSTSALCOND' ,'CRSSALCOND' ,'TRTRDFLAG' ,'ELIGBLTRD' ,'PRCQLCD' ,'LOWTP1' ,'HIGHTP1' ,'ACTTP1' ,'ACTFLAG1' ,'OFFBKTYPE' ,'GV3TEXT' ,'GV4TEXT' ,'ALIAS' ,'MFDTRANTP' ,'MMTCLASS' ,'SPRDCDN' ,'STRGYCDN' ,'OFFBKCDN' ,'PRCQL']

# GENERATE TIME (COLUMN 2)
TIME = pd.Series(pd.date_range(start = '2025-02-17 00:00:00.000000000'
                              ,end   = '2025-02-23 23:59:59.999999999'
                              ,freq  = '0.5s'
                              ).values
                ).rename('TIME')
# "jitter" time by a random amount of fractional sections between 0.0 and 0.5s (nanosecond precision)
TIME = jitter_series(TIME, volatility=1e8, relative=False)
total_rows = len(TIME)

# GENERATE DATE (COLUMN 1)
DATE = TIME.dt.date.rename('DATE')
all_cols = [DATE, TIME]

# GENERATE SYM (COLUMN 3)
SYM = pd.Series("1YMH25", index=TIME.index).rename('SYM')
all_cols.append(SYM)

# GENERATE PIMCOINTERNALKEY (COLUMN 4)
PIMCOINTERNALKEY = pd.Series("F:XCBT:XCBT:YM:M:20250301", index=TIME.index).rename('SYM')
all_cols.append(PIMCOINTERNALKEY)

# GENERATE PIMCOINTERNALKEY (COLUMN 5)
MDSID = pd.Series("1YMH25|REFINITIV|null|LIVE", index=TIME.index).rename('MDSID')
all_cols.append(MDSID)

# GENERATE FEEDSEQNUM (COLUMN 6)
start = 259237
FEEDSEQNUM = pd.Series(np.arange(start, start+total_rows, 1)).rename('FEEDSEQNUM')
all_cols.append(FEEDSEQNUM)

# GENERATE FEEDAPP (COLUMN 7)
FEEDAPP = pd.Series("RefinitivFuturesGw3_CLOUD_PROD_PROD-SECRETS_K8S_K8S-PROD", index=TIME.index).rename('FEEDAPP')
all_cols.append(FEEDAPP)

# GENERATE VENDORUPDATETIME (COLUMN 8) 
deltas = pd.Series(pd.to_timedelta(5, unit='h'), index=TIME.index)
VENDORUPDATETIME = (TIME + deltas).rename('VENDORUPDATETIME')
all_cols.append(VENDORUPDATETIME)

# GENERATE MDSRECEIVETIME (COLUMN 9)
MDSRECEIVETIME = jitter_series(VENDORUPDATETIME, volatility=1e9, direction=1, relative=False).rename('MDSRECEIVETIME')
all_cols.append(MDSRECEIVETIME)

# GENERATE MDSPUBLISHTIME (COLUMN 10)
MDSPUBLISHTIME = jitter_series(MDSRECEIVETIME, volatility=1e9, direction=1, relative=False).rename('MDSPUBLISHTIME')
all_cols.append(MDSPUBLISHTIME)

# GENERATE TYPE (COLUMN 11)
choice_ls = [1,2]
TYPE = pd.Series(random.choices(choice_ls, weights=(1, 9), k=total_rows))
TYPE = pd.Series(np.where(TYPE == 1, 'TRADE', 'QUOTE')).rename('TYPE')
all_cols.append(TYPE)

# GENERATE GMTOFFSET (COLUMN 12)
GMTOFFSET = FEEDSEQNUM.copy().rename('GMTOFFSET')
GMTOFFSET[:] = None
all_cols.append(GMTOFFSET)

# GENERATE EXCHTIME (COLUMN 13)
EXCHTIME = VENDORUPDATETIME.rename('EXCHTIME')
all_cols.append(EXCHTIME)

# GENERATE SEQNUM (COLUMN 14)
SEQNUM = np.arange(1, total_rows+1, 1)
SEQNUM = (TIME.dt.strftime('%Y%m%d%H%M%S%f') + SEQNUM.astype(str)).rename('SEQNUM')
all_cols.append(SEQNUM)

# GENERATE PRICE (COLUMN 15)
price_start = 44650.56000
trade_series = TYPE == 'TRADE'
total_trades = trade_series.sum()

pricewalk = random_walk(start_value=price_start, n_values=total_trades, step_size=0.002, prob_up=0.75)
PRICE = pd.Series(np.nan, index=TIME.index).rename('PRICE')
PRICE[trade_series] = pricewalk.values
all_cols.append(PRICE)


# GENERATE VOLUME (COLUMN 16)
vols = pd.Series(np.random.randint(1, 5, total_trades))
VOLUME = pd.Series(np.nan, index=TIME.index)
VOLUME[trade_series] = vols.values
VOLUME = VOLUME.astype('Int64').rename('VOLUME')
all_cols.append(VOLUME)

# GENERATE ACCVOLUME (COLUMN 17)
# filldown to kill nulls (where addition is not supported), 
# then convert each value from the initial one to the cumulative one,
# then drop all resulting values for all indices except those where VOLUME is not null
ACCVOLUME = VOLUME.fillna(0).cumsum().rename('ACCVOLUME')
all_cols.append(ACCVOLUME)

# OPEN (COLUMN 19)
OPEN = jitter_series(PRICE.groupby(TIME.dt.date).first(), volatility=0.001)
OPEN = pd.DataFrame(TIME.dt.date).merge(OPEN, how='left', left_on='TIME', right_on='TIME').PRICE.rename('OPEN')
all_cols.append(OPEN)

# HIGH (COLUMN 20)
HIGH = jitter_series(OPEN, direction=1, volatility=0.001).rename('HIGH')
all_cols.append(HIGH)

# LOW (COLUMN 21)
LOW = jitter_series(OPEN, direction=-1, volatility=0.001).rename('LOW')
all_cols.append(LOW)

# MARKETVWAP (COLUMN 18)
MARKETVWAP = jitter_series(pd.Series([0] * (len(TIME)-1)), direction=1, relative=False, volatility=0.01)
MARKETVWAP = pd.concat([pd.Series(LOW.values[0]), MARKETVWAP], ignore_index=True).cumsum().rename('MARKETVWAP')
all_cols.append(MARKETVWAP)

# BLOCKTRD (COLUMN 22)
BLOCKTRD = GMTOFFSET.copy().rename('BLOCKTRD')
all_cols.append(BLOCKTRD)

# BLOCKTRD (COLUMN 23)
TICKDIR = GMTOFFSET.copy().rename('TICKDIR')
all_cols.append(TICKDIR)

# BLOCKTRD (COLUMN 24)
TURNOVER = GMTOFFSET.copy().rename('TURNOVER')
all_cols.append(TURNOVER)

# BIDPRICE (COLUMN 25)
first_price = PRICE[PRICE.notna()].iloc[0] # get the numeric value of the first-occurring not-null price
BIDPRICE = PRICE.copy()
# on a copy of the original PRICE series, first fill forward. Then, for all initial nulls, replace swith first-occurring not-null price
BIDPRICE = PRICE.ffill().fillna(first_price)
numberList = [-2, -1, 0, 1]
increments = pd.Series(random.choices(numberList, weights=(60, 120, 180, 6), k=len(BIDPRICE)))
BIDPRICE = (BIDPRICE + increments).rename('BIDPRICE')
all_cols.append(BIDPRICE)

# BIDSIZE (COLUMN 26)
BIDSIZE = pd.Series(np.random.randint(1, 7, len(TIME))).rename('BIDSIZE')
all_cols.append(BIDSIZE)

# ASKPRICE (COLUMN 27)
first_price = PRICE[PRICE.notna()].iloc[0] # get the numeric value of the first-occurring not-null price
ASKPRICE = PRICE.copy()
# on a copy of the original PRICE series, first fill forward. Then, for all initial nulls, replace swith first-occurring not-null price
ASKPRICE = PRICE.ffill().fillna(first_price)
numberList = [0, 1, 2]
increments = pd.Series(random.choices(numberList, weights=(9,6,3), k=len(ASKPRICE)))
ASKPRICE = (ASKPRICE + increments).rename('ASKPRICE')
all_cols.append(ASKPRICE)

# ASKSIZE (COLUMN 28)
ASKSIZE = pd.Series(np.random.randint(1, 7, len(TIME))).rename('ASKSIZE')
all_cols.append(ASKSIZE)

# FINAL DATAFRAME
df = pd.concat(all_cols, 
               #columns=TABLE_COLUMN_SET, 
               axis=1)
df


'''
NOTES: Column Generation specs for PIMCO TICK_DATA_FULL Table:
3,330 rows per hour
for 24 hours/day
for 7 days


DATE = [2025-02-17 -- 2025-02-24]
TIME = [2025-02-17T00:00:00.000000000 -- 2025-02-24 23:59:59:999999999]
SYM = '1YMH25'
PIMCOINTERNALKEY = F:XCBT:XCBT:YM:M:20250301
MDSID = 1YMH25|REFINITIV|null|LIVE
FEEDSEQNUM = Monotonically increasing sequence ID/number
FEEDAPP = 'RefinitivFuturesGw3_CLOUD_PROD_PROD-SECRETS_K8S_K8S-PROD'
VENDORUPDATETIME = 5 hours after TIME
MDSRECEIVETIME = fractional seconds (random) after VENDORUPDATETIME
MDSPUBLISHTIME = fractional seconds (random) after MDSRECEIVETIME
TYPE = Can be approximated as 10% 'TRADE', 90% 'QUOTE'
GMTOFFSET = 100% NULL
EXCHTIME = Same as VENDORUPDATETIME
SEQNUM = (from time) YYYYMMDDHHMMSS(9) || FEEDSEQNUM
PRICE = CASE WHEN TYPE = 'TRADE' THEN -- Bidirectional 5% jitter about 44675.0000 -- ELSE NULL
VOLUME = CASE WHEN TYPE = 'TRADE' THEN -- random int b/n 1 and 80 -- ELSE NULL
ACCVOLUME = Cumulative Sum of VOLUME
MARKETVWAP = Start at 2 below first value for LOW and increase by fractional dollars cumulatively
OPEN = Bidirectional 5% jitter about PRICE
HIGH = Positive 5% jitter about OPEN
LOW = Negative 5% jitter about OPEN
BLOCKTRD = 100% NULL
TICKDIR = 100% NULL
TURNOVER = 100% NULL

BIDPRICE:
    numberList = [-2, -1, 0, 1]
    print(random.choices(numberList, weights=(60, 120, 180, 6), k=1))
    Increment off of last not-null price
BIDSIZE:
    Random int between 1 and 6
ASKPRICE:
    numberList = [0, 1, 2]
    print(random.choices(numberList, weights=(9, 6, 3), k=1))
    Increment off of last not-null price
BIDPRICE:
    numberList = [-2, -1, 0, 1]
    print(random.choices(numberList, weights=(60, 120, 180, 6), k=1))
    Increment off of last not-null price
ASKSIZE:
    Random int between 1 and 6
BUYERID= 100% NULL
NOBUYERS= 100% NULL
SELLERID= 100% NULL
NOSELLERS= 100% NULL
MIDPRICE= 100% NULL
BIDTIC= 100% NULL
ASKTONE= 100% NULL
BIDTONE= 100% NULL
TRADETONE= 100% NULL
MKTSTIND = CASE WHEN PRICE IS NULL THEN 'BBO' END
IRGCOND = 100% NULL
LSTSALCOND= 
    numberList = [-1, 0, 1]
    print(random.choices(numberList, weights=(1, 99, 99), k=1))
    Increment off of VOLUME
CRSSALCOND = 100% NULL
TRTRDFLAG = 100% NULL
ELIGBLTRD = 100% NULL
PRCQLCD = CASE WHEN VOLUME IS NULL THEN 'OPN' END 
LOWTP1 = 100% NULL
HIGHTP1 = 100% NULL
ACTTP1 = (close enough to) 100% NULL
ACTFLAG1 = 100% NULL
OFFBKTYPE = 100% NULL
GV3TEXT = 100% NULL
GV4TEXT = 100% NULL
ALIAS = 100% NULL
MFDTRANTP = 100% NULL
MMTCLASS = 100% NUL
SPRDCDN = 100% NUL
STRGYCDN = 100% NUL
OFFBKCDN = 100% NUL
PRCQL2 = (close enough to) 100% NULL
'''


