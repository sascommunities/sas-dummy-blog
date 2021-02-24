/* PROC HTTP and JSON libname test          */
/* Requires SAS 9.4m4 or later to run       */
/* SAS University Edition Dec 2017 or later */
 
filename resp "%sysfunc(getoption(WORK))/stream.json";
proc http
 url="https://httpbin.org/stream/1"
 method="GET"
 out=resp;
run;
 
/* Supported with SAS 9.4 Maint 5 */
%put HTTP Status code = &SYS_PROCHTTP_STATUS_CODE. : &SYS_PROCHTTP_STATUS_PHRASE.; 

 
data _null_;
 rc = jsonpp('resp','log');
run;
 
/* Tell SAS to parse the JSON response */
libname stream JSON fileref=resp;
 
title "JSON library structure";
proc datasets lib=stream;
quit;

data all;
 set stream.alldata;
run;
 
libname stream clear;
filename resp clear;