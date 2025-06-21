/* 
   This script retrieves bird detection data from BirdNET-Pi and generates a heatmap of bird detections by day.
   The data is sourced from a CSV file hosted on GitHub.
*/
filename birdcsv temp;
proc http
 method="GET"
 url="https://raw.githubusercontent.com/cjdinger/birdnet-data/refs/heads/main/alldetect.csv"
 out=birdcsv;
run;

 /* Import the bird detection data from the CSV file into a SAS dataset;
   The dataset will contain columns for date, time, scientific name, common name, confidence level, 
   latitude, longitude,cutoff value, week number, sensitivity, overlap, and file name. */
   
data WORK.BIRDS_EVENTS;
  infile BIRDCSV delimiter = ',' MISSOVER DSD lrecl=32767 firstobs=2;
  informat Date yymmdd10.;
  informat Time time20.3;
  informat Sci_Name $30.;
  informat Com_Name $30.;
  informat Confidence best32.;
  informat Lat best32.;
  informat Lon best32.;
  informat Cutoff best32.;
  informat Week best32.;
  informat Sens best32.;
  informat Overlap best32.;
  informat File_Name $57.;
  format Date yymmdd10.;
  format Time time20.3;
  format Sci_Name $30.;
  format Com_Name $30.;
  format Confidence best12.;
  format Lat best12.;
  format Lon best12.;
  format Cutoff best12.;
  format Week best12.;
  format Sens best12.;
  format Overlap best12.;
  format File_Name $57.;
  input
    Date
    Time
    Sci_Name  $
    Com_Name  $
    Confidence
    Lat
    Lon
    Cutoff
    Week
    Sens
    Overlap
    File_Name  $
  ;
run;

/* Create a summary table of bird detections by day and family */
PROC SQL;
  CREATE TABLE WORK.birds_DailyDetect AS 
    SELECT t1.Date, 
      t1.Sci_Name, 
      t1.Com_Name, 
      scan(t1.Com_Name,-1,' ') as Family,
      /* Detections */
  (COUNT(t1.Date)) AS Detections FROM WORK.birds_events t1 GROUP BY t1.Date, Family, t1.Sci_Name, t1.Com_Name;
QUIT;

/* Sort the 'birds_dailyDetect' dataset by the 'Family' variable */
proc sort data=birds_dailyDetect;
  by Family;
run;


ods graphics / width=1000 height=2000;
/* ods html5(eghtml) gtitle; */

/* Create a scatter plot of bird detections by day */
proc sgplot data=work.birds_DailyDetect;
  title "Birdsong Detections by Day - from BirdNET-Pi";
  scatter x=Date y=Com_Name / colorresponse=Detections  
    colormodel=(lightblue lightgreen darkgreen lightorange orange red darkred) markerattrs=(size=4)
  ;
  xaxis grid minor;
  yaxis  fitpolicy=none grid minor valueattrs=(size=8pt) display=(nolabel);
run;