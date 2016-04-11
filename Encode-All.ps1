# Encode-All 

param(
    [string]$exe = 'C:\Program Files\Handbrake\HandBrakeCLI.exe',
    [string]$InDir = 'X:\media\Video\ISO\New',
    [string]$DoneDir = 'X:\media\Video\ISO\Processed',
    [string]$OutPath = 'D:\VideoProcessing\MKV',
    [string]$LogFileParam = "",
    [bool]$Overwrite = $false,
    #[bool]$SearchNewTracks = $true,
    [bool]$SkipEncode = $false,
    [bool]$MoveDone = $true
    )

    #Specify Handbrake parameters by category
    [string]$Handbrake_GeneralOptions = '-v1'
    [string]$Handbrake_SourceOptions = ''
    [string]$Handbrake_DestinationOptions = '--markers --format mkv --use-hwd'
    [string]$Handbrake_VideoOptions = '--encoder x264 --quality 20.0 --x264-preset veryslow --x264-profile high --h264-level 4.1 --vfr'
    [string]$Handbrake_AudioOptions = '--audio 1,2,3,4,5,6,7,8,9,10 --aencoder copy --audio-fallback ffac3'
    [string]$Handbrake_PictureSettings = '--width 720 --maxHeight 480 --loose-anamorphic --modulus 2'
    [string]$Handbrake_Filters = '--decomb'
    [string]$Handbrake_SubtitleOptions = '--subtitle scan,1,2,3,4,5,6,7,8,9,10 --native-language eng --native-dub'
    [string]$Handbrake_Parameters = "$Handbrake_GeneralOptions $Handbrake_SourceOptions $Handbrake_DestinationOptions $Handbrake_VideoOptions $Handbrake_AudioOptions $Handbrake_PictureSettings $Handbrake_Filters $Handbrake_SubtitleOptions"
    #https://trac.handbrake.fr/wiki/CLIGuide
    $DoneDir = "$DoneDir\" -replace "\\","\"

function Test-FileLock {
      param ([parameter(Mandatory=$true)][string]$Path)

  $oFile = New-Object System.IO.FileInfo $Path

  if ((Test-Path -Path $Path) -eq $false)
  {
    return $false
  }

  try
  {
      $oStream = $oFile.Open([System.IO.FileMode]::Open, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None)
      if ($oStream)
      {
        $oStream.Close()
      }
      $false
  }
  catch
  {
    # file is locked by a process.
    return $true
  }
}

Get-ChildItem $InDir\*.iso | ForEach-Object {
    Write-Host "`n"
    $input=$_
    Write-Host "Begin processing $input."
    $inputBaseName = $_.BaseName

    #Figure out subdirectory names based on the source
    $OutDir = $OutPath + '\' + $inputBaseName -replace "\\","\"
    

    #If a single log wasn't specified, create a per job log file next to the output files
    if ($LogFileParam -match "") {
        $LogFile = "$OutDir\$inputBaseName.log" 
    }
    else {
        $LogFile = $LogFileParam
    }

    #RenamerFile is a CSV file that holds special instructions about the encode that do not depend on the 
    #encode destination format.  Used if an entire library gets re-encoded for a new format, without losing renames.
    #The RenamerFile is kept with the source ISO.  If one is not found, a blank will be created by the encode process.
    #Examples include renaming numbered tracks to reflect content (ie., Rename "Movie-5.mkv" to "Movie - Cast Interviews.mkv")
    #The RenamerFile can also contain a Category which, which is a subdirectory the encoded movie will be added to.
    #For example OutDir = J:\Movies, "Kid Flick" has a category of "Animation", final directory would be
    #"J:\Movies\Animation\Kid Flick\[encoded files]"
    $RenamerFile = "$InDir\$inputBaseName.renamer"
    $RenamerFileExists = Test-Path ($RenamerFile)
    #TempLog is used to hold StdErr during an encode, then is added to the main log file (master log file or per job log file) after the encode is complete.
    $TempLog = "$OutDir\$inputBaseName.templog"
    #Identify all of the source files so they can be moved after the job.
    [string]$FileSetFilter = "$inputBaseName.*"
    $FileSet = Get-ChildItem -Path "$InDir" -Filter "$FileSetFilter"

    #Don't do anything if the output sub directory already exists.  If you want to redo the encode, just move or delete the directory.
    if (!(Test-Path $OutDir)){

            #Test to see if the input file is locked, such as if it is open in an editor or it is an ISO being ripped directly into $InDir
            $FileLocked = Test-FileLock ($input)
            if ($FileLocked -notmatch $true){ 
                #Process a single title at a time.  It tries 100 chapters rather than trying to figure out how many are really there. 
                for ($a = 1; $a -le 100; $a++){
                    
                    if ($a -le 9){$TrackNumberString = "0$a"}
                        else {$TrackNumberString = $a}

                    $output = "$OutDir\$inputBaseName-$TrackNumberString.mkv"
                    Write-Host "Beginning processing for $output." 
                    $FileExists = Test-Path $output
        
                    #Test if file already exists.  Just in case two encoders manage to start in on the same source.
                    if ($FileExists -match $false -or $Overwrite -match $true) {

                        $PathExists = Test-Path $OutDir
                        if ($PathExists -match $false){

                            New-Item -ItemType Directory -Force -Path $OutDir
                            $PathExists = Test-Path $OutDir
                        }
                        
                        $cmd_Arguments = "/s /c `"(`"$exe`" $Handbrake_Parameters --input `"$input`" --title $a --output `"$output`")`""
                        $LogDate = Get-Date; Add-Content $LogFile "`n`n`"$exe`" $Handbrake_Parameters --input `"$input`" --title $a --output `"$output`""
                        if ($SkipEncode -notmatch $true){
                            Start-Process -FilePath c:\windows\system32\cmd.exe -RedirectStandardError $TempLog -Wait -ArgumentList "$cmd_Arguments"
                            $EncodeExitCode = $LASTEXITCODE
                            Add-Content $LogFile "`nAdd Encode Log $TempLog to $LogFile"
                            Add-Content -Path $LogFile -Value (Get-Content $TempLog)
                            Add-Content $LogFile "`nRemove Temporary Log File $TempLog"
                            Remove-Item $TempLog
                            Add-Content $LogFile "`nCMD ErrorLevel $output = $EncodeExitCode"
                            }
                        else {Add-Content $LogFile "`nEncode Skipped by user option.`n"}

                        #if ($LASTEXITCODE -eq 1) {$ProcessError = $true}
                        #Handbrake errors being produced on missing tracks.
                    }
                    else {Write-host "File exists and not set to overwrite.  Skipping."}
                }
        }
            else {Write-Host "$input is locked.  Aborting Processing."}
        #Generate default renamer if one does not exist
        If ($RenamerFileExists -match $false) {
        New-Item $RenamerFile -ItemType File
        Add-Content $RenamerFile "CATEGORY,"
        Get-ChildItem $OutDir -filter *.mkv | ForEach-Object {
            $OutputFileBaseName = $_.BaseName 
            Add-Content $RenamerFile "`nRENAME,$OutputFileBaseName,$OutputFileBaseName"
            }
        }
        
        if ($MoveDone -match $true) {
            Add-Content $LogFile "`nMove $InDir\$FileSetFilter to $DoneDir"
            Move-Item "$InDir\$FileSetFilter" -Destination "$DoneDir"
        }
    }
    else {Write-Host "Output Path Already Exists.  Aborting Processing for $input."}
    Write-Host "`n"
}

