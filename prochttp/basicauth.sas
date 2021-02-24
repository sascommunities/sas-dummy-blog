filename resp temp;
proc http 
 url="http://httpbin.org/basic-auth/chris/pass125"
 method="GET"
 AUTH_BASIC
 out=resp
 webusername="chris"
 webpassword="pass125"
 ;
run;

data _null_;
 rc = jsonpp('resp','log');
run;