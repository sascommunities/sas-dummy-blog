/* Copyright SAS Institute Inc. */

filename rssmap temp;
data _null_;
infile datalines;
file rssmap;
input;
put _infile_;
datalines;
<?xml version="1.0" encoding="windows-1252"?>
<SXLEMAP name="RSSMAP" version="2.1">
    <NAMESPACES count="0"/>
    <!-- ############################################################ -->
    <TABLE name="item">
        <TABLE-PATH syntax="XPath">/rss/channel/item</TABLE-PATH>
        <COLUMN name="title">
            <PATH syntax="XPath">/rss/channel/item/title</PATH>
            <TYPE>character</TYPE>
            <DATATYPE>string</DATATYPE>
            <LENGTH>250</LENGTH>
        </COLUMN>
        <COLUMN name="link">
            <PATH syntax="XPath">/rss/channel/item/link</PATH>
            <TYPE>character</TYPE>
            <DATATYPE>string</DATATYPE>
            <LENGTH>200</LENGTH>
        </COLUMN>
        <COLUMN name="pubDate">
            <PATH syntax="XPath">/rss/channel/item/pubDate</PATH>
            <TYPE>character</TYPE>
            <DATATYPE>string</DATATYPE>
            <LENGTH>40</LENGTH>
        </COLUMN>
    </TABLE>
</SXLEMAP>
;
run;

/* WordPress feeds return data in pages, 25 entries at a time        */
/* So using a short macro to loop through past 5 pages, or 125 items */
%macro getItems;
  %do i = 1 %to 5;
  filename feed temp;
  proc http
   method="get"
   url="https://www.starwars.com/news/feed?paged=&i."
   out=feed;
  run;
 
  libname result XMLv2 xmlfileref=feed xmlmap=rssmap;
 
  data posts_&i.;
   set result.item;
  run;
  %end;
%mend;
 
%getItems;
 
/* Assemble all pages of entries                       */
/* Cast the date field into a proper SAS date          */
/* Have to strip out the default day name abbreviation */
/* "Wed, 10 Apr 2019 17:36:27 +0000" -> 10APR2019      */
data allPosts ;
 set posts_:;
 length sasPubdate 8;
 sasPubdate = input( substr(pubDate,4),anydtdtm.);
 format sasPubdate dtdate9.;
 drop pubDate;
run;