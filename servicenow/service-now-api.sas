%macro getSNaccessToken;
  filename creds "&credsLoc";

  /* ===== Build application/x-www-form-urlencoded body ===== */
  filename tok temp;
  data _null_;
    infile creds(service-now-creds.csv)  dsd firstobs=2;
    length client_id $ 40 client_secret $ 40 username $ 40 password $ 250 out $ 500;
    length d1-d5 $ 600;
    input client_id client_secret username password;
    d1 = "grant_type=password";
    d2 = catt('client_id=',urlencode(trim(client_id)));
    d3 = catt('client_secret=',urlencode(trim(client_secret)));
    d4 = catt('username=',urlencode(trim(username)));
    d5 = catt('password=',urlencode(trim(password)));
    out = catx('&',d1,d2,d3,d4,d5);
    ;
    /* Store API input data in macro var */
    call symputx('SN_CRED',out);
  run;

  /* ===== Call token endpoint ===== */
  filename tokresp temp;

  proc http
    url="&SN_INSTANCE./oauth_token.do"
    method="POST"
    in="&SN_CRED"
    out=tokresp
    ct="application/x-www-form-urlencoded";
  run;

  %if (&SYS_PROCHTTP_STATUS_CODE. = 200) %then %do;
    /* ===== Parse JSON and extract access_token ===== */
    /* Save token and refresh token in secure area for next access */
    libname tokjson json fileref=tokresp;
    filename savetok "&credsLoc./sntoken.json";

    /* token fields often appear in tokjson.root */
    data _null_;
      rc = fcopy('tokresp','savetok');  
      set tokjson.root;
      if not missing(access_token) then do;
        call symputx('snAccessToken', access_token, 'G');
      end;
    run;

    /* Debugging only */
    %put NOTE: Token acquired successfully;

    libname tokjson clear;
    filename savetok clear;
  %end;

  filename tokresp clear;
%mend;

%macro refreshSNaccessToken;
  /* Now use the Refresh token instead of username/password */

  filename reftok "&credsLoc./sntoken.json";
  libname tokjson json fileref=reftok;


  /* token fields often appear in tokjson.root */
  data _null_;
    set tokjson.root;
    if not missing(refresh_token) then do;
      call symputx('refreshToken', refresh_token, 'G');
    end;
  run;


  data _null_;
    infile creds(service-now-creds.csv)  dsd firstobs=2;
    length client_id $ 40 client_secret $ 40 out $ 500;
    length d1-d4 $ 600;
    input client_id client_secret username password;
    d1 = "grant_type=refresh_token";
    d2 = catt('client_id=',urlencode(trim(client_id)));
    d3 = catt('client_secret=',urlencode(trim(client_secret)));
    d4 = catt('refresh_token=',urlencode(trim("&refreshToken.")));
    out = catx('&',d1,d2,d3,d4);
    ;
    /* Store API input data in macro var */
    call symputx('SN_CRED',out);
  run;

  /* ===== Call token endpoint ===== */
  filename tokresp temp;

  proc http
    url="&SN_INSTANCE./oauth_token.do"
    method="POST"
    in="&SN_CRED"
    out=tokresp
    ct="application/x-www-form-urlencoded";
    debug level=3;
  run;

  %if (&SYS_PROCHTTP_STATUS_CODE. = 200) %then %do;
    /* ===== Parse JSON and extract access_token ===== */
    /* Save token and refresh token in secure area for next access */
    libname tokjson json fileref=tokresp;
    filename savetok "&credsLoc./sntoken.json";

    data _null_;
      rc = fcopy('tokresp','savetok');  
      set tokjson.root;
      if not missing(access_token) then do;
        call symputx('snAccessToken', access_token, 'G');
      end;
    run;

    /* Debugging only */
    %put NOTE: Token refreshed successfully.

    libname tokjson clear;
    filename savetok clear;
  %end;

  filename tokresp clear;
%mend;

/* REPLACE WITH YOUR SERVICE-NOW INSTANCE URL */
%let SN_INSTANCE=https://dev12345.service-now.com;
/* Store the credentials in a secure area */
/* assumes you have a CSV file here named service-now-creds.csv */
/* with client-id, client-secret, username, password */
/* change path style for Windows if needed */
%let credsLoc = /u/&sysuserid./.creds/sn;

/* First time, uses username/password */
/* On success, creates sntoken.json in credentials folder */
/* and sets snAccessToken macro variable for use in API calls */
%getSNaccessToken;


/* subsequent uses, use refresh token to get a new access token */
/* Relies on refresh-token from sntoken.json created previously */
/* no longer need username & password, but still need client-id and client-secret */
%refreshSNaccessToken;

/* Sample API Call */
/* Query the Incident table with limited parms */
filename results temp;
proc http
  url="&SN_INSTANCE./api/now/table/incident?sysparm_fields=number%2Cresolved_by%2Copened_by%2Cshort_description&sysparm_limit=10"
  method="GET"
  out=results
  ct="application/json"
  oauth_bearer="&snAccessToken.";
run;

libname incident json fileref=results;

proc print data=incident.result(obs=5);
 var number short_description;
run;

libname incident clear;
filename results clear;