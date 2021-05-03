/* Adapted from Robert Allison's blog post 30-Apr2021 */
/* https://blogs.sas.com/content/graphicallyspeaking/feeling-the-effects-of-the-2020-census/    */
/* Adjusted to run well in SAS Studio (SAS OnDemand for Academics, SAS University Edition, etc) */

/*
Using Census data from:
  https://www.census.gov/data/tables/2020/dec/2020-apportionment-data.html
  Specifically:
  https://www2.census.gov/programs-surveys/decennial/2020/data/apportionment/apportionment-2020-table01.xlsx
*/

/* Use PROC HTTP to fetch data dynamically */
filename census temp;

proc http 
    url="https://www2.census.gov/programs-surveys/decennial/2020/data/apportionment/apportionment-2020-table01.xlsx" 
	out=census;
run;

/* Force PROC IMPORT to use V7 (traditional) rules for var names */
options validvarname=v7;

/* Import the census data */
/* pull from a specific range, rename variables in output */
proc import file=census out=my_data 
     (rename=(state=state_name 
		      var2=apport_population 
              NUMBER_OF_APPORTIONED_REPRESENTA=reps 
		      CHANGE_FROM___2010_CENSUS_APPORT=change_reps)) 
      dbms=xlsx replace;
	getnames=yes;
	range='Table 1$A4:D54';
run;

/* Merge in the 2-character state code for each state_name */
proc sql noprint;
	create table withcodes as select unique my_data.*, us_data.statecode from 
		my_data left join sashelp.us_data on my_data.state_name=us_data.statename;
quit;

run;

/* Create dataset of the labels to overlay */
data my_labels;
	set withcodes (where=(change_reps^=0));
	length change_reps_text $10;
	if change_reps>0 then
		change_reps_text='+'||trim(left(change_reps));
	else
		change_reps_text=trim(left(change_reps));
run;

/* Get the projected x/y centroid, that match up with the mapsgfk.us */
proc sql noprint;
	create table centroids as select unique my_labels.*, uscenter.x, uscenter.y 
		from my_labels left join mapsgfk.uscenter on 
		my_labels.statecode=uscenter.statecode;
quit;

run;

/* get the map polygons, excluding DC */
data my_map;
	set mapsgfk.us (where=(statecode^='DC'));
run;

/* sort the data (this can affect the order of the colors) */
proc sort data=my_data out=my_data;
	by change_reps;
run;

ods html5(id=web) gtitle gfootnote;
ods graphics / 
	noscale /* if you don't use this option, the text will be resized */
	imagemap tipmax=2500 width=900px height=600px;

title1 color=gray33 height=20pt 
	"State Apportionment Changes based on 2020 Census";
footnote color=cornflowerblue height=12pt 
    "Source: https://www.census.gov/data/tables/2020/dec/2020-apportionment-data.html";

proc sgmap maprespdata=withcodes mapdata=my_map plotdata=centroids noautolegend;
	styleattrs datacolors=(white cxfdbf6f cxb2df8a cx33a02c);
	choromap change_reps / discrete mapid=statecode lineattrs=(thickness=1 
		color=gray88) tip=(state_name reps change_reps);
	text x=x y=y text=change_reps_text / position=center textattrs=(color=gray33 
		size=14pt weight=bold) tip=none;
run;