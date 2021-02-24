options ps=max;
/* Neat service from Open Notify project */
filename resp temp;
proc http 
 url="http://api.open-notify.org/astros.json"
 method= "GET"
 out=resp;
run;

data _null_;
 rc = jsonpp('resp','log');
run; 

/* Assign a JSON library to the HTTP response */
libname space JSON fileref=resp;
