/* Get all of the nonblank lines */
filename CDC url "https://wwwn.cdc.gov/nndss/conditions/search/";
data rep;
infile CDC length=len lrecl=32767;
input line $varying32767. len;
 line = strip(line);
 if len>0;
run;
filename CDC clear;

/* Parse the lines and keep just condition names */
/* When a condition code is found, grab the line following (full name of condition) */
/* and the 8th line following (Notification To date)                                */
/* Relies on this page's exact layout and line break scheme */
data parsed (keep=condition_code condition_full note_to);
 length condition_code $ 40 condition_full $ 60;
 set rep;
 if find(line,"/nndss/conditions/") then do;
   condition_code=scan(line,4,'/');
   pickup= _n_+1 ;
   pickup2 = _n_+8;
   set rep (rename=(line=condition_full)) point=pickup;
   set rep (rename=(line=note_to)) point=pickup2;
   output;
  end;
run;