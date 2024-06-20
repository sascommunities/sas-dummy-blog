/*-------------------------------------------------------------------
-------------------------------------------------------------------*/
options stimer fullstimer linesize=120;
options mprint symbolgen spool;

/*-------------------------------------------------------------------
   This macro tests each bit in a byte of the mantissa of a
   floating-point number.  At each bit position, if the bit is
   set, the macro accumulates the value that bit contributes
   to the mantissa.

   Set the value of "mask" so that the first division operation
   will produce the first mask value to actually use.
-------------------------------------------------------------------*/
%macro getbyte( varname, charpos, bitpos );
   %let mask   = 256;  /* 0100x */

/*-------------------------------------------------------------------
   Read the byte of the mantissa into a numeric variable so the
   masking can be done in the less-confusing "human-readable"
   order instead of the literal Intel little-endian order.
-------------------------------------------------------------------*/
      thisbyte_n = input( substr(&varname, &charpos, 1), pib1. );

/*-------------------------------------------------------------------
   Step through the bits from most-significant to least-significant.

   Note that the mask value will progress from 128 (0x80), to
   64 (0x40), to 32 (0x20), and so on.

   If the bit is set, accumulate the value of that bit position.
-------------------------------------------------------------------*/
   %do i = 0 %to 7 %by 1;
      %let thisbit = %eval( &bitpos + &i );
      %let mask    = %eval( &mask / 2 );
      if ( band(thisbyte_n, &mask) )  then  value + 2**(exp_use - &thisbit);
   %end;
%mend;

/*-------------------------------------------------------------------
   This macro takes a number and generates the five-number sequence
   from two below and two above the supplied number.
-------------------------------------------------------------------*/
%macro surround( value, extension, increment );
   series = &value;

   do x = (&value - &extension) to (&value + &extension) by &increment;
      %decode_fp_ieee( x );
      output;
   end;
%mend;

/*-------------------------------------------------------------------
   At each number in the sequence, this macro decodes the components
   of the IEEE floating-point representation of the value.
-------------------------------------------------------------------*/
%macro decode_fp_ieee( varname );

/*-------------------------------------------------------------------
   The RB8. format just copies the bytes *exactly* to a character
   variable.  This gives the program access to the raw floating-
   point number.
-------------------------------------------------------------------*/
      crb&varname = put(&varname, rb8.);

/*-------------------------------------------------------------------
   The sign and exponent are 12 of the 16 rightmost bits.

   Record the value of the sign bit as a character string that's
   ready to print.
-------------------------------------------------------------------*/
      signexp  = input( substr(crb&varname, 7, 2), pib2. );

      if ( band(signexp, 08000x) )  then sign = '1 (-)';
      else sign = '0 (+)';

/*-------------------------------------------------------------------
   Pull the 11-bit exponent out.  Use the band() function to mask
   out the 11 exponent bits, then use brshift() to shift them
   right so they form the 12 least-significant bits of an integer.
-------------------------------------------------------------------*/
      exponent = band(signexp, 07ff0x);
      exponent = brshift(exponent, 4);

/*-------------------------------------------------------------------
   An IEEE floating-point exponent is "biased" so that its range
   of zero to 2047 can be used as -1023 to 1024.
   (see en.wikipedia.org/wiki/IEEE_754-1985)
-------------------------------------------------------------------*/
      exp_biased = exponent;
      exp_use = exponent - 1023;

/*-------------------------------------------------------------------
   Initialize the calculated value to 2 raised to the de-biased
   value of the exponent.
-------------------------------------------------------------------*/
      value = 2**exp_use;

/*-------------------------------------------------------------------
   Walk down the four most-significant bits of the exponent.  If
   a bit is set, accumulate the value of that bit position.
-------------------------------------------------------------------*/
      thisbyte_n = input( substr(crb&varname, 7, 1), pib1. );

      if ( band(thisbyte_n, 08x) )  then  value + 2**(exp_use - 1);
      if ( band(thisbyte_n, 04x) )  then  value + 2**(exp_use - 2);
      if ( band(thisbyte_n, 02x) )  then  value + 2**(exp_use - 3);
      if ( band(thisbyte_n, 01x) )  then  value + 2**(exp_use - 4);

