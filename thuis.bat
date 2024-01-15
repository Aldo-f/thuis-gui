@echo off
echo Running thuis.bat with parameters: %*

:: Set variables for input and output files
set input=%1
set output=%~dp0media\thuis.mp4

:: Check if the media folder exists, create it if not
if not exist %~dp0media (
    mkdir %~dp0media
    echo Media folder created.
)

:: Set the ffmpeg command with variables
set ffmpeg_command=ffmpeg.exe -v quiet -stats -i %input% -crf 0 -aom-params lossless=1 -map 0:v:0 -c:v copy -map 0:a -c:a copy -tag:v avc1 %output%

:: Echo the command
echo Running ffmpeg with the following command:
echo %ffmpeg_command%

:: Run your custom ffmpeg command with variables
%ffmpeg_command%

:: Send a response with the path when the file has been downloaded
echo File has been downloaded successfully to: %output%
