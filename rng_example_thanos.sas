/* ----------------------------------------------------
   Which RNG did Thanos use?                                   
   https://blogs.sas.com/content/sasdummy/rng-avengers-thanos/ 
   Authors: Chris Hemedinger, SAS
   Copyright 2018, SAS Institute Inc.
-------------------------------------------------------*/

/* Using STREAMINIT with the new RNG algorithm argument */
%let algorithm = PCG;
data characters;
  call streaminit("&algorithm.",2018);
  infile datalines dsd;
  retain x 0 y 1;
  length Name $ 60 spared 8 x 8 y 8;
  input Name;
  Spared = rand("Bernoulli", 0.5);
  x+1;
  if x > 10 then
    do; y+1; x = 1;end;
/* Character data from IMDB.com for Avengers: Infinity War */
datalines;
Tony Stark / Iron Man
Thor
Bruce Banner / Hulk
Steve Rogers / Captain America
Natasha Romanoff / Black Widow
James Rhodes / War Machine
Doctor Strange
Peter Parker / Spider-Man
T'Challa / Black Panther
Gamora
Nebula
Loki
Vision
Wanda Maximoff / Scarlet Witch
Sam Wilson / Falcon
Bucky Barnes / Winter Soldier
Heimdall
Okoye
Eitri
Wong
Mantis
Drax
Groot (voice)
Rocket (voice)
Pepper Potts
The Collector
Thanos
Peter Quill / Star-Lord
On-Set Rocket
Secretary of State Thaddeus Ross
Shuri
Cull Obsidian / On-Set Groot
Ebony Maw
Proxima Midnight
Corvus Glaive (as Michael Shaw)
Bus Driver
M'Baku
Ayo
Voice of Friday (voice)
On-Set Proxima Midnight
Ned
Cindy
Sally
Tiny
Young Gamora
Gamora's Mother
Red Skull (Stonekeeper)
Secretary Ross' Aide
Secretary Ross' Aide
Doctor Strange Double
Thanos Reader
Teenage Groot Reader
Street Pedestrian #1
Street Pedestrian #2
Scottish News (STV) Reporter
Dora Milaje (uncredited)
NYPD (uncredited)
Mourner (uncredited)
Merchant (uncredited)
Student (uncredited)
NYC Pedestrian (uncredited)
Taxi Cab Driver (uncredited)
Soldier (uncredited)
NYC Pedestrian (uncredited)
National Guard (uncredited)
Drill Sergeant (uncredited)
Construction Worker (uncredited)
NYPD (uncredited)
Coffee Shop Employee (uncredited)
Zen-Whoberi Elder (uncredited)
Patron in Vehicle (uncredited)
Nick Fury (uncredited)
Jabari Warrior (uncredited)
Citizen (uncredited)
Asgardian (uncredited)
NYC Pedestrian (uncredited)
NYC Pedestrian (uncredited)
Asgardian (uncredited)
NYC Pedestrian (uncredited)
Medical Assistant (uncredited)
Business Worker (uncredited)
Wounded Business Man (uncredited)
Student (uncredited)
NYC Pedestrian (uncredited)
Dora Milaje (uncredited)
Jack Rollins (uncredited)
Boy on Bus (uncredited)
Construction worker (uncredited)
Pedestrian (uncredited)
NYC Pedestrian / Phil (uncredited)
NYC Pedestrian (uncredited)
Asgardian (uncredited)
Maria Hill (uncredited)
NYC Pedestrian (uncredited)
NYC Pedestrian (uncredited)
New York Pedestrian (uncredited)
New York Pedestrian (uncredited)
NYC Maintenance (uncredited)
Rando 1
Rando 2
;
run;

ods noproctitle;
/* "Comic" Sans -- get it???? */
title font="Comic Sans MS" 
  "Distribution of Oblivion (&algorithm. Algorithm)";
ods graphics on / height=300 width=300;
proc freq data=work.characters;
  table spared / plots=freqplot;
run;

/* Using an attribute map for data-driven symbols */
data thanosmap;
  input id $ value $ markercolor $ markersymbol $;
  datalines;
status 0 black frowny
status 1 red heart
;
run;

title;
ods graphics / height=400 width=400 imagemap=on;
proc sgplot data=Characters noautolegend dattrmap=thanosmap;
  styleattrs wallcolor=white;
  scatter x=x y=y / markerattrs=(size=40) 
    group=spared tip=(Name Spared) attrid=status;
  symbolchar name=heart char='2665'x;
  symbolchar name=frowny char='2639'x;
  xaxis integer display=(novalues) label="Did Thanos Kill You? Frowny=Dead" 
    labelattrs=(family="Comic Sans MS" size=14pt);
  
  yaxis integer display=none;
run;

/* Conditional colors and strikethrough to indicate survival */
title "Details of who was 'snapped' and who was spared";
proc report data=Characters nowd;
  column Name spared;
  define spared / 'Spared' display;
  compute Spared;
    if spared=1 then
      call define(_row_,"style",
        "style={color=green}");
    if spared=0 then
      call define(_row_,"style",
        "style={color=red textdecoration=line_through}");
  endcomp;
run;
title;