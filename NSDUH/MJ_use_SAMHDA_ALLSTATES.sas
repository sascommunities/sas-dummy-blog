/* Copyright SAS Institute Inc. */

/* Create a temp dir to hold the data we download */
options dlcreatedir;
%let workloc = %sysfunc(getoption(WORK))/data;
libname csvloc "&workloc.";
libname csvloc clear;

/* Collect CSV files for each year */
%macro getStudies;
  %do year=2008 %to 2017;
    filename study "&workloc./usa_&year..csv";
    proc http 
     method="GET"
     url="https://pdas.samhsa.gov/api/surveys/NSDUH-&year.-DS0001/crosstab.csv/?row=CATAG2&column=IRMJRC&weight=ANALWT_C&run_chisq=false"
     out=study;
    run;
  %end;
%mend;

/* Get annual studies for all years */
%getStudies;

DATA WORK.MJUse;
    LENGTH
        fname $ 300
        year 8
        recency $ 52
        age_cat $ 19
        Total_percent            8
        Total___SE         8
        Total___CI__lower_ 8
        Total___CI__upper_ 8
        Row_percent             8
        Row___SE           8
        Row___CI__lower_ 8
        Row___CI__upper_ 8
        Column__           8
        Column___SE        8
        Column___CI__lower_ 8
        Column___CI__upper_ 8
        Weighted_Count     8
        Unweighted_Count   8
        Count_SE           8 ;
    LABEL
        recency = "MARIJUANA RECENCY - IMPUTATION REVISED"
        age_cat = "Age (recoded)"
        Total_percent          = "Total %"
        Total___SE       = "Total % SE"
        Total___CI__lower_ = "Total % CI (lower)"
        Total___CI__upper_ = "Total % CI (upper)"
        Row_percent           = "Row %"
        Row___SE         = "Row % SE"
        Row___CI__lower_ = "Row % CI (lower)"
        Row___CI__upper_ = "Row % CI (upper)"
        Column__         = "Column %"
        Column___SE      = "Column % SE"
        Column___CI__lower_ = "Column % CI (lower)"
        Column___CI__upper_ = "Column % CI (upper)"
        Weighted_Count   = "Weighted Count"
        Unweighted_Count = "Unweighted Count"
        Count_SE         = "Count SE" ;

    INFILE "&workloc./usa_*.csv"
        filename=fname
        LRECL=32767
        FIRSTOBS=2
        ENCODING="UTF-8"
        DLM='2c'x
        MISSOVER
        DSD ;
    INPUT
        recency 
        age_cat 
        Total_percent      
        Total___SE      
        Total___CI__lower_ 
        Total___CI__upper_ 
        Row_percent          
        Row___SE        
        Row___CI__lower_
        Row___CI__upper_ 
        Column__        
        Column___SE     
        Column___CI__lower_
        Column___CI__upper_ 
        Weighted_Count   
        Unweighted_Count 
        Count_SE         ;


        year = input(scan(fname,-2,'._'),4.);
        if recency ^= "Overall" and age_cat ^= "Overall" and Weighted_count;

        keep year recency age_cat used_12mo 
             row_percent;
        format weighted_count comma12.;

        used_12mo = ( char(recency,1) in ('1','2') );
RUN;

proc sql;
 create table mjsum as 
  select year, age_cat, 
    sum(row_percent) as row_percent
  from mjuse
  where used_12mo=1
  group by year, age_cat;
quit;

ods graphics / width=450 height=600;
/* Use this ODS mod in EG 8.1 to get graph title in image */
/*ods html5(id=eghtml) gtitle;*/
title "Self-reported Marijuana use in past 12 months";
title2 "ALL US STATES, Annual survey";
proc sgplot data=work.mjsum ;
   inset "Source:" "National Survey on Drug Use and Health" "samhsa.gov"
      / position=topleft border backcolor=white ; 
 series x=year y=row_percent / 
   group=age_cat 
   lineattrs=(thickness=4pt);
 xaxis minor values=(2008 to 2017 by 1)  display=(nolabel)  ;
 format 
   row_percent percent4.1;
 yaxis grid display=(nolabel) values=(0 to 1 by 0.05);
   keylegend / location=outside position=topleft across=1;
run;
