/* Reliable way to check whether a macro value is empty/blank */
%macro isBlank(param);
  %sysevalf(%superq(param)=,boolean)
%mend;

/* We need this function for large file uploads, to telegraph */
/* the file size in the API.                                   */
/* Get the file size of a local file in bytes.                */
%macro getFileSize(localFile=);
  %local rc fid fidc;
  %local File_Size;
  %let rc=%sysfunc(filename(_lfile,&localFile));
  %let fid=%sysfunc(fopen(&_lfile));
  %let File_Size=%sysfunc(finfo(&fid,File Size (bytes)));
  %let fidc=%sysfunc(fclose(&fid));
  %let rc=%sysfunc(filename(_lfile));
  %sysevalf(&File_Size.)
%mend;

%macro splitFile(sourceFile=,
 maxSize=327680,
 metadataOut=,
 /* optional, will default to WORK */
 chunkLoc=);

  %local filesize maxSize numChunks buffsize ;
  %let buffsize = %sysfunc(min(&maxSize,4096));
  %let filesize = %getFileSize(localFile=&sourceFile.);
  %let numChunks = %sysfunc(ceil(%sysevalf( &filesize / &maxSize. )));
  %put NOTE: Splitting &sourceFile. into &numChunks parts;

  %if %isBlank(&chunkLoc.) %then %do;
    %let chunkLoc = %sysfunc(getoption(WORK));
  %end;

  /* This DATA step will do the chunking.                                 */
  /* It's going to read the original file in segments sized to the buffer */
  /* It's going to write that content to new files up to the max size     */
  /* of a "chunk", then it will move on to a new file in the sequence     */
  /* All resulting files should be the size we specified for chunks       */
  /* except for the last one, which will be a remnant                     */
  /* Along the way it will build a data set with the metadata for these   */
  /* chunked files, including the file location and byte range info       */
  /* that will be useful for APIs that need that later on                 */
  data &metadataOut.(keep=original originalsize chunkpath chunksize byterange);
    length 
      filein 8 fileid 8 chunkno 8 currsize 8 buffIn 8 rec $ &buffsize fmtLength 8 outfmt $ 12
      bytescumulative 8
      /* These are the fields we'll store in output data set */
      original $ 250 originalsize 8 chunkpath $ 500 chunksize 8 byterange $ 50;
    original = "&sourceFile";
    originalsize = &filesize.;
    rc = filename('in',"&sourceFile.");
    filein = fopen('in','S',&buffsize.,'B');
    bytescumulative = 0;
    do chunkno = 1 to &numChunks.;
      currsize = 0;
      chunkpath = catt("&chunkLoc./chunk_",put(chunkno,z4.),".dat");
      rc = filename('out',chunkpath);
      fileid = fopen('out','O',&buffsize.,'B');
      do while ( fread(filein)=0 ) ;
        call missing(outfmt, rec);
        rc = fget(filein,rec, &buffsize.);
        buffIn = fcol(filein);
        if (buffIn - &buffsize) = 1 then do;
          currsize + &buffsize;
          fmtLength = &buffsize.;
        end;
        else do;
          currsize + (buffIn-1);
          fmtLength = (buffIn-1);
        end;
        /* write only the bytes we read, no padding */
        outfmt = cats("$char", fmtLength, ".");
        rcPut = fput(fileid, putc(rec, outfmt));
        rcWrite = fwrite(fileid);      
        if (currsize >= &maxSize.) then leave;
      end;
      chunksize = currsize;
      bytescumulative + chunksize;
      byterange = cat("bytes ",bytescumulative-chunksize,"-",bytescumulative-1,"/",originalsize);
      output;
      rc = fclose(fileid);
    end;
    rc = fclose(filein);
  run;
%mend;