/* BinaryHeart adapted from Rick Wicklin's blog */
/* ODS statements assume you're running in      */
/* SAS Enterprise Guide with HTML destination   */
/* Shared on "Social Media Love" day            */
/* https://www.instagram.com/p/BzVo5CuHtSn/     */
data BinaryHeart;
drop Nx Ny t r;
Nx = 21; Ny = 23;
call streaminit(2142015);
do x = -2.6 to 2.6 by 5.2/(Nx-1);
   do y = -4.4 to 1.5 by 6/(Ny-1);
      r = sqrt( x**2 + y**2 );
      t = atan2(y,x);
      Heart=(r < 2 - 2*sin(t) + sin(t)*sqrt(abs(cos(t))) / 
               (sin(t)+1.4)) 
            & (y > -3.5);
      B = rand("Bernoulli", 0.5);
      output;
   end;
end;
run;
ods html5(eghtml) gtitle style=raven; 
ods graphics / width=550px height=550px;
title height=2.5 "You're encoded in our hearts";
proc sgplot data=BinaryHeart noautolegend;
   styleattrs datacontrastcolors=(lightgray red); 
   scatter x=x y=y / group=Heart markerchar=B 
      markercharattrs=(size=14);
   xaxis display=none offsetmin=0 offsetmax=0.06;
   yaxis display=none;
run;