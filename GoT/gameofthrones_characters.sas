filename eps temp;

/* Big thanks to this GoT data nerd for assembling this data */
proc http
 url="https://raw.githubusercontent.com/jeffreylancaster/game-of-thrones/master/data/episodes.json"
 out=eps
 method="GET";
run;

/* slurp this in with the JSON engine */
libname episode JSON fileref=eps;

/* Build details of scenes and characters who appear in them */
PROC SQL;
   CREATE TABLE WORK.character_scenes AS 
   SELECT t1.seasonNum, 
          t1.episodeNum, 
          input(t2.sceneStart,time.) as time_start format=time., 
          input(t2.sceneEnd,time.) as time_end format=time., 
          (calculated time_end) - (calculated time_start) as duration,
          t3.name
      FROM EPISODE.EPISODES t1, 
           EPISODE.EPISODES_SCENES t2, 
           EPISODE.SCENES_CHARACTERS t3
      WHERE (t1.ordinal_episodes = t2.ordinal_episodes AND 
             t2.ordinal_scenes = t3.ordinal_scenes);
QUIT;

/* Sum up the screen time per character, per episode */
PROC SQL;
   CREATE TABLE WORK.per_episode AS 
   SELECT t1.seasonNum, 
          t1.episodeNum, 
          /* timePerEpisode */
            (SUM(t1.duration)) AS timePerEpisode, 
          t1.name,
          cat("Season ",seasonNum,", Ep ",episodeNum) as epLabel
      FROM WORK.CHARACTER_SCENES t1
      GROUP BY t1.seasonNum,
               t1.episodeNum,
               t1.name
      order by seasonNum, episodeNum, name;
QUIT;

/* Assign ranks so we can filter to just top 10 per episode */
PROC RANK DATA = WORK.per_episode
	DESCENDING
	TIES=MEAN
	OUT=ranked_timings;
	BY seasonNum episodeNum;
	VAR timePerEpisode;
RANKS rank;

/* Create a gridded presentation of Episode graphs, single ep timings */
title;
filename htmlout temp;
ods graphics / width=500 height=300 imagefmt=svg noborder;
ods html5 file=htmlout options(svg_mode="inline")  gtitle style=daisy;
ods layout gridded columns=3 advance=bygroup;
proc sgplot data=ranked_timings noautolegend ;
  hbar name / response=timePerEpisode 
    categoryorder=respdesc 
    colorresponse=rank dataskin=crisp
    datalabel=name datalabelpos=right datalabelattrs=(size=10pt);
  by epLabel notsorted;
  format timePerEpisode time.;
  label epLabel="Ep";
  where rank<=10;
  xaxis display=(nolabel) max='00:45:00't min=0 minor grid ;
  yaxis display=none grid ;
run;
ods layout end;
ods html5 close;

/* Data prep to assemble cumulative timings */
/* First SORT by name, season, episode*/
proc sort data=per_episode
 out=for_cumulative;
 by name seasonNum episodeNum;
run;
 
/* Then use FIRST-dot-NAME processing      */
/* plus RETAIN to calc cumulative time per */
/* character name */
data cumulative;
 set for_cumulative;
 length cumulative 8;
 retain cumulative; 
 by name;
 if first.name then cumulative=timePerEpisode;
 else cumulative + timePerEpisode;
run;

/* Now rank the cumulative times PER character PER episode        */
/* So that we can report on the top 10 cumulative-time characters */
/* for each episode */
proc sort data=cumulative;
 by seasonNum episodeNum descending cumulative ;
run;

/* Assign ranks so we can filter to just top 10 per episode */
PROC RANK DATA = WORK.cumulative
	DESCENDING
	TIES=MEAN
	OUT=ranked_cumulative;
	BY seasonNum episodeNum;
	VAR cumulative;
RANKS rank;

/* Create a gridded presentation of Episode graphs CUMULATIVE timings */
title;
filename htmlout temp;
ods graphics / width=500 height=300 imagefmt=svg noborder;
ods html5 file=htmlout options(svg_mode="inline")  gtitle style=daisy;
ods layout gridded columns=3 advance=bygroup;
proc sgplot data=ranked_cumulative noautolegend ;
  hbar name / response=cumulative 
    categoryorder=respdesc 
    colorresponse=rank dataskin=crisp
    datalabel=name datalabelpos=right datalabelattrs=(size=10pt);
  by epLabel notsorted;
  format cumulative time.;
  label epLabel="Ep";
  where rank<=10;
  xaxis display=(nolabel)  grid ;
  yaxis display=none grid ;
run;
ods layout end;
ods html5 close;

/* Create a single animated SVG file for all episodes */
options printerpath=svg animate=start animduration=1 
  svgfadein=.25 svgfadeout=.25 svgfademode=overlap
  nodate nonumber; 

/* change this file path to something that works for you */
ODS PRINTER file="c:\temp\got_cumulative.svg" style=daisy;

/* For SAS University Edition
ODS PRINTER file="/folders/myfolders/got_cumulative.svg" style=daisy;
*/

proc sgplot data=ranked_cumulative noautolegend ;
  hbar name / response=cumulative 
    categoryorder=respdesc 
    colorresponse=rank dataskin=crisp
    datalabel=name datalabelpos=right datalabelattrs=(size=10pt);
  by epLabel notsorted;
  format cumulative time.;
  label epLabel="Ep";
  where rank<=10;
  xaxis label="Cumulative screen time (HH:MM:SS)" grid ;
  yaxis display=none grid ;
run;
options animation=stop;
ods printer close;
