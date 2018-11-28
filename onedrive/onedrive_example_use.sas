/* ----------------------------------------------------
 Example API calls from SAS to 
 Microsoft Office 365 OneDrive.

 Authors: Joseph Henry, SAS
          Chris Hemedinger, SAS
 Copyright 2018, SAS Institute Inc.
-------------------------------------------------------*/

%let config_root=/folders/myfolders/onedrive;

%include "&config_root./onedrive_config.sas";
%include "&config_root./onedrive_macros.sas";

/*
  Our json file that contains the oauth token information
*/
filename token "&config_root./token.json";

/* Note: %if/%then in open code supported in 9.4m5 */
%if (%sysfunc(fexist(token)) eq 0) %then %do;
 %put ERROR: &config_root./token.json not found.  Run the setup steps to create the API tokens.;
%end;

/*
 If the access_token expires, we can just use the refresh token to get a new one.

 Some reasons the token (and refresh token) might not work:
  - Explicitly revoked by the app developer or admin
  - Password change in the user account for Microsoft Office 365
  - Time limit expiration

 Basically from this point on, user interaction is not needed.

 We assume that the token will only need to be refreshed once per session, 
 and right at the beginning of the session. 

 If a long running session is needed (>3600 seconds), 
 then check API calls for a 401 return code
 and call %refresh if needed.
*/

%process_token_file(token);

/* If this is first use for the session, we'll likely need to refresh  */
/* the token.  This will also call process_token_file again and update */
/* our token.json file.                                                */
%refresh(&client_id.,&refresh_token.,&resource.,token,tenant=&tenant_id.);

/*
  At this point we have a valid access token and we can start using the api.
*/

/*
First we need the ID of the "drive" we are going to use.
to list the drives the current user has access to you can do this
*/
filename resp TEMP;
/* Note: oauth_bearer option added in 9.4M5 */
proc http url="https://graph.microsoft.com/v1.0/me/drives/"
     oauth_bearer="&access_token"
     out = resp;
	 run;

libname jresp json fileref=resp;

/*
 I only have access to 1 drive, but if you have multiple you can filter 
 the set with a where clause on the name value.
 
 This creates a data set with the one record for the drive.
*/
data drive;
 set jresp.value;
run;

/* store the ID value for the drive in a macro variable */
proc sql noprint;
 select id into: driveId from drive;
quit;


/* LIST TOP LEVEL FOLDERS/FILES */

/*
 To list the items in the drive, use the /children verb with the drive ID
*/
filename resp TEMP;
proc http url="https://graph.microsoft.com/v1.0/me/drives/&driveId./items/root/children"
     oauth_bearer="&access_token"
     out = resp;
	 run;

libname jresp json fileref=resp;

/* Create a data set with the top-level paths/files in the drive */
data paths;
 set jresp.value;
run;

/* LIST ITEMS IN A SPECIFIC FOLDER */

/*
 At this point, if you want to act on any of the items, you just replace "root" 
 with the ID of the item. So to list the items in the "SASGF" folder I have:
  - find the ID for that folder
  - list the items within by using the "/children" verb
*/

/* Find the ID of the folder I want */
proc sql noprint;
 select id into: folderId from paths
  where name="SASGF";
quit;

filename resp TEMP;
proc http url="https://graph.microsoft.com/v1.0/me/drives/&driveId./items/&folderId./children"
     oauth_bearer="&access_token"
     out = resp;
	 run;

/* This creates a data set of the items in that folder, 
   which might include other folders.
*/
libname jresp json fileref=resp;
data folderItems;
 set jresp.value;
run;

/* DOWNLOAD A FILE FROM ONEDRIVE TO SAS SESSION */

/*
 With a list of the items in this folder, we can download
 any item of interest by using the /content verb 
*/

/* Find the item with a certain name */
proc sql noprint;
 select id into: fileId from folderItems
  where name="sas_tech_talks_18.xlsx";
quit;

filename fileout "&config_root./sas_tech_talks_18.xlsx";
proc http url="https://graph.microsoft.com/v1.0/me/drives/&driveId./items/&fileId./content"
     oauth_bearer="&access_token"
     out = fileout;
	 run;

proc import file=fileout 
 out=sasgf
 dbms=xlsx replace;
run;
/* UPLOAD A NEW FILE TO ONEDRIVE */
/*
  We can upload a new file to that same folder with the PUT method and /content verb
  Notice the : after the folderId and the target filename
*/

/* Create a simple Excel file to upload */
%let targetFile=iris.xlsx;
filename tosave "%sysfunc(getoption(WORK))/&targetFile.";
ods excel(id=upload) file=tosave;
proc print data=sashelp.iris;
run;
ods excel(id=upload) close;

filename details temp;
proc http url="https://graph.microsoft.com/v1.0/me/drives/&driveId./items/&folderId.:/&targetFile.:/content"
  method="PUT"
  in=tosave
  out=details
  oauth_bearer="&access_token";
run;

/*
  This returns a json response that describes the item uploaded.
  This step pulls out the main file attributes from that response.
*/
libname attrs json fileref=details;
data newfileDetails (keep=filename createdDate modifiedDate filesize);
 length filename $ 100 createdDate 8 modifiedDate 8 filesize 8;
 set attrs.root;
 filename = name;
 modifiedDate = input(lastModifiedDateTime,anydtdtm.);
 createdDate  = input(createdDateTime,anydtdtm.);
 format createdDate datetime20. modifiedDate datetime20.;
 filesize = size;
run;

/* REPLACE AN EXISTING FILE IN ONEDRIVE */

/*
  If you want to replace a file instead of making a new file 
  then you need to upload it with the existing file ID.  If you
  don't replace it with the existing ID, some sharing properties
  and history could be lost.
*/

proc sql noprint;
 select id into: folderId from paths
  where name="SASGF";
quit;

proc http url="https://graph.microsoft.com/v1.0/me/drives/&driveId./items/&folderId./children"
     oauth_bearer="&access_token"
     out = resp;
	 run;

libname jresp json fileref=resp;
data folderItems;
 set jresp.value;
run;

proc sql noprint;
 select id into: fileId from folderItems
  where name="iris.xlsx";
quit;

libname attrs json fileref=details;
proc http url="https://graph.microsoft.com/v1.0/me/drives/&driveId./items/&fileId./content"
 method="PUT"
 in=tosave
 out=details
 oauth_bearer="&access_token";
run;

/*
  Capture the file details from the response
*/
libname attrs json fileref=details;
data replacefileDetails (keep=filename createdDate modifiedDate filesize id mimeType);
 length filename $ 100 createdDate 8 modifiedDate 8 filesize 8;
 merge attrs.root attrs.file;
 by ordinal_root;
 filename = name;
 modifiedDate = input(lastModifiedDateTime,anydtdtm.);
 createdDate  = input(createdDateTime,anydtdtm.);
 format createdDate datetime20. modifiedDate datetime20.;
 filesize = size;
run;

