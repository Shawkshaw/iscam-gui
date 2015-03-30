#**********************************************************************************
# iscam-gui-tables.r
# This file contains the code for creating tables for assessments with iscam-gui.
#
# Author            : Chris Grandin
# Development Date  : March 2015 - Present
# Current version   : 1.0
#**********************************************************************************

makeTable <- function(scenario   = 1,         # Scenario number
                      tableNum   = 1,         # table code number, see below
                      savetable  = .SAVETAB,  # TRUE/FALSE for table output
                      fileText   = "Default", # Name of the file if savetable==TRUE
                      ci         = NULL,      # confidence interval in % (0-100)
                      multiple   = FALSE,     # TRUE/FALSE to add sensitivity cases to table
                      sensGroup  = 1,         # Sensitivity group to use if multiple==TRUE
                      burnthin   = list(0,1), # List of two elements, burnin and thinning for mcmc tables
                      digits     = 3,         # Number of decimal places to report in tables
                      silent     = .SILENT){

  # If multiple==TRUE, whatever is in the sensitivity list (sens) for the currently
  #  chosen sensitivity number in the GUI will be used in the table..
  # If multiple==FALSE, whatever the currently chosen scenario number is in the GUI
  #  will be tabled by itself.
  # If plotMCMC==TRUE, follow the same rules, but for the MCMC data. Use the
  #  confidence interval for an envelope plot in this case.
  # Assumes that 'op' list exists and has been populated correctly.
  # Assumes that 'sens' list exists and has been populated correctly.

  # tableNum must be one of (all tables include MPD, MCMC lower bound, median, and upper bound):
  # 1 Parameter estimates
  # 2 Reference points
  # 3 Spawning biomass
  # 4 Recruitment
  # 5 Fishing mortality (F)
  # 6 Fishing mortality (U)
  # 7 Decision table
  # 8 Indices table (Input indices)

  currFuncName <- getCurrFunc()

  scenarioName <- op[[scenario]]$names$scenario
  if(multiple){
    # Extract models in the current sensitivity group
    if(is.null(sens[[sensGroup]])){
      cat0(.PROJECT_NAME,"->",currFuncName,"The sensitivity group you selected has no members.")
      return(NULL)
    }
    models <- sens[[sensGroup]]
  }else{
    models <- scenario # For the non-multiple and retro cases
  }


  # Remove models which do not have MCMC outputs, or MPD outputs
  validModelsMPD <- getValidModelsList(models, type = "mpd")
  validModelsMCMC <- getValidModelsList(models, type = "mcmc")
  if(length(validModelsMPD) != length(validModelsMCMC)){
    cat0(.PROJECT_NAME,"->",currFuncName,"The number of MPDs and MCMCs are not equal. Reload and make sure all MCMCs are being loaded correctly.")
    return(NULL)
  }

  if(is.null(ci)){
    cat0(.PROJECT_NAME,"->",currFuncName,"You must supply a confidence interval (e.g. ci=95).")
    return(NULL)
  }

  tableDir <- op[[scenario]]$names$tableDir
  inputs <- op[[scenario]]$inputs
  outMPD <- validModelsMPD[[1]]
  outMCMC <- validModelsMCMC[[1]]
  namesMCMC  <- validModelsMCMC[[3]]

  if(multiple){
    filenameRaw  <- paste0("SensitivityGroup_",sensGroup,"_",fileText,".csv")
    filename     <- file.path(.SENS_FIGURES_DIR_NAME,filenameRaw)
  }else{
    filenameRaw  <- paste0(scenarioName,"_",fileText,".csv")
    filename     <- file.path(tableDir, filenameRaw)
  }
  if(tableNum == 1){
    paramEstTable(outMPD, outMCMC, names, ci=ci, burnthin=burnthin, savetable=savetable, filename=filename, digits=digits)
  }
  if(tableNum == 2){
    refPointsTable(outMPD, outMCMC, names, ci=ci, burnthin=burnthin, savetable=savetable, filename=filename, digits=digits)
  }
  if(tableNum == 3){
    # send biomass output for mcmc and mpd
    valueTable(outMPD[[1]]$mpd$sbt, outMCMC[[1]]$mcmc$sbt[[1]], names, ci=ci, burnthin=burnthin, savetable=savetable, filename=filename, digits=digits)
  }
  if(tableNum == 4){
    # send recruitment output for mcmc and mpd
    valueTable(outMPD[[1]]$mpd$rt, outMCMC[[1]]$mcmc$rt[[1]], names, ci=ci, burnthin=burnthin, savetable=savetable, filename=filename, digits=digits)
  }
  if(tableNum == 5){
    # send F output for mcmc and mpd - NOTE only for gear 1
    # Special because the years are embedded in text, and they must be extracted first..
    ft <- outMCMC[[1]]$mcmc$ft[[1]][[1]]
    fnames <- names(ft)
    yrs <- gsub(".*_([[:digit:]]+)","\\1",fnames)
    names(ft) <- yrs
    valueTable(outMPD[[1]]$mpd$ft[1,], ft, names, ci=ci, burnthin=burnthin, savetable=savetable, filename=filename, digits=digits)
  }
  if(tableNum == 6){
    # send U output for mcmc and mpd - NOTE only for gear 1
    # Special because the years are embedded in text, and they must be extracted first..
    ut <- outMCMC[[1]]$mcmc$ut[[1]][[1]]
    unames <- names(ut)
    yrs <- gsub(".*_([[:digit:]]+)","\\1",unames)
    names(ut) <- yrs
    valueTable(outMPD[[1]]$mpd$ut[1,], ut, names, ci=ci, burnthin=burnthin, savetable=savetable, filename=filename, digits=digits)
  }
  if(tableNum == 7){
    # Decision table based on projection runs
    decisionTable(outMCMC, names, ci=ci, burnthin=burnthin, savetable=savetable, filename=filename, digits=digits)
  }
  if(tableNum == 8){
    # Indices table for current scenario only
    gearnames <- op[[scenario]]$inputs$data$gearNames
    indicesTable(inputs, gearnames=gearnames, savetable=savetable, filename=filename, digits=digits)
  }
}

