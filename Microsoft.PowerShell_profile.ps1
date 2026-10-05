#requires -Version 7.0

# ============================================================================
# PowerShell Transcript Configuration
# ============================================================================

# Customize these two values for your environment.
$Global:autoPath = Join-Path $HOME 'PowerShellTranscripts'
$Global:autoFileNamePrefix = 'PowerShellTranscript'

if (-not (Test-Path -LiteralPath $Global:autoPath)) {
    New-Item -ItemType Directory -Path $Global:autoPath -Force | Out-Null
}

# ============================================================================
# Transcript helper
# ============================================================================

function Complete-TranscriptFile {
    param(
        [Parameter(Mandatory)]
        [string]$TranscriptPath
    )

    if (-not (Test-Path -LiteralPath $TranscriptPath)) {
        return
    }

    Write-Host ""
    Write-Host "Transcript saved:" -ForegroundColor Green
    Write-Host $TranscriptPath -ForegroundColor Cyan
    Write-Host ""

    $action = Read-Host "Enter R to rename, D to delete, or press Enter to keep"

    switch ($action.Trim().ToUpperInvariant()) {
        'R' {
            do {
                $newName = Read-Host "Enter the new filename (without path)"
                if ([string]::IsNullOrWhiteSpace($newName)) {
                    Write-Host "Filename cannot be empty." -ForegroundColor Yellow
                    continue
                }

                if ($newName.IndexOfAny([IO.Path]::GetInvalidFileNameChars()) -ge 0) {
                    Write-Host "The filename contains invalid characters." -ForegroundColor Yellow
                    $newName = $null
                }
            } while ([string]::IsNullOrWhiteSpace($newName))

            $newPath = Join-Path (Split-Path -Parent $TranscriptPath) $newName

            if (Test-Path -LiteralPath $newPath) {
                $overwrite = Read-Host "File already exists. Overwrite? (y/N)"
                if ($overwrite.Trim().ToUpperInvariant() -ne 'Y') {
                    Write-Host "Rename cancelled." -ForegroundColor Yellow
                    return
                }
            }

            try {
                Move-Item -LiteralPath $TranscriptPath -Destination $newPath -Force
                Write-Host "Transcript renamed to:" -ForegroundColor Green
                Write-Host $newPath -ForegroundColor Cyan
            }
            catch {
                Write-Host "Could not rename transcript: $($_.Exception.Message)" -ForegroundColor Red
            }
        }

        'D' {
            $confirm = Read-Host "Delete this transcript? (y/N)"
            if ($confirm.Trim().ToUpperInvariant() -eq 'Y') {
                try {
                    Remove-Item -LiteralPath $TranscriptPath -Force
                    Write-Host "Transcript deleted." -ForegroundColor Yellow
                }
                catch {
                    Write-Host "Could not delete transcript: $($_.Exception.Message)" -ForegroundColor Red
                }
            }
        }

        default {
            Write-Host "Transcript kept." -ForegroundColor Green
        }
    }
}

# ============================================================================
# StartTranscript
# ============================================================================

function StartTranscript {
    if ($Global:TranscriptSessionActive) {
        Write-Host "A transcript is already active." -ForegroundColor Yellow
        return
    }

    Write-Host ""
    $answer = Read-Host "Do you want to start the transcript? (<Yes>/No)"

    if ($answer.Trim() -and $answer.Trim() -notmatch '^(?i:y|yes)$') {
        Write-Host "Transcript not started." -ForegroundColor Yellow
        return
    }

    $prefix = Read-Host "Enter transcript filename prefix (press Enter for '$Global:autoFileNamePrefix')"
    if (-not [string]::IsNullOrWhiteSpace($prefix)) {
        $Global:autoFileNamePrefix = $prefix.Trim()
    }

    try {
        $result = Start-Transcript `
            -Path $Global:autoPath `
            -FileNamePrefix $Global:autoFileNamePrefix `
            -ErrorAction Stop

        $Global:TranscriptSessionActive = $true
        $Global:TranscriptPath = $result.Path
    }
    catch {
        $Global:TranscriptSessionActive = $false
        $Global:TranscriptPath = $null
        Write-Host "Unable to start transcript: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# ============================================================================
# StopAndSaveTranscript
# ============================================================================

function StopAndSaveTranscript {
    if (-not $Global:TranscriptSessionActive) {
        Write-Host "No transcript is currently active." -ForegroundColor Yellow
        return
    }

    $transcriptPath = $Global:TranscriptPath

    try {
        Stop-Transcript -ErrorAction Stop | Out-Null
    }
    catch {
        Write-Host "Unable to stop transcript: $($_.Exception.Message)" -ForegroundColor Red
    }
    finally {
        $Global:TranscriptSessionActive = $false
        $Global:TranscriptPath = $null
    }

    # PSReadLine normally persists command history automatically according
    # to its HistorySaveStyle/HistorySavePath settings.
    Complete-TranscriptFile -TranscriptPath $transcriptPath
}

# ============================================================================
# SaveTranscriptExitPS
# ============================================================================

function SaveTranscriptExitPS {
    StopAndSaveTranscript
    exit
}

# ============================================================================
# PowerShell.Exiting
#
# This handler must remain NON-INTERACTIVE. Do not use Read-Host here.
# It exists only as a fallback for normal PowerShell shutdown.
# ============================================================================

if (-not $Global:TranscriptExitEventRegistered) {
    $Global:TranscriptExitEventRegistered = $true

    Register-EngineEvent -SourceIdentifier PowerShell.Exiting -Action {
        try {
            if ($Global:TranscriptSessionActive) {
                Stop-Transcript -ErrorAction SilentlyContinue | Out-Null
                $Global:TranscriptSessionActive = $false
                $Global:TranscriptPath = $null
            }
        }
        catch {
            # Never interfere with PowerShell shutdown.
        }
    } | Out-Null
}

# ============================================================================
# Start transcript prompt automatically for each interactive session.
# ============================================================================

StartTranscript
