/* Copyright 2019 SAS Institute Inc. */

/* Create dummy JSON to represent the recommendation engine */
/* API response */

filename apiout temp;
data _null_;
file apiout;
infile datalines;
input;
put _infile_;
datalines4;
{
    "anonymous_astore_creation": "05Sep2019:13:05:00",
    "astore_creation": "05Sep2019:13:30:06",
    "conversation_uid": "[250217,20045,216873,196443,251360]",
    "cooloff_records": 65239,
    "cooloff_users": 29540,
    "creation": "Thu Sep  5 13:30:41 2019",
    "num_topics": 78378,
    "num_users": 148686,
    "personalized": true,
    "process_time": "0.3103 seconds"
}
;;;;
run;

/* Create the first part of the boilerplate for the message card */
filename heading temp;
data _null_;
ts = cat('"activitySubtitle": "As of ',"%trim(%sysfunc(datetime(),datetime20.))",'",');
infile datalines4;
file heading;
input;
if (find(_infile_,"TIMESTAMP")>0)
  then put ts;
else put _infile_;
datalines4;
{
	"@type": "MessageCard",
	"@context": "https://schema.org/extensions",
	"summary": "Recommendation Engine Health Check",
	"themeColor": "0075FF",
	"sections": [
		{
			"startGroup": true,
			"title": "**Recommendation Engine Heartbeat**",
			"activityImage": "",
			"activityTitle": "**PRODUCTION** endpoint check",			 
TIMESTAMP
			"facts":
;;;;
run;

/* Read the "API response" */
libname prod json fileref=apiout;

data segment (keep=name value);
 set prod.root;
 name="Score data updated (UTC)";
 value= astore_creation;
 output;
 name="Topics scored";
 value=left(num_topics);
 output;
 name="Number of users";
 value= left(num_users);
 output;
 name="Process time";
 value= process_time;
 output;
run;

/* generate the "Facts" segment */
filename segment temp;
proc json out=segment nosastags pretty;
 export segment;
run;

/* Combine it all together */
filename msg temp;
data _null_;
 file msg;
 infile heading end=eof;
 do while (not eof);
   input;
   put _infile_;
 end;
 infile segment end=eof2;
 do while (not eof2);
   input;
   put _infile_;
   if eof2 then put "} ] }";
 end; 
run;

/* Publish to Teams channel with a webhook */
proc http
 method="POST"
 ct="text/plain"
 url="https://outlook.office.com/webhook/my-unique-webhook-endpoint"
 in=msg;
run;