indicesTable <- function(inputs    = NULL,
                         gearnames = NULL,
                         savetable = FALSE,
                         filename  = "default",
                         digits    = 1,            # Number of digits to round the index to
                         verbose   = FALSE){
  currFuncName <- getCurrFunc()
  if(is.null(inputs)){
    cat0(.PROJECT_NAME,"->",currFuncName,"You must supply an inputs vector.")
    return(NULL)
  }
  indices <- inputs$data$indices
  if(is.null(indices)){
    cat0(.PROJECT_NAME,"->",currFuncName,"Your inputs list must contain data$indices.")
    return(NULL)
  }

  oldPar <- par(no.readonly=TRUE)
  on.exit(par(oldPar))

  tabledf <- NULL
  # bind the index list into a single data frame, since the list elements are all the same shape
  indicesdf <- as.data.frame(do.call(rbind, indices))
  # Strip index names from the gearnames vector by using gear number from the indices table
  gearnums <- unique(indicesdf$gear)
  indnames <- gearnames[gearnums]
  for(gear in 1:length(gearnums)){
    header <- c(indnames[gear], "Index", "CV")
    index <- indicesdf[indicesdf$gear == gearnums[gear],]
    index <- as.matrix(cbind(index$iyr, index$it, index$wt))
    # Round values and make all the same number of digits
    pattern <- paste0("%0.",digits,"f")
    indexPretty <- apply(index, c(1,2), function(d){d <- round(d,digits);sprintf(pattern, d)})
    tabledf <- rbind(tabledf, header, indexPretty)
  }

  if(savetable){
    write.table(tabledf, filename, quote=FALSE, sep=",", col.names=FALSE, row.names=FALSE)
    cat0(.PROJECT_NAME,"->",currFuncName,"Wrote table to file: ",filename)
  }else{
    print(tabledf)
  }


}

