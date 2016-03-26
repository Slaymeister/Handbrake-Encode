# Encode-All 

param(
    [string]$exe = 'C:\Program Files\Handbrake\HandBrakeCLI.exe',
    [string]$InDir = 'X:\media\Video\ISO\New',
    [string]$DoneDir = 'X:\media\Video\ISO\Processed',
    [string]$OutPath = 'D:\VideoProcessing\MKV',
    [string]$LogFileParam = "",
    [bool]$Overwrite = $false,
    [bool]$SearchNewTracks = $true
    )

    #Specify Handbrake parameters by category
    [string]$Handbrake_GeneralOptions = ''
    [string]$Handbrake_SourceOptions = ''
    [string]$Handbrake_DestinationOptions = '--markers --format mkv --use-hwd'
    [string]$Handbrake_VideoOptions = '--encoder x264 --quality 20.0 --x264-preset veryslow --x264-profile high --h264-level 4.1 --vfr'
    [string]$Handbrake_AudioOptions = '--audio 1,2,3,4,5,6,7,8,9,10 --aencoder copy --audio-fallback ffac3'
    [string]$Handbrake_PictureSettings = '--width 720 --maxHeight 480 --loose-anamorphic --modulus 2'
    [string]$Handbrake_Filters = '--decomb'
    [string]$Handbrake_SubtitleOptions = '--subtitle scan,1,2,3,4,5,6,7,8,9,10 --native-language eng --native-dub'
    [string]$Handbrake_Parameters = "$Handbrake_GeneralOptions $Handbrake_SourceOptions $Handbrake_DestinationOptions $Handbrake_VideoOptions $Handbrake_AudioOptions $Handbrake_PictureSettings $Handbrake_Filters $Handbrake_SubtitleOptions"
    #https://trac.handbrake.fr/wiki/CLIGuide

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
    $input=$_

    #Figure out a subdirectory name based on the source
    $OutDir = $OutPath + '\' + $input.BaseName

    #If a single log wasn't specified, create a per job log file next to the output files
    if ($LogFileParam -match "") {
        $LogFile = $OutDir+ '\' + $input.BaseName + '.log' 
    }
    else {
        $LogFile = $LogFileParam
    }

    #TempLog is used to hold StdErr during an encode, then is added to the main log file (master log file or per job log file) after the encode is complete.
    $TempLog = $OutDir+ '\' + $input.BaseName + '.templog'
        
    #Identify all of the source files so they can be moved after the job.
    $FileSetFilter = $input.BaseName + ".*"
    $FileSet = Get-ChildItem -Path "$InDir" -Filter "$FileSetFilter"

    #Don't do anything if the output sub directory already exists.  If you want to redo the encode, just move or delete the directory.
    if (!(Test-Path $OutDir)){

            #Test to see if the input file is locked, such as if it is open in an editor or it is an ISO being ripped directly into $InDir
            $FileLocked = $false
            if ($FileLocked -notmatch $true){ 
                #Process a single title at a time.  It tries 100 chapters rather than trying to figure out how many are really there. 
                for ($a = 1; $a -le 100; $a++){
        
                    $output = $OutDir + '\' + $input.BaseName + '-' + ($a -as [string]) +'.mkv'
                    $FileExists = Test-Path $output
        
                    #Test if file already exists.  Just in case two encoders manage to start in on the same source.
                    if ($FileExists -eq $false) {

                        $PathExists = Test-Path $OutDir
                        if ($PathExists -eq $false){

                            New-Item -ItemType Directory -Force -Path $OutDir
                            $PathExists = Test-Path $OutDir
                        }
                        
                        $cmd_Arguments = "/s /c `"(`"$exe`" $Handbrake_Parameters --input `"$input`" --title $a --output `"$output`")&(echo `"Handbrake $input completion errorlevel = %errorlevel%`">>$TempLog)`""
                        $LogDate = Get-Date; Add-Content $LogFile "`n`n`"$exe`" $Handbrake_Parameters --input `"$input`" --title $a --output `"$output`""
                    
                        Start-Process -FilePath c:\windows\system32\cmd.exe -RedirectStandardError $TempLog -Wait -ArgumentList "$cmd_Arguments"


                        #&$exe $Handbrake_Parameters --input "$_" --title $a --output "$output" 2>> $TempLog
                        Add-Content -Path $LogFile -Value (Get-Content $TempLog); Remove-Item $TempLog
                        Add-Content $LogFile "CMD ErrorLevel $output = $LASTEXITCODE"
                        #if ($LASTEXITCODE -eq 1) {$ProcessError = $true}
                    }
                }

        #if ($ProcessError -eq $false) {
        Move-Item $FileSet -Destination $DoneDir -Path $InDir

        #}

        }
    }
    #Put Renamer code here
}

