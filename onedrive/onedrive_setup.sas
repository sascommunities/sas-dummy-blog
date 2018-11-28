/* 
  This file contains steps that you perform just once to
  set up a new project. You'll use these steps to get an
  access code and your initial authentication tokens.

  You might need to repeat this step later if your 
  Microsoft Office 365 credentials change (including password) 
  or if the tokens are revoked by using another method.

*/
%let config_root=/folders/myfolders/onedrive;

%include "&config_root./onedrive_config.sas";
%include "&config_root./onedrive_macros.sas";

/*
Our json file that contains the oauth token information
*/
filename token "&config_root./token.json";

/* Do these steps JUST ONCE, interactively,
   for your application and user account. 

   Get the code from the URL in the browser and set it below
   as the value of auth_code.

   The authorization code is going to be a LONG character value.
*/

/* Run this line to build the authorization URL */
%let authorize_url=https://login.microsoftonline.com/&tenant_id./oauth2/authorize?client_id=&client_id.%nrstr(&response_type)=code%nrstr(&redirect_uri)=&redirect_uri.%nrstr(&resource)=&resource.;
options nosource;
%put Paste this URL into your web browser:;
%put -- START -------;
%put &authorize_url;
%put ---END ---------;
options source;

/* 
 Copy the value of the authorize_url into a web browser.
 Log into your OneDrive account as necessary.
 The browser will redirect to a new address.  
 Copy the auth_code value from that address into the following 
 macro variable.  Then run the next two lines (including %get_token macro).

 Note: this code can be quite long -- 700+ characters.
*/
%let auth_code=;

/*
  Now that we have an authorization code we can get the access token
  This step will write the tokens.json file that we can use in our
  production programs.
*/
%get_token(&client_id.,&auth_code,&resource.,token,tenant=&tenant_id,debug=3);