decisionTable <- function(outMCMC   = NULL,
                          names     = NULL,
                          ci        = NULL,
                          burnthin  = list(0,1),
                          savetable = FALSE,
                          filename  = "default",
                          digits    = 3,          # Number of digits to round the output table to
                          verbose   = FALSE){

  currFuncName <- getCurrFunc()
  if(is.null(outMCMC)){
    cat0(.PROJECT_NAME,"->",currFuncName,"You must supply an output vector for MCMC data (outMCMC).")
    return(NULL)
  }
  if(length(outMCMC) < 1){
    cat0(.PROJECT_NAME,"->",currFuncName,"You must supply at least one element in the MCMC output vector (outMCMC).")
    return(NULL)
  }
  if(is.null(names)){
    cat0(.PROJECT_NAME,"->",currFuncName,"You must supply a names vector (names).")
    return(NULL)
  }
  if(is.null(names)){
    cat0(.PROJECT_NAME,"->",currFuncName,"You must supply a confidence interval in % (ci).")
    return(NULL)
  }

  oldPar <- par(no.readonly=TRUE)
  on.exit(par(oldPar))

  projdat <- outMCMC[[1]]$mcmc$proj
  projfields <- names(projdat)
  burn <- burnthin[[1]]
  thin <- burnthin[[2]]
  # Code assumes that the fields are in the order show here. The names (years) may change from year to year,
  # but they must be in this order:
  # 1  TAC
  # 2  B2015
  # 3  B2016
  # 4  B0
  # 5  04B0
  # 6  02B0
  # 7  B1996
  # 8  B2016B2015
  # 9  B201604B0
  # 10 B201602B0
  # 11 B2016B1996
  # 12 F2014
  # 13 F2015
  # 14 F2015F2014
  # 15 U2015
  # 16 U2015U2014
  # 17 BMSY
  # 18 B2016BMSY
  # 19 B201608BMSY
  # 20 B201604BMSY
  # 21 FMSY
  # 22 F2015FMSY
  # 23 UMSY
  # 24 U2015UMSY

  probs <- data.frame()
  probsnames <- NULL
  tac <- sort(unique(projdat[,1]))
  for(t in 1:length(tac)){
    dat <- projdat[projdat[,1]==tac[t],]
    dat <- dat[(burn+1):nrow(dat),] # Remove burn-in samples
    dlen <- length(dat[,1])
    probs <- rbind(probs,
                   c(tac[t],
                     length(which(dat[,8]<1))/dlen,   # B2016/B2015
                     length(which(dat[,9]<1))/dlen,   # B2016/0.4B0
                     length(which(dat[,10]<1))/dlen,  # B2016/0.2B0
                     length(which(dat[,11]<1))/dlen,  # B2016/B1996
                     length(which(dat[,18]<1))/dlen,  # B2016/Bmsy
                     length(which(dat[,19]<1))/dlen,  # B2016/0.8Bmsy
                     length(which(dat[,20]<1))/dlen,  # B2016/0.4Bmsy
                     length(which(dat[,14]>1))/dlen,  # F2015/F2014 - Note the change from < to > for Fs
                     length(which(dat[,22]>1))/dlen,  # F2015/Fmsy
                     length(which(dat[,16]>1))/dlen,  # U2015/U2014
                     length(which(dat[,24]>1))/dlen)) # U2015/Umsy
  }
  tmp <- projdat[,c(1,8,9,10,11,18,19,20,14,22,16,24)] # Same numbers as in loop above
  names(probs) <- c(names(tmp)[1], paste0("P_",names(tmp)[-1])) #Prepend 'P_', except for first one which is TAC

  # Round values and make all the same number of digits
  pattern <- paste0("%0.",digits,"f")
  probs <- apply(probs, c(1,2), function(d){d <- round(d,digits);sprintf(pattern, d)})
  if(savetable){
    write.table(probs, filename, quote=FALSE, sep=",", col.names=TRUE, row.names=FALSE)
    cat0(.PROJECT_NAME,"->",currFuncName,"Wrote table to file: ",filename)
  }else{
    print(probs)
  }
}

