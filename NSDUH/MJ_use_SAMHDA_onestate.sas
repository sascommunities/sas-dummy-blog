/* Copyright SAS Institute Inc. */

/* Create a temp dir to hold the data we download */
options dlcreatedir;
%let workloc = %sysfunc(getoption(WORK))/data;
libname csvloc "&workloc.";
libname csvloc clear;

%macro fetchStudy(state=,year=);

  filename study "&workloc./&state._&year..csv";

  /* Marijuana IRMJRC */
  /* Alcohol: IRALCRC */
  /* Cigarettes: IRCIGRC */
  proc http
   method="GET"
   url="https://rdas.samhsa.gov/api/surveys/NSDUH-&year.-RD02YR/crosstab.csv/?row=CATAG2%str(&)column=IRMJRC%str(&)control=STNAME%str(&)weight=DASWT_1%str(&)run_chisq=false%str(&)filter=STNAME%nrstr(%3D)&state."
   out=study;
  run;

%mend;

%let state=COLORADO;

/* Download data for each 2-year study period */
%fetchStudy(state=&state., year=2016-2017);
%fetchStudy(state=&state., year=2015-2016);
%fetchStudy(state=&state., year=2014-2015);
%fetchStudy(state=&state., year=2012-2013);
%fetchStudy(state=&state., year=2010-2011);
%fetchStudy(state=&state., year=2008-2009);
%fetchStudy(state=&state., year=2006-2007);


DATA WORK.MJState;
  LENGTH
    year 8
    fname $ 300
    STATE_NAME       $ 15
    recency $ 52
    age_cat $ 19
    Total_pc            8
    Total_pcSE         8
    Total_pcCI__lower_ 8
    Total_pcCI__upper_ 8
    row_percent             8
    Row_pcSE           8
    Row_pcCI_lower 8 
    Row_pcCI_upper 8
    Column_pc           8
    Column_pcSE        8
    Column_pcCI__lower_ 8
    Column_pcCI__upper_ 8
    Weighted_Count     8
    Count_SE           8;
  LABEL
    recency = "drug use recency, imputed revised"
    age_cat = "AGE (recoded)"
  ;
  INFILE "&workloc./&state._*.csv"
    filename=fname
    LRECL=32767
    FIRSTOBS=2
    ENCODING="UTF-8"
    DLM='2c'x
    MISSOVER
    DSD;
  INPUT
    state_name   
    recency 
    age_cat 
    Total_pc     
    Total_pcSE   
    Total_pcCI__lower_ 
    Total_pcCI__upper_ 
    row_percent      
    Row_pcSE         
    Row_pcCI_lower
    Row_pcCI_upper
    Column_pc       
    Column_pcSE     
    Column_pcCI__lower_
    Column_pcCI__upper_
    Weighted_Count
    Count_SE;

  /* get year from filename */
  year = input( scan(fname,-2,'._-'), 4.);

  /* trim out the summarized lines/columns */
  if state_name="&state." and age_cat ^= "Overall" and recency ^="Overall";
  keep recency age_cat row_percent year 
    used_12mo Row_pcCI_lower Row_pcCI_upper;

    /* recoded recency to 12mo, yes or no */
  used_12mo = ( char(recency,1) in ('1','2') );

  /* Trim ordinal indicator from age category */
  age_cat = substr(age_cat,4);
RUN;

/* Summarize to the "used in past 12 mo" category */
proc sql;
 create table mjsum as 
  select year, age_cat,
    sum(row_percent) as row_percent
  from mjState
  where used_12mo=1
  group by year, age_cat;
quit;

ods graphics / width=450 height=600;

/* Use this ODS mod in EG 8.1 to include title in graph file */
/*ods html5(id=eghtml) gtitle;*/

title "Self-reported Marijuana use in past 12 months";
title2 "&state., 2-year study survey results";
proc sgplot data=work.mjsum ;
   inset "Source:" "National Survey on Drug Use and Health" "samhsa.gov"
      / position=topleft border backcolor=white ; 
 series x=year y=row_percent / 
   group=age_cat  
   markers markerattrs=(size=12 symbol=Diamond color=blue)
   lineattrs=(thickness=4pt);
 xaxis minor grid display=(nolabel)  
   values=(2007 to 2017 by 1)  ;
 format 
   row_percent percent4.1;

 yaxis grid display=(nolabel) min=0 max=1
   values=(0 to 1 by .05);
   keylegend / location=outside position=topleft across=1;

run;

/* An example of a Band plot to show Confidence Interval */
title "Use in just past 30 days, with CI";
proc sgplot data=WORK.MJState;
 band x=year upper=Row_pcCI_upper lower=Row_pcCI_lower
  / group=age_cat transparency=0.4;
 series x=year y=row_percent / group=age_cat lineattrs=(thickness=3);
 yaxis display=(nolabel) values=(0 to 1 by .1);
 format row_percent percent6.;
 where recency ? "past 30 days";
run;