/*-------------------------------------------------------------------
   Use the macro to walk down the rest of the mantissa.
-------------------------------------------------------------------*/
      %getbyte( crb&varname, 6,  5 );
      %getbyte( crb&varname, 5, 13 );
      %getbyte( crb&varname, 4, 21 );
      %getbyte( crb&varname, 3, 29 );
      %getbyte( crb&varname, 2, 37 );
      %getbyte( crb&varname, 1, 45 );
%mend;

/*-------------------------------------------------------------------
   Un-comment these two steps to explore fractional values.
-------------------------------------------------------------------*/

/*-------------------------------------------------------------------
data;
   drop   thisbyte_n;
   length crbx $ 8
          sign $ 5;
   format crbx $hex16.
          x value 15.12
          exp_biased exp_use 5.
          signexp exponent hex4.;

   do x = 0.5, 0.25, 0.125, 0.0625, 0.03125, 0.015625, 0.0078125;
      %decode_fp_ieee( x );
      output;
   end;
run;

title "1: Software Calculation of Fractional IEEE Floating-Point Values, Intel Format";
proc print;
   var crbx x value signexp sign exponent exp_biased exp_use;
run;
-------------------------------------------------------------------*/

/*-------------------------------------------------------------------
   This DATA step uses the above macros to decode sample
   floating-point numbers.
-------------------------------------------------------------------*/
data;
   drop   thisbyte_n;
   length crbx $ 8
          sign $ 5;
   format crbx $hex16.
          x value comma10.
          exp_biased exp_use 5.
          signexp exponent hex4.;

   do x = 0.5, 0.25, 0.125, 0.0625, 0.03125, 0.015625, 0.0078125;
      %decode_fp_ieee( x );
   end;

   %surround(       0, 5, 1 );
   %surround(       8, 2, 1 );
   %surround(      16, 2, 1 );
   %surround(      32, 2, 1 );
   %surround(      64, 2, 1 );
   %surround(     128, 2, 1 );
   %surround(     256, 2, 1 );
   %surround(     512, 1, 1 );
   %surround(    1024, 1, 1 );
   %surround(    2048, 1, 1 );
   %surround(    4096, 1, 1 );
   %surround(    8192, 1, 1 );
   %surround(   16384, 1, 1 );
   %surround(   32768, 1, 1 );
   %surround(   65536, 1, 1 );
   %surround(  131072, 1, 1 );
   %surround(  262144, 1, 1 );
   %surround(  524288, 1, 1 );
   %surround( 1048576, 1, 1 );
   %surround( 2097152, 1, 1 );
   %surround( 4194304, 1, 1 );
   %surround( 8388608, 1, 1 );
run;

title "1: Software Calculation of IEEE Floating-Point Values, Intel Format";
proc print;
   by notsorted series;
   id series;
   var crbx x value signexp sign exponent exp_biased exp_use;
run;

/*-------------------------------------------------------------------
   This DATA step creates the "root" data file that will be used
   by most of the steps below. It captures the two original
   values and sets up formats so the variables can be read in
   both hexadecimal (crb...) and decimal.
-------------------------------------------------------------------*/
data a;
   length crbx crby crbd $ 8
          sign $ 5;
   format x y 22.7
          d 11.8
          exp_biased exp_use 5.
          signexp exponent hex4.
          crbx crby crbd $hex16.;
   drop   thisbyte_n;

/*-------------------------------------------------------------------
   Set x to the original integer value, and y to the original
   value that mysteriously compared unequal to x.  Calculate
   the difference between y and x.
-------------------------------------------------------------------*/
   x = 122000015596951.0;
   y = 122000015596951.015625;
   d = y - x;

/*-------------------------------------------------------------------
   Save the IEEE floating-point representations as character
   strings that can be displayed in hexadecimal to show the
   actual binary floating-point representations.
-------------------------------------------------------------------*/
   crbx = put(x, rb8.);
   crby = put(y, rb8.);
   crbd = put(d, rb8.);

/*-------------------------------------------------------------------
   Take the difference value apart to show how normalization
   moves the mantissa and re-calculates the exponent.
-------------------------------------------------------------------*/
   %decode_fp_ieee( d );
run;

title "2: The Two Original Values and Their Difference";
proc print;
   var x crbx  y crby  d crbd signexp exponent exp_biased exp_use;
run;

/*-------------------------------------------------------------------
   Examine values around the original value.
-------------------------------------------------------------------*/
data;
   length c $ 1;
   format c $hex2.
          lsb binary8.;

   set a;

