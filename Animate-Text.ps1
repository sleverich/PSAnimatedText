param(
    [Parameter()]
    [string]$Lyrics = '.\Lyrics.txt',
    [Parameter()]
    [string]$Song = '.\Song.mp3'
)

# Verify that we have the necessary data
$lyricsFile = Get-Item -Path $Lyrics
$songFile = Get-Item -Path $Song

$dataLoaded = $true
if(-not $lyricsFile) {
    Write-Error ('Unable to find Lyrics file: {0}' -f $Lyrics)
    $dataLoaded = $false
}

if(-not $songFile) {
    Write-Error ('Unable to find Song file: {0}' -f $Song)
    $dataLoaded = $false
}

if(-not $dataLoaded) {
    throw 'Unable to find required files!'
}

# Playback control functions
function startPlayback {
    param(
        [Parameter(ValueFromRemainingArguments = $true)]
        $PlaybackArgs,
        [Parameter()]
        $PlaybackEnvironment
    )
    $mediaPath = $PlaybackArgs[0]
    Add-Type -AssemblyName presentationCore
    $mediaPlayer = New-Object System.Windows.Media.MediaPlayer
    $mediaPlayer.open($mediaPath)
    if(-not $PlaybackEnvironment) {
        $PlaybackEnvironment = [PSCustomObject]@{}
    }
    $PlaybackEnvironment | Add-Member -MemberType NoteProperty -Name 'player' -Value $mediaPlayer
    $mediaPlayer.Play()
    return $PlaybackEnvironment
}

function stopPlayback {
    param(
        [Parameter(Mandatory = $true)]
        $PlaybackEnvironment
    )
    Process {
        $PlaybackEnvironment.player.Stop()
        $PlaybackEnvironment.player.Close()
    }
}

function getPlaybackPosition {
    # Returns total seconds elapsed
    param(
        [Parameter(Mandatory = $true)]
        $PlaybackEnvironment
    )
    Process {
        $progress = $PlaybackEnvironment.player.Position
        return $progress.totalSeconds
    }
}

# Read in Lyrics file (which is a Label track exported from Audacity)

function New-CommandListTextCommand {
    param(
        [Parameter(Mandatory = $true)]
        $ParsingContext,
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string]$Text,
        [Parameter()]
        $Time = 0
    )
    Process {
        $textLength = $Text.Length
        $currentTextRegion = $ParsingContext.currentTextRegion
        $command = @(
            $Time,
            $currentTextRegion.x,
            $currentTextRegion.y,
            $text
        )
        $currentTextRegion.x += $textLength
        $currentTextRegion.boundXHigh = [Math]::Max($currentTextRegion.boundXHigh, $currentTextRegion.x)
        $command
    }
}

function Add-ParsingContextNewline {
    param(
        [Parameter(Mandatory = $true)]
        $ParsingContext
    )
    Process {
        $currentTextRegion = $ParsingContext.currentTextRegion
        $currentTextRegion.x = $currentTextRegion.StartX
        $currentTextRegion.y += 1
        $currentTextRegion.boundXHigh = [Math]::Max($currentTextRegion.boundXHigh, $currentTextRegion.x)
        $currentTextRegion.boundYHigh = [Math]::Max($currentTextRegion.boundYHigh, $currentTextRegion.y)
    }
}


function Parse-LabelTrack {
    param(
        [Parameter(Mandatory = $true)]
        [string]$LabelFilePath,
        [Parameter()]
        $StartX = 0,
        [Parameter()]
        $StartY = 0
    )
    Process {
        $parsingContext = [PSCustomObject]@{
            textRegions = @{
                0 = @{
                    x = $StartX
                    y = $StartY
                    boundXLow = $StartX
                    boundXHigh = $StartX
                    boundYLow = $StartY
                    boundYHigh = $StartY
                    maxX = 255
                    maxY = 255
                }
            }
            contentSeparator = [char]0x09
            currentTextRegion = $null
            commandList = New-Object System.Collections.ArrayList
        }
        $parsingContext.currentTextRegion = $parsingContext.textRegions[0]  # Make the default text region active

        # Step through each line in the label track and parse it
        $labelFileContent = Get-Content -Path $LabelFilePath
        foreach($line in $labelFileContent) {
            $lineParts = $line.split($parsingContext.contentSeparator)
            $text = $lineParts[2]
            if($text[0] -eq '{') {
                $line | Parse-JSONLine -ParsingContext $parsingContext
            }
            else {
                $line | Parse-SimpleLine -ParsingContext $parsingContext
            }
        }
    return $parsingContext.commandList
    }
}

function Parse-SimpleLine {
    param(
        [Parameter(Mandatory = $true)]
        $ParsingContext,
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [ValidateNotNull]
        [string]$Line
    )
    Process {
        $lineParts = $line.split($ParsingContext.contentSeparator)
        [double]$startTime = $lineParts[0]
        [double]$endTime = $lineParts[1]
        $text = $lineParts[2]
        $stringReader = [System.IO.StringReader]::new($text)
        $commandList = New-Object System.Collections.ArrayList

        # Step through the string a character at a time, bulding up the local command list
        $character = $stringReader.Read()
        while($character -ne -1) {
            if([char]$character -eq '\') {
                'n' {

                }
            }
        }
    }
}