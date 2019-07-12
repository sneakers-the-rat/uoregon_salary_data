These scripts were used to extract the salary data from the PDFs available at https://ir.uoregon.edu/salary and aggregate them.

# Step 1:  extract_salaries.py

This script uses [https://camelot-py.readthedocs.io/en/master/](camelot) to parse the tables in the pdfs. Much of this script depends on the structure of your PDFs, so it should be treated as an example rather than an 'out of the box' salary extractor.

The main thing you will need to adjust is the table boundaries in the `camelot.read_pdf(table_areas=[...])` call. See the camelot documentation for more information on how to do that.

You will also need to set up the `if __name__ == '__main__'` block with the path containing your pdfs and their particular naming structure

# Step 2: salaries_agg.R

This script was used to generate the basic plots also included in this directory. Note that these plots were heavily stylized afterwards in illustrator.

