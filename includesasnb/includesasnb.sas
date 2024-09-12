/*-----------------------------------------------------------------------------------*/
/* Extract the code cells from a SAS Notebook file (.sasnb) and submit as a %include */
/* filepath = <full path to sasnb file, no quotes>                                   */
/* outpath  = OPTIONAL: <full path to save code as .SAS file>                        */
/* noexec =  1 | 0 OPTIONAL: 1 is default, and code will be run.                     */
/* If 0 will just output code to log or outfile if specified                         */
/*                                                                                   */
/* Example use:                                                                      */
/*  %includesasnb(filepath=C:\Projects\sas-microsoft365-example.sasnb);              */
/* To echo code to log and NOT run it:                                               */
/*  %includesasnb(filepath=C:\Projects\sas-microsoft365-example.sasnb,noexec=1);     */
/* To save the notebook code in persistent SAS file:                                 */
/*  %includesasnb(filepath=C:\Projects\sas-microsoft365-example.sasnb,               */
/*                         outfile=c:\projects\newfile.sas);                         */
/*-----------------------------------------------------------------------------------*/
%macro includesasnb(
     filepath=, /* REQUIRED: full path to the .sasnb file                                  */
     outpath=,  /* OPTIONAL: persistent location for .SAS file to save .sasnb as program   */
     noexec=0   /* OPTIONAL: whether to skip execution of code or just echo to log or file */
  );
  filename _nb "&filepath.";
  %if %sysfunc(fexist(_nb)) %then
    %do;
      libname _nb JSON fileref=_nb;

      %if "&outpath." ^= "" %then %do;
        filename _code "&outpath." ;
      %end;
      %else %do;
        filename _code temp;
      %end;

      /* Pull just the code cells from the notebook file    */
      /* SQL and Python code must be wrapped in step syntax */
      data _null_;
        set _nb.root;
        file _code;
        if _n_ = 1 then do;
          put "/* Code generated from &filepath. */";
        end;

        if language="sas" then
          do;
            put value;
          end;

        if language="sql" then
          do;
            put "proc sql;";
            put value;
            put "quit;";
          end;

        if language="python" then
          do;
            put "proc python;";
            put "submit;";
            put value;
            put "endsubmit;";
            put "run;";
          end;
      run;
      %if &noexec = 0 %then
        %do;
          %include _code;
        %end;
      %else
        %do;
          %if "&outpath." = "" %then 
            %do;
              /* echo to log only */
              %put --------------------------------;
              %put Code cells from &filepath.;
              %put --------------------------------;

              data _null_;
                infile _code;
                file log;
                input;
                put _infile_;
              run;
            %end;
        %end;
      libname  _nb clear;
      filename _code clear;
    %end;
    %else %put ERROR: File &filepath. does not exist;
    filename _nb clear;
%mend;

