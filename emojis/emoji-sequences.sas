/*
  Sample code for pulling emoji data into SAS
  Code by: Chris Hemedinger, SAS

  NOTE: These data require ENCODING=UTF8 in your SAS session!
  
  Pull emoji definitions from Unicode.org
  Each version of the emoji standard has a data file.
  This code pulls from the "latest" to get the most current set.
*/

filename raw temp;
proc http
  url="https://unicode.org/Public/emoji/latest/emoji-sequences.txt"
 out=raw;
run;

ods escapechar='~';
data emojis (drop=line);
length line $ 1000 codepoint_range $ 45 val_start 8 val_end 8 
       type $ 30 comments $ 65 saschar $ 20 htmlchar $ 25;
infile raw ;
input;
line = _infile_;

/* skip comments and blank lines */
/* data fields are separated by semicolons */
if substr(line,1,1)^='#' and line ^= ' ' then do;

 /* read the raw codepoint value - could be single, a range, or a combo of several */
 codepoint_range = scan(line,1,';');
 /* read the type field */
 type = compress(scan(line,2,';'));
 /* text description of this emoji */
 comments = scan(line,3,'#;');

 /* for those emojis that have a range of values */
 val_start = input(scan(codepoint_range,1,'. '), hex.);
 if find(codepoint_range,'..') > 0 then do;
  val_end = input(scan(codepoint_range,2,'.'), hex.);
 end;
 else val_end=val_start;

 if type = "Basic_Emoji" then do;
  saschar = cat('~{Unicode ',scan(codepoint_range,1,' .'),'}');
  htmlchar = cats('<span>&#x',scan(codepoint_range,1,' .'),';</span>');
 end;
 output;
end;
run;

/* Assuming HTML or HTML5 output destination */
/* print the first 50 emoji records */
proc print data=emojis (obs=50); run;


/*
  Instead of the Unicode.org data, let's pull data
  from a structured data file built for another
  project on GitHub -- the gemoji project

*/

filename rawj temp;
 proc http
  url="https://raw.githubusercontent.com/github/gemoji/master/db/emoji.json"
  out=rawj;
run;

libname emoji json fileref=rawj;

/* reformat the tags and aliases data for inclusion in a single data set */
data tags;
 length ordinal_root 8 tags $ 60;
 set emoji.tags;
 tags = catx(', ',of tags:);
 keep ordinal_root tags;
run;

data aliases;
 length ordinal_root 8 aliases $ 60;
 set emoji.aliases;
 aliases = catx(', ',of aliases:);
 keep ordinal_root aliases;
run;

/* Join together in one record per emoji */
proc sql;
 create table full_emoji as 
 select  t1.emoji as emoji_char, 
    unicodec(t1.emoji,'esc') as emoji_code, 
    t1.description, t1.category, t1.unicode_version, 
    case 
     when t1.skin_tones = 1 then  t1.skin_tones
	 else 0
	end as has_skin_tones,
    t2.tags, t3.aliases
  from emoji.root t1
  left join tags t2 on (t1.ordinal_root = t2.ordinal_root)
  left join aliases t3 on (t1.ordinal_root = t3.ordinal_root)
 ;
quit;

/* Assuming HTML or HTML5 output destination */
proc print data=full_emoji; run;


