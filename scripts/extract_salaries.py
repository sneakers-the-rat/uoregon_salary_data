import camelot
import numpy as np
import pandas as pd
from tqdm import tqdm
import os
import PyPDF2
import pdb
import multiprocessing as mp
from pprint import pprint

def clean_salary(path, tqdm_position=1):
    # global read_type

    # get date and filename
    dirname, fname = os.path.split(path)
    out_fn = os.path.splitext(path)[0] + '.csv'

    if 'unclassified' in path.lower():
        read_type = 'unclassified'
    elif 'classified' in path.lower():
        read_type = 'classified'
    else:
        Warning(f'{path} doesnt look like a salary file! aborting.')
        return

    # get number of pages in pdf
    file = PyPDF2.PdfFileReader(path)
    n_pages = file.getNumPages()

    all_salaries = None

    # if this is run in multiprocessing mode, 
    # set the position of the tqdm progress bar so it
    # doesn't overlap w/ other processes
    try:
        current = mp.current_process()
        tqdm_position = current._identity[0]+1
    except:
        pass

    # iterate through pages and 
    for page in tqdm(range(2,n_pages), position=tqdm_position):
        try:
            # extract the page
            if read_type.lower() == "classified":
                tables = camelot.read_pdf(path,
                                          flavor='stream', pages=str(page), table_areas=['0,690,560,70'])
            else:
                tables = camelot.read_pdf(path,
                                          flavor='stream', pages=str(page), table_areas=['0,675,560,70'])

            # cast table as pandas dataframe
            table_df = tables[0].df

            # find names by looking for places where there are three empty columns in a row
            row_1 = table_df.loc[:,1] == ""
            row_2 = table_df.loc[:,2] == ""
            row_3 = table_df.loc[:,3] == ""

            join_1 = np.logical_and(row_1, row_2)
            join_2 = np.logical_and(join_1, row_3)

            # get the indices of name rows, and make 
            # another iterator w/ the final row before the next name
            name_idx = np.where(join_2)[0]
            next_idx = name_idx.copy()
            next_idx[0:-1] = name_idx[1:]
            next_idx[-1] = table_df.shape[0]

            # iterate through name blocks in the table
            salaries = None
            for idx, idx_end in zip(name_idx, next_idx):
                # extract name and rows
                name = table_df.loc[idx,0]
                rows = table_df.loc[idx+1:idx_end-1]

                # these tables are split into two columns, so we concatenate them.
                # have to do a bit of inelegant index manipulation to make it work... probably a better way to do this.
                left_cols = rows.iloc[:,0:2]
                right_cols = rows.iloc[:,2:4]
                right_cols.columns = pd.RangeIndex(start=0, stop=2, step=1)
                rows = pd.concat((left_cols, right_cols))
                rows.index = pd.Int64Index(range(rows.shape[0]))
                rows = rows.T
                rows.columns = rows.iloc[0]
                rows = rows.reindex(rows.index.drop(0))
                rows.loc[1,'NAME'] = name

                # drop empty columns
                try:
                    rows = rows.drop('', axis=1)
                except:
                    pass

                # if this is the first pass on this page, start the list, otherwise add to it
                if salaries is None:
                    salaries = rows
                else:
                    salaries = salaries.append(rows)

            # same pattern here, append salaries from each page to a list.
            if all_salaries is None:
                all_salaries = salaries
            else:
                all_salaries = all_salaries.append(salaries)
        except Exception as e:
            # if a page fails, print which file and page.
            # set a trace here to debug failures if needed.

            #pdb.set_trace()
            print('Failed on file {}, page {}'.format(path, page))
            print(e)
            pass

    # finally, save to a csv.
    all_salaries.to_csv(out_fn, index=False)




if __name__ == "__main__":

    base_dir = '../unprocessed'

    # do this as w/ multiple processes
    do_multi = True

    # find relevant pdfs and csvs
    files = os.listdir(base_dir)
    csv_files = [f for f in files if f.endswith('.csv')]
    files = [f for f in files if f.endswith('.pdf')]


    csv_stems = [os.path.splitext(f)[0] for f in csv_files]

    print('Found pdf files:\n')
    pprint(files)

    print('\n\nFound csv files:\n')
    pprint(csv_files)


    # remove any that have already been converted
    files = [f for f in files if os.path.splitext(f)[0] not in csv_stems]

    print("\n\nonly extracting files without csv files:\n\n")
    pprint(files)



    fullpaths = [os.path.join(base_dir, f) for f in files]

    if do_multi:
        pbar = tqdm(total=len(files), position=0)
        pool = mp.Pool(7)


        results = pool.imap_unordered(clean_salary, fullpaths)

        for r in results:
            try:
                r.get()
                pbar.update()
            except AttributeError:
                pbar.update()

    else:
        for f in tqdm(files, position=0):
            fullpath = os.path.join(base_dir, f)
            clean_salary(fullpath)