/*-------------------------------------------------------------------
   Go through a loop that sets the least-significant byte of the
   floating-point value to a series of values that increment by
   one bit.
-------------------------------------------------------------------*/
   do lsb = (0c0x - 15) to (0c0x + 15) by 1;

/*-------------------------------------------------------------------
   Store the loop variable as a one-byte integer, then store that
   in the least-significant byte of the floating-point value.
-------------------------------------------------------------------*/
      c = put( lsb, pib1. );
      substr( crby, 1, 1 ) = c;

/*-------------------------------------------------------------------
   Copy the floating-point bit string into a numeric variable.

   Calculate the difference between this floating-point value and
   Kugendrn's customer's original value.

   Calculate the difference between this observation's difference
   and the previous observation's difference.
-------------------------------------------------------------------*/
      y = input(crby, rb8.);
      d = y - x;
      lagd = d - lag(d);
      output;
   end;
run;

title "3: Values Immediately Adjacent to the Customer's Integer";
proc print;
   var x crbx  y crby  lsb  d lagd;
run;

/*-------------------------------------------------------------------
   These steps are commented-out because discussing them made the
   mail message too long. But feel free to uncomment them and
   explore this area yourself.
-------------------------------------------------------------------*/

/*-------------------------------------------------------------------
   Create an interleaved series of values from the original
   integer value to a little more than one greater than itself.

   The interleaving will be of values produced by base-2
   arithmetic and base-10 arithmetic.

   Note that this loop has to set the two least-significant bytes
   of the floating-point value.
-------------------------------------------------------------------*/
* data c1;
*    drop c;
*    length c $ 2;
*    format c $hex4.
*           i_2 hex4.;
*    retain base ' 2';

/*-------------------------------------------------------------------
   Read the original values, then loop from the original integer
   to a little past one greater than it.  This is to get past
   the "boundary effects" at the change of displayed values.
-------------------------------------------------------------------*/
*    set a;
* 
*    do i_2 = 65c0x to 6602x by 1;

/*-------------------------------------------------------------------
   Save the loop value as an integer in the least-significant
   two bytes of the floating-point value.  Then load the
   modified floating-point value into a numeric variable.
-------------------------------------------------------------------*/
*       c = put( i_2, pib2. );
*       substr( crby, 1, 2 ) = c;
*       y = input(crby, rb8.);

/*-------------------------------------------------------------------
   Compare the just-produced floating-point value to the original
   integer value, and write the observation.
-------------------------------------------------------------------*/
*       d = y - x;
*       output;
*    end;
* run;

/*-------------------------------------------------------------------
   Now produce a similar series of observations, but incremented
   by a base-10 value.
-------------------------------------------------------------------*/
* data c2;
*    drop   cx;
*    length cx $ 8;
*    retain base '10';
*    format i_10   3.1;

/*-------------------------------------------------------------------
   Get the original values, then loop to the next-higher-by-one
   value, using an increment that's one power of 10 lower than
   the range we're covering (so we'll get 10 steps).
-------------------------------------------------------------------*/
*    set a;
* 
*    do y = x to (x + 1) by 0.1;

/*-------------------------------------------------------------------
   Save the floating-point value so it can be displayed.

   Calculate the difference and save it for display.

   The "i_10"variable is for display; it shows the index by which
   "y" was incremented on this iteration of the loop.
-------------------------------------------------------------------*/
*       crby = put(y, rb8.);
*       d = y - x;
*       output;
*       i_10 + 0.1;
*    end;

/*-------------------------------------------------------------------
   Just show this in the log for reference.
-------------------------------------------------------------------*/
*    cx = put( 0.1, rb8. );
*    put cx= $hex16.;
* run;

/*-------------------------------------------------------------------
   Combine the two SAS data files generated above.
-------------------------------------------------------------------*/
* data;
*    drop i_2;
*    length c_2 $ 4;
* 
*    set c1(in=in_1)
*        c2(in=in_2);

/*-------------------------------------------------------------------
   For readability in the output, blank whichever type of
   increment did *not* contribute.
-------------------------------------------------------------------*/
*    if ( in_1 )  then  c_2 = put(i_2, hex4.);
*    else               c_2 = ' ';
* 
*    if ( not in_2 )  then  i_10 = .;
* run;

