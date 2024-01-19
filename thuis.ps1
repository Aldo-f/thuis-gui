# Function to process command-line arguments
Function ProcessCommandLineArguments {
    param (
        [string[]] $arguments
    )

    $settings = @{
        list        = $null
        resolutions = '1080'
        filename    = $null
    }

    # Process each argument
    for ($i = 0; $i -lt $arguments.Count; $i++) {
        $arg = $arguments[$i]

        switch -regex ($arg) {
            "^\-list$" { $settings.list = $arguments[++$i] }
            "^\-resolutions$|^\-p$" { $settings.resolutions = $arguments[++$i] }
            "^\-filename$" { $settings.filename = $arguments[++$i] }
            "^[^-]" { $settings.list = $arg }
        }
    }

    return $settings
}

# Function to increment the output filename
function GenerateOutputName {
    param (
        [string]$filename = "",
        [string]$directory = "",
        [PSCustomObject]$usedIndices
    )

    function IncrementAndGenerateFilename($prefix, $index, $extension) {
        $outputFilename = "${prefix}$("{0:D3}" -f $index)$extension"

        if ($usedIndices.Indices -notcontains $index -and -not (Test-Path (Join-Path $directory $outputFilename))) {
            $usedIndices.Indices += $index
            return $outputFilename
        }

        $index++
        return $null
    }

    if ($filename) {
        $lastPartAndExtension = $filename -replace '^.*[^0-9](\d+)(\.[^.]+)$', '$1$2'
    
        if ($lastPartAndExtension -ne $filename) {
            $prefix = $filename -replace '\d+(\.[^.]+)$', ''
            $index = [int]($lastPartAndExtension -replace '\..*$')
            $extension = $filename -replace '^.*(\.[^.]+)$', '$1'
    
            do {
                $outputFilename = IncrementAndGenerateFilename $prefix $index $extension
    
                if ($outputFilename) {
                    return $outputFilename
                }
    
                $index++
            } while ($true)
        }
    }
    
    
    $currentDate = Get-Date -Format 'y-M-d'
    $index = 1
    do {
        $outputFilename = IncrementAndGenerateFilename "${currentDate}_" $index ".mp4"

        if ($outputFilename) {
            return $outputFilename
        }

        $index++
    } while ($true)
}

function ProcessInputFile {
    param (
        [string]$inputFile,
        [string]$filename,
        [string]$directory,
        [PSCustomObject]$usedIndices
    )

    # Use ffprobe to determine the codec types present in the input file
    $codecType = & ffprobe.exe -loglevel error -show_entries stream=codec_type -of default=nw=1 "$inputFile" | ForEach-Object { $_.Trim() }

    # Check if the codecType contains "video"
    if ($codecType -match "video") {
        Write-Host "Input file is a video."
        $outputFilename = GenerateOutputName -filename "$filename.mp4" -directory $directory -usedIndices $usedIndices
        $outputFile = Join-Path $directory "$outputFilename"
        $ffmpegCommand = "ffmpeg.exe -v quiet -stats -i `"$inputFile`" -crf 0 -aom-params lossless=1 -map 0:v:0 -map 0:a -c:a copy -tag:v avc1 `"$outputFile`""
    }
    else {
        Write-Host "Input file is audio-only."
        $outputFilename = GenerateOutputName -filename "$filename.mp3" -directory $directory -usedIndices $usedIndices
        $outputFile = Join-Path $directory "$outputFilename"
        $ffmpegCommand = "ffmpeg.exe -v quiet -stats -i `"$inputFile`" -b:a 320k `"$outputFile`""
    }

    # Check if the media folder exists, create it if not
    if (-not (Test-Path -Path $directory)) {
        New-Item -ItemType Directory -Path $directory
        Write-Host "Media folder created."
    }

    # Echo the command
    Write-Host "Running ffmpeg with the following command:"
    Write-Host $ffmpegCommand

    # Uncomment the line below to run your custom ffmpeg command with variables
    Invoke-Expression $ffmpegCommand

    # Send a response with the path when the file has been downloaded
    Write-Host "File has been downloaded successfully to: $outputFile"
}

# Function to check and try to install dependencies using multiple package managers, provide instructions if not successful
Function CheckAndInstallDependency {
    param (
        [string] $dependencyName,
        [string[]] $installCommands,
        [string] $installInstructions
    )    
    Function DependencyInstalled() {
        param(
            [string] $dependencyName
        )

        $dependencyInstalled = $null

        try {
            $dependencyInstalled = Get-Command $dependencyName -ErrorAction SilentlyContinue
        }
        catch {
            $dependencyInstalled = $null
        }

        return $dependencyInstalled;
    }

    $dependencyInstalled = DependencyInstalled -dependencyName $dependencyName

    if (-not $dependencyInstalled) {
        Write-Host "Dependency '$dependencyName' is not installed. Attempting to install..."

        # Try to install the dependency using multiple package managers
        foreach ($command in $installCommands) {
            Invoke-Expression $command
            # Check if the installation was successful
            try {
                $dependencyInstalled = Get-Command $dependencyName -ErrorAction SilentlyContinue
            }
            catch {
                $dependencyInstalled = $null
            }
            if ($dependencyInstalled) {
                Write-Host "Dependency '$dependencyName' was successfully installed."
                break
            }
        }

        if (-not $dependencyInstalled) {
            # Provide instructions for manual installation
            Write-Host $installInstructions
            Write-Host "After installation, please run the script again."
            Exit
        }
    }
    else {
        # Dependency is already installed.
    }
}

# Function to split a string into an array
function SplitString($string) {
    # Split the $string string by ',' or ';' or ' ' and remove empty entries
    $array = $string -split '[,; ]' | Where-Object { $_ -ne '' }

    # Ensure $array is always an array
    if ($array -isnot [System.Array]) {
        $array = @($array)
    }

    return [System.Array]$array
}

# Check if all dependencies are met
$ffmpegVersion = '6.1'
CheckAndInstallDependency -dependencyName "ffmpeg.exe" `
    -installCommands @(
    "choco install ffmpeg --version $ffmpegVersion -y",
    "winget install ffmpeg -v $ffmpegVersion"
    "scoop install ffmpeg@$ffmpegVersion",
    "(irm get.scoop.sh | iex) -and (scoop install ffmpeg@$ffmpegVersion)"
) `
    -installInstructions "If package managers are not available, please download and install ffmpeg from https://www.ffmpeg.org/download.html"


# Process command-line arguments
$commandLineSettings = ProcessCommandLineArguments -arguments $args

# Check if no input file and -list is provided
if ($commandLineSettings.list -eq "" -or $null -eq $commandLineSettings.list) {
    Write-Host "Error: No input file or -list provided."
    Write-Host "Usage: ./thuis.ps1 [-list <mpd_files>] [-resolutions <preferred_resolution>] [-filename <output_filename>]"
    exit 1
}

# Split the list of mpd files
$mpdFiles = SplitString $commandLineSettings.list

# Define a variable to store used indices
$usedIndices = [PSCustomObject]@{ Indices = @() }

foreach ($inputFile in $mpdFiles) {
    ProcessInputFile -inputFile $inputFile -filename $commandLineSettings.filename -directory 'media' -usedIndices $usedIndices
}

# End of script
