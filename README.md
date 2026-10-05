# PowerShell Transcript Management

A reusable PowerShell 7 profile-based transcript workflow.

The setup centralizes transcript startup and control in
`Microsoft.PowerShell_profile.ps1`.

## Features

- Prompts whether to start a transcript when an interactive PowerShell
  session starts.
- Uses a configurable transcript directory and filename prefix.
- `StartTranscript` starts a transcript interactively.
- `StopAndSaveTranscript` stops the transcript, then offers Rename/Delete/Keep
  while leaving the PowerShell session running.
- `SaveTranscriptExitPS` performs the same interactive cleanup and then exits.
- A `PowerShell.Exiting` event provides non-interactive fallback cleanup.
- The shutdown handler deliberately does **not** use `Read-Host`.
- The design keeps transcript startup in one central place: the profile.

## Files

```text
PowerShell-Transcript/
├── README.md
├── Microsoft.PowerShell_profile.ps1
└── .gitignore
```

## Installation

Find the profile used by the current PowerShell host:

```powershell
$PROFILE.CurrentUserCurrentHost
```

Create its parent directory if necessary:

```powershell
$profileDirectory = Split-Path -Parent $PROFILE.CurrentUserCurrentHost
New-Item -ItemType Directory -Path $profileDirectory -Force
```

Open the profile:

```powershell
notepad $PROFILE.CurrentUserCurrentHost
```

Copy the supplied `Microsoft.PowerShell_profile.ps1` into the profile, or
merge its transcript section into an existing profile.

Do not overwrite an existing profile blindly if it already contains other
configuration.

## Configuration

The template deliberately avoids user-specific paths:

```powershell
$Global:autoPath = Join-Path $HOME 'PowerShellTranscripts'
$Global:autoFileNamePrefix = 'PowerShellTranscript'
```

`$HOME` refers to the current user's home directory, so the default transcript
directory becomes:

```text
<current-user-home>\PowerShellTranscripts
```

You can change it to any directory appropriate for your environment.

For example:

```powershell
$Global:autoPath = Join-Path $HOME 'Documents\PowerShell\Transcripts'
```

or:

```powershell
$Global:autoPath = 'D:\PowerShell\Transcripts'
```

You can also change the default filename prefix:

```powershell
$Global:autoFileNamePrefix = 'MyPowerShellSession'
```

The template creates the configured directory if it does not already exist.

## Automatic startup

At the end of the profile:

```powershell
StartTranscript
```

is called automatically.

When PowerShell starts, the user is asked:

```text
Do you want to start the transcript? (<Yes>/No)
```

Press Enter or enter `Yes` to start the transcript.

Enter `No` to continue without a transcript.

The user can also run:

```powershell
StartTranscript
```

later in the session.

## `StartTranscript`

`StartTranscript`:

1. Checks whether a transcript is already active.
2. Prompts whether to start one.
3. Allows the filename prefix to be changed for the session.
4. Calls PowerShell's native `Start-Transcript`.
5. Stores the active transcript path so that the other functions can manage it.

The actual transcript file naming and timestamp handling are provided by
PowerShell's `Start-Transcript`.

## `StopAndSaveTranscript`

Use:

```powershell
StopAndSaveTranscript
```

when you want to finish the transcript but keep the PowerShell session open.

The workflow is:

```text
Stop transcript
      ↓
Show saved transcript
      ↓
Rename / Delete / Keep
      ↓
Remain in PowerShell
```

The function asks:

```text
Enter R to rename, D to delete, or press Enter to keep
```

### Rename

Enter:

```text
R
```

and provide the new filename.

### Delete

Enter:

```text
D
```

and confirm the deletion.

### Keep

Press Enter.

The transcript remains at its current filename.

## `SaveTranscriptExitPS`

Use:

```powershell
SaveTranscriptExitPS
```

when you want to finish the transcript and then leave PowerShell.

The workflow is:

```text
Stop transcript
      ↓
Rename / Delete / Keep
      ↓
Exit PowerShell
```

This is the preferred command when you want an interactive Rename/Delete
decision before exiting.

## What happens with `exit`?

You can still type:

```powershell
exit
```

