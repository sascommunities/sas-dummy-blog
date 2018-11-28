/* ----------------------------------------------------
 Utility macros to manage and refresh the access token
 for using Microsoft OneDrive APIs from SAS,
 using PROC HTTP.

 Authors: Joseph Henry, SAS
          Chris Hemedinger, SAS
 Copyright 2018, SAS Institute Inc.
-------------------------------------------------------*/

/*
  Utility macro to process the JSON token 
  file that was created at authorization time.
  This will fetch the access token, refresh token,
  and expiration datetime for the token so we know
  if we need to refresh it.
*/
%macro process_token_file(file);
  libname oauth json fileref=&file.;

  data _null_;
    set oauth.root;
    call symputx('access_token', access_token,'G');
    call symputx('refresh_token', refresh_token,'G');
    /* convert epoch value to SAS datetime */
    call symputx('expires_on',(input(expires_on,best32.)+'01jan1970:00:00'dt),'G');
  run;
%mend;

/*
  Utility macro that retrieves the initial access token
  by redeeming the authorization code that you're granted
  during the interactive step using a web browser
  while signed into your Microsoft OneDrive / Azure account.

  This step also creates the initial token.json that will be
  used on subsequent steps/sessions to redeem a refresh token.
*/
%macro get_token(client_id,
      code,
      resource,
      outfile,
      redirect_uri=https://login.microsoftonline.com/common/oauth2/nativeclient,
      tenant=common,
      debug=0);

  proc http url="https://login.microsoft.com/&tenant_id./oauth2/token"
    method="POST"
    in="%nrstr(&client_id)=&client_id.%nrstr(&code)=&code.%nrstr(&redirect_uri)=&redirect_uri%nrstr(&grant_type)=authorization_code%nrstr(&resource)=&resource."
    out=&outfile.;
    %if &debug>=0 %then
      %do;
        debug level=&debug.;
      %end;
    %else %if &_DEBUG_. ge 1 %then
      %do;
        debug level=&_DEBUG_.;
      %end;
  run;

  %process_token_file(&outfile);
%mend;

/*
  Utility macro to redeem the refresh token 
  and get a new access token for use in subsequent
  calls to the OneDrive service.
*/
%macro refresh(client_id,
      refresh_token,
      resource,
      outfile,
      redirect_uri=https://login.microsoftonline.com/common/oauth2/nativeclient,
      tenant=common,
      debug=0);

  proc http url="https://login.microsoft.com/&tenant_id./oauth2/token"
    method="POST"
    in="%nrstr(&client_id)=&client_id.%nrstr(&refresh_token=)&refresh_token%nrstr(&redirect_uri)=&redirect_uri.%nrstr(&grant_type)=refresh_token%nrstr(&resource)=&resource."
    out=&outfile.;
    %if &debug. ge 0 %then
      %do;
        debug level=&debug.;
      %end;
    %else %if %symexist(_DEBUG_) AND &_DEBUG_. ge 1 %then
      %do;
        debug level=&_DEBUG_.;
      %end;
  run;

  %process_token_file(&outfile);
%mend refresh;