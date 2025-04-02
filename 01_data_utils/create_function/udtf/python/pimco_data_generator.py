import numpy as np
import pandas as pd
import random

# "jitter" some value up, down, or bidirectionally about a start value
# will be used for many random value generations
def jitter(start_value: float, volatility: float = 0.01, direction: int = 0) -> float:
    if direction not in [-1, 0, 1]:
        raise ValueError("Input argument for `direction` should be -1 (negative jitter), 1 (positive jitter), or 0 (bidirectional jitter).")
    jitter = 0
    if direction == -1:
        jitter += random.uniform(-volatility, 0) * start_value
    elif direction == 1:
        jitter += random.uniform(0, volatility) * start_value
    else:
        jitter += random.uniform(-volatility, volatility) * start_value
    return start_value + jitter

# GENERATE TIME (COLUMN 2)
TIME = pd.Series(pd.date_range(start = '2025-02-17 00:00:00.000000000'
                              ,end   = '2025-02-23 23:59:59.999999999'
                              ,freq  = '0.5s'
                              ).values
                )
total_rows = len(TIME)

TIME = pd.Series([ts + np.timedelta64(round(jitter(250000000, 0.99999, 0)), 'ns') for ts in TIME])

# GENERATE DATE (COLUMN 1)
DATE = pd.Series([dt.date() for dt in TIME])

# GENERATE SYM (COLUMN 3)
SYM = pd.Series("1YMH25", index=TIME.index)

# GENERATE PIMCOINTERNALKEY (COLUMN 4)
PIMCOINTERNALKEY = pd.Series("F:XCBT:XCBT:YM:M:20250301", index=TIME.index)

# GENERATE PIMCOINTERNALKEY (COLUMN 5)
MDSID = pd.Series("1YMH25|REFINITIV|null|LIVE", index=TIME.index)

# GENERATE FEEDSEQNUM (COLUMN 6)
start = 259237
FEEDSEQNUM = pd.Series(np.arange(start, start+total_rows, 1))

# GENERATE FEEDAPP (COLUMN 7)
FEEDAPP = pd.Series("RefinitivFuturesGw3_CLOUD_PROD_PROD-SECRETS_K8S_K8S-PROD", index=TIME.index)

# GENERATE VENDORUPDATETIME (COLUMN 8) 
VENDORUPDATETIME = pd.Series([ts + np.timedelta64(5, 'h') for ts in TIME])

# GENERATE MDSRECEIVETIME (COLUMN 9)

MDSRECEIVETIME = pd.Series([ts + np.timedelta64(round(jitter(500000000, 0.99999, 0)), 'ns') for ts in VENDORUPDATETIME])

# GENERATE MDSPUBLISHTIME (COLUMN 10)

MDSPUBLISHTIME = pd.Series([ts + np.timedelta64(round(jitter(500000000, 0.99999, 0)), 'ns') for ts in MDSRECEIVETIME])

# GENERATE TYPE (COLUMN 11)
choice_ls = [1,2]
TYPE = random.choices(choice_ls, weights=(1, 9), k=total_rows)
TYPE = ['TRADE' if item == 1 else 'QUOTE' if item == 2 else None for item in TYPE]

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