However, the normal `exit` path is already in the PowerShell shutdown
sequence, so an interactive Rename/Delete prompt is not appropriate there.

The profile therefore registers:

```powershell
PowerShell.Exiting
```

The event handler performs only non-interactive cleanup:

```text
PowerShell.Exiting
      │
      └── Stop active transcript
```

It does **not** call `Read-Host`.

Therefore:

| Command / event | Stops transcript | Rename/Delete prompt | Exits |
|---|---:|---:|---:|
| `StopAndSaveTranscript` | Yes | Yes | No |
| `SaveTranscriptExitPS` | Yes | Yes | Yes |
| `exit` | Yes, via shutdown handler | No | Yes |
| PowerShell shutdown event | Yes | No | Yes |

If you want the interactive Rename/Delete workflow, use:

```powershell
SaveTranscriptExitPS
```

instead of:

```powershell
exit
```

## Transcript and PSReadLine history are different

A transcript and PSReadLine history serve different purposes.

### PowerShell transcript

Created with:

```powershell
Start-Transcript
```

A transcript records the interactive session, including commands and the
output/error information displayed during the session.

It is useful as a session record, troubleshooting record, and learning
archive.

### PSReadLine history

PSReadLine maintains command history separately.

View its configured persistent history file with:

```powershell
(Get-PSReadLineOption).HistorySavePath
```

The exact path depends on the user's PowerShell and PSReadLine configuration.

Conceptually:

```text
Transcript
    └── session record
        commands + displayed output/errors

PSReadLine history
    └── commands entered
        persistent command history
```

Do not treat the transcript and PSReadLine history file as interchangeable.

## Why the profile is the central owner

Transcript startup should have one clear owner.

A clean design is:

```text
PowerShell starts
      ↓
Microsoft.PowerShell_profile.ps1
      ↓
StartTranscript
      ↓
Transcript session
```

Avoid starting the same transcript logic independently from multiple startup
mechanisms. Otherwise a single PowerShell session can accidentally execute the
startup prompt more than once.

## Important shutdown design

The profile intentionally separates **interactive cleanup** from
**shutdown cleanup**.

Interactive functions can use:

```powershell
Read-Host
```

because the user is still interacting with PowerShell.

The `PowerShell.Exiting` event must remain non-interactive because PowerShell
is already shutting down.

This distinction is important:

```text
Interactive command
    ↓
Read-Host is appropriate
    ↓
Rename / Delete / Keep

PowerShell.Exiting
    ↓
No Read-Host
    ↓
Best-effort cleanup only
```

## Troubleshooting

Check the active profile:

```powershell
$PROFILE.CurrentUserCurrentHost
```

Check whether the profile exists:

```powershell
Test-Path $PROFILE.CurrentUserCurrentHost
```

Open the profile:

```powershell
notepad $PROFILE.CurrentUserCurrentHost
```

Check the transcript directory:

```powershell
$Global:autoPath
```

Check whether the directory exists:

```powershell
Test-Path $Global:autoPath
```

Check whether the current session has an active transcript:

```powershell
$Global:TranscriptSessionActive
```

Check the current transcript path:

```powershell
$Global:TranscriptPath
```

Check the PSReadLine history path:

```powershell
(Get-PSReadLineOption).HistorySavePath
```

## Privacy and security

Transcript files can contain sensitive information.

They may include:

- commands,
- file paths,
- environment information,
- error messages,
- API responses,
- accidentally displayed credentials or tokens,
- other sensitive command output.

Therefore:

- Do not commit personal transcripts to GitHub.
- Add the transcript directory to `.gitignore`.
- Review transcripts before sharing them.
- Never intentionally record passwords, access tokens, private keys, or other
  secrets.

Example `.gitignore` entry:

```gitignore
PowerShellTranscripts/
```

Adjust it if you choose a different transcript directory.

## Recommended repository structure

```text
PowerShell-Transcript/
├── README.md
├── Microsoft.PowerShell_profile.ps1
└── .gitignore
```

The supplied profile is a template. Adapt the transcript directory, filename
prefix, and any other profile settings to your environment.

## License

Choose a license appropriate for your repository. MIT is one common option for
reusable scripts and configuration.