valueTable <- function(outMPD    = NULL,
                       outMCMC   = NULL,
                       names     = NULL,
                       ci        = NULL,
                       burnthin  = list(0,1),
                       savetable = FALSE,
                       filename  = "default",
                       digits    = 3,
                       verbose   = FALSE){

  currFuncName <- getCurrFunc()
  if(is.null(outMPD)){
    cat0(.PROJECT_NAME,"->",currFuncName,"You must supply an output vector for MPD data (outMPD).")
    return(NULL)
  }
  if(is.null(outMCMC)){
    cat0(.PROJECT_NAME,"->",currFuncName,"You must supply an output vector for MCMC data (outMCMC).")
    return(NULL)
  }
  if(length(outMPD) < 1){
    cat0(.PROJECT_NAME,"->",currFuncName,"You must supply at least one element in the MPD output vector (outMPD).")
    return(NULL)
  }
  if(length(outMCMC) < 1){
    cat0(.PROJECT_NAME,"->",currFuncName,"You must supply at least one element in the MCMC output vector (outMCMC).")
    return(NULL)
  }
  if(is.null(names)){
    cat0(.PROJECT_NAME,"->",currFuncName,"You must supply a names vector (names).")
    return(NULL)
  }
  if(is.null(names)){
    cat0(.PROJECT_NAME,"->",currFuncName,"You must supply a confidence interval in % (ci).")
    return(NULL)
  }

  oldPar <- par(no.readonly=TRUE)
  on.exit(par(oldPar))

  burn <- burnthin[[1]]
  thin <- burnthin[[2]]

  # Apply the mcmc windowing and getQuants function to the mcmc output
  # Cannot use 'apply' function because mcmc object cannot have a function applied to it
  mcmcObj <- apply(outMCMC, 2, mcmc)
  mcmcWindow <- NULL
  for(col in 1:ncol(mcmcObj)){
    tmp <- window(mcmcObj[,col], start=burn, thin=thin)
    mcmcWindow <- cbind(mcmcWindow, tmp)
  }
  tmpQuants <- as.data.frame(apply(mcmcWindow, 2, getQuants, ci))
  names(tmpQuants) <- names(outMCMC)

  # Add mpd data
  alltable <- rbind(tmpQuants, outMPD)
  rown <- rownames(alltable)
  rown[length(rown)] <- "MPD"
  rownames(alltable) <- rown

  # Round values and make all the same number of digits
  pattern <- paste0("%0.",digits,"f")
  alltable <- apply(alltable, c(1,2), function(d){d <- round(d,digits);sprintf(pattern, d)})

  if(savetable){
    write.table(t(alltable), filename, quote=FALSE, sep=",", col.names=TRUE, row.names=TRUE)
    cat0(.PROJECT_NAME,"->",currFuncName,"Wrote table to file: ",filename)
  }else{
    print(t(alltable))
  }
}

