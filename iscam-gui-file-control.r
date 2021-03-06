
#**********************************************************************************
# iscam-gui-file-control.r
# This file contains:
# 1. Functions for creating/editing dat, control, and starter files for the stock of your choice.
# 2. Functions for copying these files to the execution directory
# 3. Functions for copying the outputs from the admb runs back to the scenario directories
# 4. Function to copy model executable to each Scenarios' folder
#
# The data structure used is an op, which is a list of lists, see loadScenarios.r for
# details on this structure. This file assumes that an object called 'op'
# exists and is a valid op.
#
# Assumes that the tcl/tk window is open and ready to be read from/written to
# using PBSmodelling commands such as setWinVal() and getWinVal().  Also assumes
# that the variable fdScenario is in the .GlobalEnv workspace and that it points to the
# current Scenario.
# Assumes iscam-gui-load-scenarios.r has been sourced. It instantiates the path and file name variables.
#
# Author            : Chris Grandin
# Development Date  : September 2013 - Present
#
#**********************************************************************************

.copyExecutableToScenarioDirectory <- function(scenario, silent = .SILENT){
# Copies the model executable from the execution directory to
# the given scenario folder
  src <- .EXE_FILE_NAME_FULL_PATH
  des <- file.path(op[[scenario]]$names$dir,.EXE_FILE_NAME)
  file.copy(src, des, overwrite = TRUE)
  if(!silent){
    cat("Copied model executable from '",src,"' to '",des,"'\n\n",sep="")
  }
}

.copyExecutableToScenariosDirectories <- function(silent = .SILENT){
# Copies the model executable from the execution directory to
# all scenarios folders.
  for(scenario in 1:length(dirList)){
    .copyExecutableToScenarioDirectory(scenario)
  }
}

.deleteOutputs <- function(scenario, silent = .SILENT){
  # delete all files output by iSCAM.
  currFuncName <- getCurrFunc()
  outputsFullPath <- file.path(op[[scenario]]$names$dir, .OUTPUT_FILES)
  if(!any(file.exists(outputsFullPath))){
      cat0(.PROJECT_NAME,"->",currFuncName,"The model in '",op[[scenario]]$names$dir,
          "' has not been run (no output files exist).")
    return(TRUE)
  }else if(any(file.exists(outputsFullPath)) &&
     getYes(paste0("Warning, you are about to delete all outputs for the '",op[[scenario]]$names$scenario,
                  "' scenario. Continue?"),title="Delete Files?",icon="question")){
    unlink(outputsFullPath)
    if(!silent){
      cat0(.PROJECT_NAME,"->",currFuncName,"Deleted MPD outputs from '",op[[scenario]]$names$dir,"'")
    }
    return(TRUE)
  }
  return(FALSE)
}

.editFile <- function(scenario, type, silent = .SILENT){
  # type is one of 1, 2, 3, 4, 5, 6 where:
  # 1 = Control file
  # 2 = Data file
  # 3 = Starter file
  # 4 = Command line output
  # 5 = Forecast file
  # 6 = Warning file
  # 7 = PAR file
  # 8 = Report file
  if(type==1){
    editCall <- paste(.EDITOR,op[[scenario]]$names$control)
    shell(editCall, wait=F)
  }
  if(type==2){
    editCall <- paste(.EDITOR,op[[scenario]]$names$data)
    shell(editCall, wait=F)
  }
  if(type==3){
    editCall <- paste(.EDITOR,op[[scenario]]$names$starter)
    shell(editCall, wait=F)
  }
  if(type==4){
    if(file.exists(op[[scenario]]$names$log)){
      editCall <- paste(.EDITOR,op[[scenario]]$names$log)
      shell(editCall, wait=F)
    }else{
      cat(.PROJECT_NAME,"->.editFile: '",op[[scenario]]$names$log,"' does not exist.\n",
          "You must run the model from within the GUI to create this file.\n")
    }
  }
  if(type==5){
    editCall <- paste(.EDITOR,op[[scenario]]$names$projection)
    shell(editCall, wait=F)
  }
  if(type==6){
    if(file.exists(op[[scenario]]$names$log)){
      editCall <- paste(.EDITOR,op[[scenario]]$names$warnings)
      shell(editCall, wait=F)
    }else{
      cat(.PROJECT_NAME,"->.editFile: '",op[[scenario]]$names$warnings,"' does not exist.\n",
          "You must run the model from within the GUI to create this file.\n")
    }
  }
  if(type==7){
    if(file.exists(op[[scenario]]$names$par)){
      editCall <- paste(.EDITOR,op[[scenario]]$names$par)
      shell(editCall, wait=F)
    }else{
      cat(.PROJECT_NAME,"->.editFile: '",op[[scenario]]$names$par,"' does not exist.\n",
          "You must run the model from within the GUI to create this file.\n")
    }
  }
  if(type==8){
    if(file.exists(op[[scenario]]$names$report)){
      editCall <- paste(.EDITOR,op[[scenario]]$names$report)
      shell(editCall, wait=F)
    }else{
      cat(.PROJECT_NAME,"->.editFile: '",op[[scenario]]$names$report,"' does not exist.\n",
          "You must run the model to create this file.\n")
    }
  }

}
