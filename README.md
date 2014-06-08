Presenter to ProPresenter migrator
==================================

Convert song files from Presenter (http://presentersoftware.com/) to ProPresenter 5 format.

Here are the steps to use this script:

1. set working directory to the location of the Presenter files ("*.txt")
2. run script with `-1` argument to convert Presenter files to plain_text/*.txt
3. import plain text files into ProPresenter 5
4. copy ProPresenter 5 files into propresenter_xml directory
5. run script with `-2` argument to add metadata in modified_xml/*.pro5
6. delete imported files from ProPresenter 5
7. import modified_xml/*.pro5 into ProPresenter 5

Some info on the Presenter and CCLI-text formats is in research.txt.

The ProPresenter 5 format is an XML mapping to OSX Objective C data structures;
the words themselves are in a field encoded as RTF and Base-64. That is why the
process above uses ProPresenter's built in importer.