/*-------------------------------------------------------------------
   Sort the combined file so the values incremented using
   base-2 and base-10 interleave to show how the machine
   did the math.
-------------------------------------------------------------------*/
* proc sort;
*    by d;
* run;
* 
* title "0: Interleaving Values From Base-2 and Base-10 Addition";
* proc print;
*    var base x crbx  y crby c_2 i_10  d;
* run;

/*-------------------------------------------------------------------
   Create a file that covers a wider range and shows the number
   of base-2 values that are between each base-10 value.
-------------------------------------------------------------------*/
data;
   drop   x crbx d crbd thisbyte_n;
   format ls_12bits_hex hex3.
          ls_12bits_bin binary12.
          value 8.3
          d_10 3.;
   label  value = 'Lowest 12 Bits Decoded';

/*-------------------------------------------------------------------
   Get the original values and initiate a loop from five below
   to five above the original value.  On each iteration,
   capture the floating-point bit pattern into a character
   variable where it can be decoded and displayed.
-------------------------------------------------------------------*/
   set a;

   do y = (x - 5) to (x + 5) by 1;
      crby = put(y, rb8.);

/*-------------------------------------------------------------------
   All of the action is in the least-significant 12 bits of the
   mantissa.  To get 12 bits, we have to read 2 bytes (16 bits).

   Because Intel is byte-swapped, we have to read the individual
   bytes in significance, not storage, order.
-------------------------------------------------------------------*/
      ls_12bits_hex = input(substr(crby, 2, 1), pib1.);
      ls_12bits_hex = (ls_12bits_hex * 256) + input(substr(crby, 1, 1), pib1.);
      ls_12bits_bin = ls_12bits_hex;

/*-------------------------------------------------------------------
   Calculate the difference between this difference and the
   previous one.  Copy it to a variable that will be displayed
   using another format.
-------------------------------------------------------------------*/
      d_10 = ls_12bits_hex - lag(ls_12bits_hex);

/*-------------------------------------------------------------------
   Extract the sign and exponent.  De-bias the exponent.
-------------------------------------------------------------------*/
      signexp  = input( substr(crby, 7, 2), pib2. );

      exponent = band(signexp, 07ff0x);
      exponent = brshift(exponent, 4);
      exp_biased = exponent;
      exp_use  = exponent - 1023;

/*-------------------------------------------------------------------
   Decode only the least-significant 12 bits of the mantissa.
   This covers all of the variation in this range of values.
-------------------------------------------------------------------*/
      value = 0;

      thisbyte_n = input( substr(crby, 2, 1), pib1. );

      if ( band(thisbyte_n, 08x) )  then  value + 2**(exp_use - 41);
      if ( band(thisbyte_n, 04x) )  then  value + 2**(exp_use - 42);
      if ( band(thisbyte_n, 02x) )  then  value + 2**(exp_use - 43);
      if ( band(thisbyte_n, 01x) )  then  value + 2**(exp_use - 44);

      %getbyte( crby, 1, 45 );

      output;
   end;
run;

title "4: Incrementing the Least-Significant of 15 Significant Decimal Digits";
proc print label;
   var y crby ls_12bits_hex ls_12bits_bin d_10 exp_use value;
run;

/*-------------------------------------------------------------------
   We showed what happens when these values participate in a
   subtraction operation above.  Here, show what happens when
   the operations are divide, multiply, and add.  And show the
   results of the fuzz() and round() functions.
-------------------------------------------------------------------*/
data;
   length crbw operation $ 8;
   format w    22.7
          d    E12.7
          crbw $hex16.;
   set a;

   operation = 'Divide';
   w = y / x;
   crbw = put(w, rb8.);
   d = w - 1;
   output;

   operation = 'Multiply';
   w = y * x;
   crbw = put(w, rb8.);
   d = w - (x * x);
   output;

   operation = 'Add';
   w = y + x;
   crbw = put(w, rb8.);
   d = w - (x + x);
   output;

   operation = 'Fuzz';
   w = fuzz(y);
   crbw = put(w, rb8.);
   d = w - fuzz(x);
   output;

   operation = 'Round';
   w = round(y);
   crbw = put(w, rb8.);
   d = w - round(x);
   output;
run;

title "5: Results of Miscellaneous Math Operations";
proc print;
   id operation;
   var x crbx  y crby  w crbw  d;
run;
