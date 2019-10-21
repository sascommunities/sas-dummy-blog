/* ----------------------------------------------------
 Example API calls from SAS to 
 Microsoft Office 365 SharePoint Online.

 Authors: Joseph Henry, SAS
          Chris Hemedinger, SAS
 Copyright 2019, SAS Institute Inc.
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
 Now we have a file on disk named token.json. 
 We should not need to interact with the web browser any more for quite a long time.
 If the access_token expires, we can just use the refresh token to get a new one.

 Some reasons the token (and refresh token) might not work:
  - Explicitly revoked by the app developer or admin
  - Password change in the user account for Microsoft Office 365
  - Time limit expiration

 Basically from this point on, user interaction is not needed.

 We can write code to see if the token need to be refreshed.
 We assume that the token will only need to be refreshed once per session, 
 and right at the beginning of the session. 

 If a long running session is needed (>3600 seconds), 
 then check API calls for a 401 return code
 and call %refresh_token if needed.
*/

%process_token_file(token);

/* This "open code" %if-%then-%else is supported as of 9.4M5   */
/* Check whether the token is aging out, and refresh if needed */
%if &expires_on < %sysevalf(%sysfunc(datetime()) - %sysfunc(gmtoff())) %then %do;
 %refresh(&client_id.,&refresh_token.,&resource.,token,tenant=&tenant_id.);
%end;

filename resp temp;

/* Note: oauth_bearer option added in 9.4M5                       */
/* Using the /sites methods in the Microsoft Graph API            */
/* May require the Sites.ReadWrite.All permission for your app    */
/* See https://docs.microsoft.com/en-us/graph/api/resources/sharepoint?view=graph-rest-1.0 */
/* Set these values per your SharePoint Online site.
   Ex: https://yourcompany.sharepoint.com/sites/YourSite 
    breaks down to:
       yourcompany.sharepoint.com -> hostname
       /sites/YourSite -> sitepath

   This example uses the /drive method to access the files on the
   Sharepoint site -- works just like OneDrive.
   API also supports a /lists method for SharePoint lists.
   Use the Graph Explorer app to find the correct APIs for your purpose.
    https://developer.microsoft.com/en-us/graph/graph-explorer
*/
%let hostname = yourcompany.sharepoint.com;
%let sitepath = /sites/YourSite;
proc http url="https://graph.microsoft.com/v1.0/sites/&hostname.:&sitepath.:/drive"
     oauth_bearer="&access_token"
     out = resp;
	 run;

libname jresp json fileref=resp;

/*
 This creates a data set with the one record for the drive.
 Need this object to get the Drive ID
*/
data drive;
 set jresp.root;
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
 with the ID of the item. So to list the items in the "General" folder I have:
  - find the ID for that folder
  - list the items within by using the "/children" verb
*/

/* Find the ID of the folder I want */
proc sql noprint;
 select id into: folderId from paths
  where name="General";
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


/* DOWNLOAD A FILE FROM SharePoint TO SAS SESSION */

/*
 With a list of the items in this folder, we can download
 any item of interest by using the /content verb 
*/

/* Find the item with a certain name                    */
/* My example uses an Excel file called "pmessages.xlsx */
/* Which this downloads and then imports as SAS data    */
proc sql noprint;
 select id into: fileId from folderItems
  where name="pmessages.xlsx";
quit;

filename fileout "&config_root./pmessages.xlsx";
proc http url="https://graph.microsoft.com/v1.0/me/drives/&driveId./items/&fileId./content"
     oauth_bearer="&access_token"
     out = fileout;
	 run;

proc import file=fileout 
 out=pmessages
 dbms=xlsx replace;
run;


/* UPLOAD A NEW FILE TO SharePoint */
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
