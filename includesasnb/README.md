# %includesasnb -- read in and run code from a SAS Notebook

*Purpose:* Extract the code cells from a SAS Notebook file (.sasnb) and submit as a %include action in SAS.

This macro reads just the code-style cells from the SAS Notebook file and assembles them into one continuous SAS program. It then uses %INCLUDE to bring that program into your current SAS session and run it.

**NOTE**: This macro does *not* update the content of the SAS Notebook file with any SAS log or other results. 

Currently, SAS Notebook files support these type of code cells: SAS, SQL and Python. For SQL and Python, this macro adds the required PROC SQL/QUIT or PROC PYTHON/SUBMIT/ENDSUBMIT/RUN sections so the complete code runs in SAS. 

The **filepath**= argument tells the macro where to find the SAS Notebook file. There are also two optional arguments:

- **outpath=** Path to output file to save the code as a persistent .SAS file. If you do not specify outpath=, the code is stored in a temp location and deleted at the end of your SAS session.
- **noexec=** 1 | 0 - If 1, then the code is not run but just echoed to the SAS log or output to the outpath= location.      

### Example use
```
/* Build SAS code from code cells and run in current session */

 %includesasnb(filepath=C:\Projects\sas-microsoft365-example.sasnb);              

 /* To echo code to log and NOT run it: */

%includesasnb(filepath=C:\Projects\sas-microsoft365-example.sasnb,noexec=1);     

/* To save the notebook code in persistent SAS file AND run it: */

%includesasnb(filepath=C:\Projects\sas-microsoft365-example.sasnb,              
                         outfile=c:\projects\newfile.sas);       

```