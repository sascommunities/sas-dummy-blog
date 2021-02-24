filename nh temp;
proc http
 url="https://data.cms.gov/api/views/s2uc-8wxp/rows.csv?accessType=DOWNLOAD"
 method="GET"
 out=nh;
run;



options validvarname=v7;
proc import file=nh
 out=covid19nh
 dbms=csv
 replace;
run;

