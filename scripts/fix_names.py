"""
hacky lil script to change the date formatting from MDY to Y-M-D
"""

import os


base_dir = '../'
files = os.listdir(base_dir)
files = [f for f in files if f.endswith('.csv')]

for f in files:
    prefix = f.split('_')[0]
    date = f.split('_')[-1].split('.')[0]

    # if we've already renamed this one, skip
    if len(date.split('-'))>1:
        continue

    # reorganize to ymd
    date_reformat = f'20{date[-2:]}-{date[:2]}-{date[2:4]}'

    # recombine to full filename
    new_fn = f'{prefix}_{date_reformat}.csv'

    os.rename(
        os.path.join(base_dir,f), 
        os.path.join(base_dir,new_fn)
        )