refPointsTable <- function(outMPD    = NULL,
                           outMCMC   = NULL,
                           names     = NULL,
                           ci        = NULL,
                           burnthin  = list(0,1),
                           savetable = FALSE,
                           filename  = "default",
                           digits    = 3,
                           verbose   = FALSE){

  currFuncName <- getCurrFunc()
  if(is.null(outMPD)){
    cat0(.PROJECT_NAME,"->",currFuncName,"You must supply an output vector for MPD data (outMPD).")
    return(NULL)
  }
  if(is.null(outMCMC)){
    cat0(.PROJECT_NAME,"->",currFuncName,"You must supply an output vector for MCMC data (outMCMC).")
    return(NULL)
  }
  if(length(outMPD) < 1){
    cat0(.PROJECT_NAME,"->",currFuncName,"You must supply at least one element in the MPD output vector (outMPD).")
    return(NULL)
  }
  if(length(outMCMC) < 1){
    cat0(.PROJECT_NAME,"->",currFuncName,"You must supply at least one element in the MCMC output vector (outMCMC).")
    return(NULL)
  }
  if(is.null(names)){
    cat0(.PROJECT_NAME,"->",currFuncName,"You must supply a names vector (names).")
    return(NULL)
  }
  if(is.null(names)){
    cat0(.PROJECT_NAME,"->",currFuncName,"You must supply a confidence interval in % (ci).")
    return(NULL)
  }

  oldPar <- par(no.readonly=TRUE)
  on.exit(par(oldPar))

  burn <- burnthin[[1]]
  thin <- burnthin[[2]]

  # Calculate quantiles for the posterior data if an MCMC is to be plotted
  quants <- vector("list", length(outMCMC))
  for(model in 1:length(outMCMC)){
    mcmcData <- outMCMC[[model]]$mcmc$params
    # If you are trying to show more than one group or area's parameters,
    # comment the next line below out.
    mcmcData <- stripAreasGroups(mcmcData)
    # We only want to see estimated parameters, so this call strips the static params.
    mcmcData <- stripStaticParams(model, mcmcData)

    # Remove some of them... We want only ref points and nothing else
    mcmcnames <- names(mcmcData)
    mcmcData <- mcmcData[ ,which(mcmcnames %in% c("fmsy","bmsy","umsy","ssb","bo"))]
    mcmcnames <- names(mcmcData)
    # Change then name 'ssb' to B followed by the final year.
    yrs <- names(outMCMC[[1]]$mcmc$sbt[[1]])
    mcmcnames[mcmcnames=="ssb"] = paste0("B",yrs[length(yrs)])

    # Add the initial year biomass (first column of sbt)
    sbt <- outMCMC[[model]]$mcmc$sbt[[1]]
    sbtinit <- sbt[,1]
    yrinit <- yrs[1]
    mcmcData <- cbind(mcmcData, sbtinit)
    mcmcnames <- c(mcmcnames, paste0("B",yrinit))

    # Add end year Fishing mortalities
    ft <- outMCMC[[model]]$mcmc$ft[[1]][[1]]
    ftend <- ft[,ncol(ft)]
    # Get name by stripping year from last column name
    fnames <- names(ft)
    fendname <- fnames[length(fnames)]
    yrend <- gsub(".*_([[:digit:]]+)","\\1",fendname)
    mcmcData <- cbind(mcmcData, ftend)
    mcmcnames <- c(mcmcnames, paste0("F",yrend))

    # Add the newly formed names to the data frame
    names(mcmcData) <- mcmcnames

    # Apply the mcmc windowing and getQuants function to each parameter (column) in mcmcData
    # Cannot use 'apply' function because mcmc object cannot have a function applied to it
    mcmcObj <- apply(mcmcData, 2, mcmc)
    mcmcWindow <- NULL
    for(col in 1:ncol(mcmcObj)){
      tmp <- window(mcmcObj[,col], start=burn, thin=thin)
      mcmcWindow <- cbind(mcmcWindow, tmp)
    }
    tmpQuants <- as.data.frame(apply(mcmcWindow, 2, getQuants, ci))
    names(tmpQuants) <- names(mcmcData)
    quants[[model]] <- t(tmpQuants)
  }

  # Round values and make all the same number of digits
  pattern <- paste0("%0.",digits,"f")
  quants <- apply(quants[[1]], c(1,2), function(d){d <- round(d,digits);sprintf(pattern, d)})

  if(savetable){
    write.table(quants, filename, quote=FALSE, sep=",", col.names=TRUE, row.names=TRUE)
    cat0(.PROJECT_NAME,"->",currFuncName,"Wrote table to file: ",filename)
  }else{
    print(quants[[1]])
  }
}

