$exe = 'C:\Program Files\Handbrake\HandBrakeCLI.exe'
$InDir = 'Z:\DVDRip\New'
$DoneDir = 'Z:\DVDRip\Processed'
$OutPath = 'D:\VideoProcessing\MKV'


Get-ChildItem $InDir\*.iso | ForEach-Object {
    $ProcessError = $false
    for ($a = 1; $a -le 100; $a++){
        
        $OutDir = $OutPath + '\' + $_.BaseName
        $output = $OutDir + '\' + $_.BaseName + '-' + ($a -as [string]) +'.mkv'
        Write-Host $output
        $FileExists = Test-Path $output
        
        if ($FileExists -eq $false) {
            $PathExists = Test-Path $OutDir
            if ($PathExists -eq $false){
                New-Item -ItemType Directory -Force -Path $OutDir
                $PathExists = Test-Path $OutDir
            }
            
            &'C:\Program Files\Handbrake\HandBrakeCLI.exe' --markers --format mkv --encoder x264 --x264-preset veryslow --x264-profile high --quality 20 --vfr --audio 1,2,3,4,5,6,7,8,9,10 --aencoder copy:ac3 --audio-fallback ac3 --width 720 --maxHeight 480 --strict-anamorphic --decomb --subtitle scan,1,2,3,4,5,6,7,8,9,10 --native-language eng --native-dub  --input "$_" --title $a --output "$output"
            if ($LASTEXITCODE -eq $true) {$ProcessError = $true}
        }
    
    }
    if ($ProcessError -eq $false) {
        move-item $_ -destination $DoneDir
    }
}