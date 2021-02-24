filename resp temp;
proc http 
 url="http://httpbin.org/post"
 method="POST"
 in="custname=Joe%str(&)size=large%str(&)topping=cheese"
 out=resp;
run;

data _null_;
 rc = jsonpp('resp','log');
run; 