paramEstTable <- function(outMPD    = NULL,
                          outMCMC   = NULL,
                          names     = NULL,
                          ci        = NULL,
                          burnthin  = list(0,1),
                          savetable = FALSE,
                          filename  = "default",
                          digits    = 3,
                          verbose   = FALSE){

  currFuncName <- getCurrFunc()
  if(is.null(outMPD)){
    cat0(.PROJECT_NAME,"->",currFuncName,"You must supply an output vector for MPD data (outMPD).")
    return(NULL)
  }
  if(is.null(outMCMC)){
    cat0(.PROJECT_NAME,"->",currFuncName,"You must supply an output vector for MCMC data (outMCMC).")
    return(NULL)
  }
  if(length(outMPD) < 1){
    cat0(.PROJECT_NAME,"->",currFuncName,"You must supply at least one element in the MPD output vector (outMPD).")
    return(NULL)
  }
  if(length(outMCMC) < 1){
    cat0(.PROJECT_NAME,"->",currFuncName,"You must supply at least one element in the MCMC output vector (outMCMC).")
    return(NULL)
  }
  if(is.null(names)){
    cat0(.PROJECT_NAME,"->",currFuncName,"You must supply a names vector (names).")
    return(NULL)
  }
  if(is.null(names)){
    cat0(.PROJECT_NAME,"->",currFuncName,"You must supply a confidence interval in % (ci).")
    return(NULL)
  }

  oldPar <- par(no.readonly=TRUE)
  on.exit(par(oldPar))

  burn <- burnthin[[1]]
  thin <- burnthin[[2]]

  # Calculate quantiles for the posterior data if an MCMC is to be plotted
  quants <- vector("list", length(outMCMC))
  for(model in 1:length(outMCMC)){
    mcmcData <- outMCMC[[model]]$mcmc$params
    # If you are trying to show more than one group or area's parameters,
    # comment the next line below out.
    mcmcData <- stripAreasGroups(mcmcData)
    # We only want to see estimated parameters, so this call strips the static params.
    mcmcData <- stripStaticParams(model, mcmcData)

    # Remove some of them... We want only estimated parameters, not all mcmc variables
    mcmcnames <- names(mcmcData)
    mcmcData <- mcmcData[ , -which(mcmcnames %in% c("msy","fmsy","bmsy","umsy","ssb","bo"))]
    mcmcnames <- names(mcmcData)

    # Apply the mcmc windowing and getQuants function to each parameter (column) in mcmcData
    # Cannot use 'apply' function because mcmc object cannot have a function applied to it
    mcmcObj <- apply(mcmcData, 2, mcmc)
    mcmcWindow <- NULL
    for(col in 1:ncol(mcmcObj)){
      tmp <- window(mcmcObj[,col], start=burn, thin=thin)
      mcmcWindow <- cbind(mcmcWindow, tmp)
    }
    tmpQuants <- as.data.frame(apply(mcmcWindow, 2, getQuants, ci))
    names(tmpQuants) <- names(mcmcData)
    quants[[model]] <- tmpQuants

    # Append MPD values, must match names of mcmc parameters to mpd names, which may be a little different
    tmpMPD <- outMPD[[model]]$mpd
    mpdnames <- names(tmpMPD)
    mpdparamvals <- NULL
    for(pname in mcmcnames){
      # This is hack code because iscam is not outputting the same parameter names for MPD and MCMC runs
      if(pname == "h"){
        pname <- "steepness"
      }
      if(pname == "m1"){
        pname <- "m"
      }
      if(pname == "bo"){
        pname <- "sbo"
      }

      matchsel <- grep("sel[[:digit:]]+",pname)
      matchq <- grep("q[[:digit:]]+",pname)
      selpars <- tmpMPD$sel_par[,3] # Age value at 50% only, not Age SD at 50% (that would be column 4)
      qpars <- tmpMPD$q
      if(length(matchsel) > 0){
        # The parameter starts with "sel"
        splitval <- strsplit(pname, "[^[:digit:]]")[[1]]
        selnum <- as.numeric(splitval[length(splitval)])
        thispar <- selpars[selnum]
      }else if(length(matchq) > 0){
        # The parameter starts with "q"
        splitval <- strsplit(pname, "[^[:digit:]]")[[1]]
        qnum <- as.numeric(splitval[length(splitval)])
        thispar <- qpars[qnum]
      }else{
        # Match the mcmc name with the mpd name. Q and selectivity are special cases, they must be extracted from
        # vectors and matrices respectively.
        thispar <- tmpMPD[match(pname, mpdnames)]
      }
      mpdparamvals <- c(mpdparamvals, thispar)
    }
    names(mpdparamvals) <- mcmcnames
    alltable <- rbind(tmpQuants, mpdparamvals)
    rown <- rownames(alltable)
    rown[length(rown)] <- "MPD"
    rownames(alltable) <- rown
  }
  alltable <- t(alltable)

  # Round values and make all the same number of digits
  pattern <- paste0("%0.",digits,"f")
  alltable <- apply(alltable, c(1,2), function(d){d <- round(d,digits);sprintf(pattern, d)})

  if(savetable){
    write.table(alltable, filename, quote=FALSE, sep=",", col.names=TRUE, row.names=TRUE)
    cat0(.PROJECT_NAME,"->",currFuncName,"Wrote table to file: ",filename)
  }else{
    print(alltable)
  }
}
