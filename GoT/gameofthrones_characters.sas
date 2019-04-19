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
          t2.ordinal_scenes as scene_id, 
          input(t2.sceneStart,time.) as time_start format=time., 
          input(t2.sceneEnd,time.) as time_end format=time., 
          (calculated time_end) - (calculated time_start) as duration format=time.,
          t3.name
      FROM EPISODE.EPISODES t1, 
           EPISODE.EPISODES_SCENES t2, 
           EPISODE.SCENES_CHARACTERS t3
      WHERE (t1.ordinal_episodes = t2.ordinal_episodes AND 
             t2.ordinal_scenes = t3.ordinal_scenes);
QUIT;

/* Create a table of characters and TOTAL screen time */
proc sql;
  create table characters as 
    select name,
      sum(duration) as total_screen_time format=time.
    from character_scenes
      group by name
        order by total_screen_time desc;

  /* and a table of scenes */
  create table scenes as
    select distinct t1.seasonNum, t1.episodeNum, t1.scene_id, 
      t1.time_start, t1.time_end, t1.duration format=time.,
      t2.location, t2.subLocation
    from character_scenes t1 left join episode.episodes_scenes t2 
      on (t1.scene_id = t2.ordinal_scenes);
quit;

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
filename per_ep temp;
ods graphics / width=500 height=300 imagefmt=svg noborder;
ods html5 file=per_ep options(svg_mode="inline")  gtitle style=daisy;
ods layout gridded columns=3 advance=bygroup;
proc sgplot data=ranked_timings noautolegend ;
  hbar name / response=timePerEpisode 
    categoryorder=respdesc 
    colorresponse=rank dataskin=crisp datalabelpos=right
    datalabel=name datalabelattrs=(size=10pt)
    seglabel seglabelattrs=(weight=bold size=10pt color=white) ;    
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

proc sql;
  create table all_times
  as select t1.*, t2.total_screen_time
  from ranked_cumulative t1 left join characters t2 on (t1.name=t2.name)
  order by epLabel;
quit;

title;
filename all_ep temp;

ods html5 file=all_ep options(svg_mode="inline")  gtitle style=daisy;

/* Create a summary of scene locations and time spent */
ods graphics / reset width=800 height=600 imagefmt=svg noborder;
proc sgplot data=work.scenes;
 hbar location / response=duration 
   categoryorder=respdesc seglabel seglabelattrs=(color=white weight=bold);
 yaxis display=(nolabel);
 xaxis label="Scene time (HH:MM:SS)" grid values=(0 to '20:00:00't by '05:00:00't) ;
run;

/* Break it down for just the Crownlands */
ods graphics / width=500 height=300 imagefmt=svg noborder;
proc sgplot data=work.scenes;
 hbar subLocation / response=duration 
   categoryorder=respdesc seglabel seglabelattrs=(color=white weight=bold);
 yaxis display=(nolabel);
 xaxis label="Crownlands Scene time (HH:MM:SS)" grid values=(0 to '20:00:00't by '05:00:00't) ;
 where location="The Crownlands";
run;

/* Create a gridded presentation of Episode graphs CUMULATIVE timings */
ods graphics / width=500 height=300 imagefmt=svg noborder;
ods layout gridded columns=3 advance=bygroup;
proc sgplot data=all_times noautolegend ;
  hbar name / response=cumulative 
    categoryorder=respdesc  
    colorresponse=total_screen_time dataskin=crisp
    datalabel=name datalabelpos=right datalabelattrs=(size=10pt)
    seglabel seglabelattrs=(weight=bold size=10pt color=white) ;
   ;
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

proc sgplot data=all_times noautolegend ;
  hbar name / response=cumulative 
    categoryorder=respdesc 
    colorresponse=total_screen_time dataskin=crisp
    datalabel=name datalabelpos=right datalabelattrs=(size=10pt)
    seglabel seglabelattrs=(weight=bold size=10pt color=white) ;
   ;
  by epLabel notsorted;
  format cumulative time.;
  label epLabel="Ep";
  where rank<=10;
  xaxis label="Cumulative screen time (HH:MM:SS)" grid ;
  yaxis display=none grid ;
run;
options animation=stop;
ods printer close;
