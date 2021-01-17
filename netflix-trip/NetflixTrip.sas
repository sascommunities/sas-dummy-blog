/* Utility macro to check if folder is empty before Git clone */ 
%macro FolderIsEmpty(folder);
  %local memcount;
  %let memcount = 0;
	%let filrf=mydir;
  	%let rc=%sysfunc(filename(filrf, "&folder."));
  %if &rc. = 0 %then %do;
  	%let did=%sysfunc(dopen(&filrf));
  	%let memcount=%sysfunc(dnum(&did));
  	%let rc=%sysfunc(dclose(&did));
    %let rc=%sysfunc(filename(filrf));
  %end;
  /* Value to return: 1 if empty, else 0 */
  %sysevalf(&memcount. eq 0)
%mend;

options dlcreatedir;
%let repopath=%sysfunc(getoption(WORK))/sas-netflix-git;
libname repo "&repopath.";
data _null_;
 if (%FolderIsEmpty(&repoPath.)) then do;
    	rc = gitfn_clone( 
      	"https://github.com/cjdinger/sas-netflix-git", 
      	"&repoPath." 
    				); 
    	put 'Git repo cloned ' rc=; 
    end;
    else put "Skipped Git clone, folder not empty";
run;

filename viewing "&repopath./NetflixData/*.csv";
data viewing (keep=title date profile maintitle episode season);
 length title $ 300 date 8 
        maintitle $ 60 episode $ 40 season $ 12
        profile $ 40 in $ 250;
 format date date9.;
 infile viewing dlm=',' dsd filename=in firstobs=2;
 profile=scan(in,-1,'\/');
 input title date:??mmddyy.;
 if date^=. and title ^="";
 array part $ 60 part1-part4;
 do i = 1 to 4;
	part{i} = scan(title, i, ':',);
  if (find(part{i},"Season")>0)
   then do;
     season=part{i};
   end;
	end;
 drop i;
 maintitle = part{1};
 episode = part{3};
run;

PROC SQL noprint;
   CREATE TABLE WORK.Office AS 
   SELECT t1.date, 
            (COUNT(t1.date)) AS Episodes
      FROM WORK.VIEWING t1
      WHERE t1.maintitle = 'The Office (U.S.)' 
      GROUP BY t1.date ;
      %let days = &sqlobs;

   select sum(episodes) into:episodes trimmed from office;
QUIT;

data dates;
 length date 8 year 8 day 8 month 8 monyear 8 ;
 format date date9. monyear yymmd7.;
 do date='01oct2017'd to '01jan2021'd;
  year=year(date);
  day = day(date);
  month=month(date);
  monyear = intnx('month',date,0,'b');
  output;
 end;
run;

proc sql noprint;
 create table ofc_viewing as 
  select t1.*, 
  case 
   when t2.Episodes not is missing then t2.Episodes
   else 0
  end as Episodes
  from dates t1 left join office t2
  on (t1.date=t2.date)
 ;

 select distinct monyear format=6. into: allmon separated by ' ' from ofc_viewing;
quit;

/* for use in SAS Enterprise Guide to overide styles */
ods html5(id=eghtml) gtitle gfootnote style=raven;

ods graphics / width=1100 height=1000 ;
proc sgplot data=ofc_viewing;
 title height=2.5 "The Office - a Netflix Journey";
 title2 height=2 "&episodes. episodes streamed on &days. days, over 3 years";
 label Episodes="Episodes per day";
 format monyear monyy7.;
 heatmapparm x=day y=monyear 
   colorresponse=episodes / x2axis
    outline
   colormodel=(white  CXfcae91 CXfb6a4a CXde2d26 CXa50f15) ;
 yaxis  minor reverse display=(nolabel) 
  values=(&allmon.)
  ;
 x2axis values=(1 to 31 by 1) 
   display=(nolabel)  ;
run;

title "Frequency of Episodes per Season";
ods graphics  / height=400 width=800;
proc freq data=viewing order=formatted;
 where maintitle  = 'The Office (U.S.)';
 table season / plots=freqplot;
run;




