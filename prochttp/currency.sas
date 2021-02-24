filename data URL "https://www.federalreserve.gov/paymentsystems/files/coin_currcircvolume.txt";

filename data "c:\temp\curr.txt";
proc http method="GET"
 url =
  "https://www.federalreserve.gov/paymentsystems/files/coin_currcircvolume.txt"
 out=data;
run;

data work.fromfed;
    length
        year               8
        notes_1            8
        notes_2            8
        notes_5            8
        notes_10           8
        notes_20           8
        notes_50           8
        notes_100          8
        notes_500plus      8 ;
    infile data
        firstobs=4
        encoding="utf-8"
        truncover ;
    input
        @1     year            
        @13    notes_1         
        @22    notes_2         
        @30    notes_5         
        @38    notes_10        
        @46    notes_20        
        @54    notes_50        
        @61    notes_100       
        @69    notes_500plus   ;

	/* drop empty rows */
	if year ^= .;
run;


/* Add and ID value to prepare for transpose */
proc sql ;
  create table circdata as select t1.*, 
  'BillCountsInBillions' as ID from fromfed t1
  order by year;
run;

/* Stack this data into column-wise format */
proc transpose data = work.circdata
	out=work.stackedcash
	name=denomination
	label=countsinbillions
	;
	by year;
    id id;
	var notes_1 notes_2 notes_5 notes_10 notes_20 notes_50 notes_100 notes_500plus;
run;

/* Calculate the dollar values based on counts */
data cashvalues;
  set stackedcash;
  length multiplier 8 value 8;
  select (denomination);
    when ('notes_1') multiplier=1;
	when ('notes_2') multiplier=2;
	when ('notes_5') multiplier=5;
	when ('notes_10') multiplier=10;
	when ('notes_20') multiplier=20;
	when ('notes_50') multiplier=50;
	when ('notes_100') multiplier=100;
	when ('notes_500plus') multiplier=500;
	otherwise multiplier=0;
   end;
   value = BillCountsInBillions * multiplier;
run;

/* Use a format to make a friendlier legend in our plots */
proc format lib=work;
value $notes
	"notes_1" = "$1"
	"notes_2" = "$2"
	"notes_5" = "$5"
	"notes_10" = "$10"
	"notes_20" = "$20"
	"notes_50" = "$50"
	"notes_100" = "$100"
	"notes_500plus" = "$500+"
;
run;

proc freq data=cashvalues
	order=data
	noprint
;
	tables denomination / nocum out=work.cashpercents scores=table;
	weight value;
	by year;
run;

proc freq data=cashvalues
	order=data
	noprint
;
	tables denomination / nocum out=work.billpercents scores=table;
	weight BillCountsInBillions;
	by year;
run;

/* directives for EG HTML output */
 ods html5 (id=eghtml) gtitle gfootnote; 
ods graphics / width=700px height=400px;

/* Plot the results */
footnote height=1 'Source: https://www.federalreserve.gov/paymentsystems/coin_currcircvolume.htm';
title "US Currency in Circulation: % Value of Denominations";
proc sgplot data=cashpercents ;
 label denomination = 'Denomination';
 format denomination $notes.;
 vbar year / response=percent group=denomination grouporder=data;
 yaxis label="% Value in Billions" ; 
 xaxis display=(nolabel);
 keylegend / position=right across=1 noborder valueattrs=(size=12pt) title="" ;
run;

title "US Currency in Circulation: % Bill Counts";
proc sgplot data=billpercents ;
 label denomination = 'Denomination';
 format denomination $notes.;
 vbar year / response=percent group=denomination grouporder=data;
 yaxis label="% Bills in Billions" ; 
 xaxis display=(nolabel);
 keylegend / position=right across=1 noborder valueattrs=(size=12pt) title="";
run;