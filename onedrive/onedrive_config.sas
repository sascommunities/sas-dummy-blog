/*
  Set the variables that will be needed through the code
  We'll need these for authorization and also for runtime 
  use of the service.
 
  Reading these from a config.json file so that the values
  are easy to adapt for different users or projects.
*/

%if %symexist(config_root) %then %do;
  filename config "&config_root./config.json";
  libname config json fileref=config;
  data _null_;
   set config.root;
   call symputx('tenant_id',tenant_id,'G');
   call symputx('client_id',client_id,'G');
   call symputx('redirect_uri',redirect_uri,'G');
   call symputx('resource',resource,'G');
  run;
%end;
%else %do;
  %put ERROR: You must define the CONFIG_ROOT macro variable.; 
%end;