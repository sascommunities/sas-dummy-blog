/* Copyright SAS Institute Inc. */

/* Read JSON feed into a local file. */
/* Use Blogspot parameters to get 100 posts at a time */
filename resp temp;
proc http
 url='https://googlemapsmania.blogspot.com/feeds/posts/default?alt=json&max-results=100'
 method="get"
 out=resp;
run;
 
libname rss json fileref=resp;

/* Join the relevant feed entry items to make a single table */
/* with post titles and URLs */
proc sql;
   create table work.blogspot as 
   select t2._t as rss_title,
          t1.href as rss_href          
      from rss.entry_link t1
           inner join rss.entry_title t2 on (t1.ordinal_entry = t2.ordinal_entry)
      where t1.type = 'text/html' and t1.rel = 'alternate';
quit;
 
libname rss clear;