## DOES NOT WORK
## AI GENERATED SLOP
## Need to figure out how to actually write a python UDTF
import numpy as np
import pandas as pd
import random

class GeneratePimcoTickData:
    def __init__(self):
        self.TABLE_COLUMN_SET = [
            'DATE', 'TIME', 'SYM', 'PIMCOINTERNALKEY', 'MDSID', 'FEEDSEQNUM', 'FEEDAPP', 
            'VENDORUPDATETIME', 'MDSRECEIVETIME', 'MDSPUBLISHTIME', 'TYPE', 'GMTOFFSET', 
            'EXCHTIME', 'SEQNUM', 'PRICE', 'VOLUME', 'ACCVOLUME', 'MARKETVWAP', 'OPEN', 
            'HIGH', 'LOW', 'BLOCKTRD', 'TICKDIR', 'TURNOVER', 'BIDPRICE', 'BIDSIZE', 
            'ASKPRICE', 'ASKSIZE', 'BUYERID', 'NOBUYERS', 'SELLERID', 'NOSELLERS', 
            'MIDPRICE', 'BIDTIC', 'ASKTONE', 'BIDTONE', 'TRADETONE', 'MKTSTIND', 
            'IRGCOND', 'LSTSALCOND', 'CRSSALCOND', 'TRTRDFLAG', 'ELIGBLTRD', 'PRCQLCD', 
            'LOWTP1', 'HIGHTP1', 'ACTTP1', 'ACTFLAG1', 'OFFBKTYPE', 'GV3TEXT', 'GV4TEXT', 
            'ALIAS', 'MFDTRANTP', 'MMTCLASS', 'SPRDCDN', 'STRGYCDN', 'OFFBKCDN', 'PRCQL2'
        ]
        
    def _random_walk(self, start_value, n_values, step_size, prob_up):
        if prob_up < 0 or prob_up > 1:
            raise ValueError("`prob_up` must be a float between 0 and 1")
        
        choices = np.random.choice([1, -1], size=n_values-1, p=[prob_up, 1-prob_up])
        steps = np.cumsum(choices) * step_size
        values = np.concatenate([[start_value], start_value + steps])
        return values
    
    def _jitter_series(self, input_series, direction=0, seed=None, volatility=0.01, relative=True, discrete=False):
        if direction not in [-1, 0, 1]:
            raise ValueError("`direction` must be -1, 0, or 1")
        
        rng = np.random.default_rng(seed)
        size = len(input_series)
        
        if direction == -1:
            jitters = rng.uniform(-volatility, 0, size)
        elif direction == 1:
            jitters = rng.uniform(0, volatility, size)
        else:
            jitters = rng.uniform(-volatility, volatility, size)
        
        if discrete:
            jitters = jitters.round().astype('int64')
        
        if not relative:
            return input_series + jitters
        else:
            return input_series * (1 + jitters)
    
    def process(self, start_datetime: str, end_datetime: str, row_interval_seconds: float):
        """Generate complete dataset with proper NULL handling for integer columns"""
        # Convert inputs to pandas Timestamps
        start_dt = pd.Timestamp(start_datetime)
        end_dt = pd.Timestamp(end_datetime)
        
        # Calculate total duration and rows
        total_seconds = (end_dt - start_dt).total_seconds()
        total_rows = int(total_seconds / row_interval_seconds) + 1
        
        # Generate core TIME column
        TIME = pd.date_range(start=start_dt, end=end_dt, periods=total_rows)
        
        # Jitter TIME column
        time_numeric = TIME.astype('int64').values
        jittered_time = self._jitter_series(time_numeric, volatility=1e8, relative=False)
        TIME = pd.to_datetime(jittered_time)
        
        # Initialize DataFrame with proper NULL handling
        df = pd.DataFrame({
            'DATE': TIME.date,
            'TIME': TIME,
            'SYM': "1YMH25",
            'PIMCOINTERNALKEY': "F:XCBT:XCBT:YM:M:20250301",
            'MDSID': "1YMH25|REFINITIV|null|LIVE",
            'FEEDSEQNUM': list(range(259237, 259237 + total_rows)),
            'FEEDAPP': "RefinitivFuturesGw3_CLOUD_PROD_PROD-SECRETS_K8S_K8S-PROD",
            'VENDORUPDATETIME': TIME + pd.Timedelta(hours=5),
            'TYPE': random.choices(['TRADE', 'QUOTE'], weights=(1, 9), k=total_rows),
            'GMTOFFSET': None,
            'EXCHTIME': TIME + pd.Timedelta(hours=5),
            'SEQNUM': TIME.strftime('%Y%m%d%H%M%S%f') + pd.Series(range(1, total_rows + 1)).astype(str),
            'BIDSIZE': [int(x) for x in np.random.randint(1, 7, total_rows)],
            'ASKSIZE': [int(x) for x in np.random.randint(1, 7, total_rows)],
            'MKTSTIND': None,
            'LSTSALCOND': [2 if x < 0.08 else None for x in np.random.random(total_rows)],
            'PRCQLCD': None
        })
        
        # Jitter time-based columns
        df['MDSRECEIVETIME'] = pd.to_datetime(
            self._jitter_series(
                df['VENDORUPDATETIME'].astype('int64').values,
                direction=1, volatility=1e9, relative=False
            )
        )
        df['MDSPUBLISHTIME'] = pd.to_datetime(
            self._jitter_series(
                df['MDSRECEIVETIME'].astype('int64').values,
                direction=1, volatility=1e9, relative=False
            )
        )
        
        # Generate trade-specific columns
        trade_mask = df['TYPE'] == 'TRADE'
        total_trades = trade_mask.sum()
        
        # PRICE for trades
        df['PRICE'] = None  # Using None instead of np.nan
        if total_trades > 0:
            pricewalk = self._random_walk(44650.56000, total_trades, 0.002, 0.75)
            df.loc[trade_mask, 'PRICE'] = pricewalk
            
            # VOLUME for trades - using Python int or None
            df['VOLUME'] = None
            volumes = np.random.randint(1, 5, total_trades)
            df.loc[trade_mask, 'VOLUME'] = [int(v) for v in volumes]
            
            # ACCVOLUME - handle NULLs properly
            df['ACCVOLUME'] = None
            if total_trades > 0:
                acc_vol = 0
                for i in range(len(df)):
                    if trade_mask[i] and df.at[i, 'VOLUME'] is not None:
                        acc_vol += df.at[i, 'VOLUME']
                        df.at[i, 'ACCVOLUME'] = int(acc_vol)
            
            # Window functions for OPEN/HIGH/LOW
            df['OPEN'] = None
            df['HIGH'] = None
            df['LOW'] = None
            
            # Only calculate for days that have trades
            for date, group in df.groupby('DATE'):
                if any(group['TYPE'] == 'TRADE'):
                    first_price = next((x for x in group['PRICE'] if x is not None), None)
                    if first_price is not None:
                        df.loc[group.index, 'OPEN'] = first_price
                        df.loc[group.index, 'HIGH'] = first_price * (1 + np.random.uniform(0, 0.001))
                        df.loc[group.index, 'LOW'] = first_price * (1 - np.random.uniform(0, 0.001))
            
            # MARKETVWAP
            first_low = next((x for x in df['LOW'] if x is not None), None)
            if first_low is not None:
                df['MARKETVWAP'] = first_low + np.random.uniform(0, 0.01, total_rows).cumsum()
            
            # BIDPRICE and ASKPRICE
            first_price = next((x for x in df.loc[trade_mask, 'PRICE'] if x is not None), 44650.56000)
            df['BIDPRICE'] = df['PRICE'].ffill().fillna(first_price)
            df['BIDPRICE'] += [float(x) for x in random.choices([-2, -1, 0, 1], weights=(60, 120, 180, 6), k=total_rows)]
            
            df['ASKPRICE'] = df['PRICE'].ffill().fillna(first_price)
            df['ASKPRICE'] += [float(x) for x in random.choices([0, 1, 2], weights=(9, 6, 3), k=total_rows)]
        
        # Set quote-specific values
        df.loc[df['TYPE'] == 'QUOTE', 'MKTSTIND'] = 'BBO'
        df.loc[df['TYPE'] == 'QUOTE', 'PRCQLCD'] = 'OPN'
        
        # Set all NULL columns
        null_cols = [col for col in self.TABLE_COLUMN_SET if col not in df.columns]
        for col in null_cols:
            df[col] = None
        
        # Convert all pandas NA/NaN to None
        df = df.where(pd.notnull(df), None)
        
        # Ensure proper Python types before yielding
        for col in df.columns:
            if df[col].dtype == 'object':
                df[col] = df[col].apply(lambda x: int(x) if isinstance(x, (int, float)) and not pd.isna(x) else x)
        
        # Yield rows in the exact order specified
        for _, row in df[self.TABLE_COLUMN_SET].iterrows():
            yield tuple(None if pd.isna(x) else x for x in row)