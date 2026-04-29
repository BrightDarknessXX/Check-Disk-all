# chkdskA - AI Agent Instructions

## Project Overview
**chkdskA** is a Windows batch script utility that automates disk checking across all system drives and generates timestamped log files. It wraps the native `chkdsk` command with a user-friendly interface and persistent logging.

## Architecture & Core Flow

The script operates in these sequential phases:

1. **Permission Validation**: Checks for elevated privileges; auto-escalates via UAC if needed (detects Windows Terminal vs. standard cmd)
2. **Initialization**: Sets working directory to `%tmp%`, initializes counters for volume tracking
3. **Volume Discovery**: Uses PowerShell to query `Win32_LogicalDisk` and extracts all drive letters
4. **Batch Processing**: Iterates through each volume, runs `chkdsk`, captures output and exit codes
5. **Log Assembly**: Combines volume list, results, and chkdsk output into final timestamped file
6. **Cleanup**: Removes temporary working files, displays summary

## Key Technical Patterns

### Delayed Expansion
- **Use**: `setlocal EnableDelayedExpansion` at line 8 is critical for all loop operations
- **Pattern**: Always wrap loop variables in `!variable!` (not `%variable%`) to access updated values
- **Example**: Volume counter `!currentvolume!` must use `!` syntax within the main loop

### Cross-Technology Execution
- **PowerShell Integration**: Script shells out to PowerShell for:
  - WMI queries (`Get-CimInstance Win32_LogicalDisk`)
  - Timestamp generation (`Get-Date -Format`)
  - File listing and sorting (`gci` with filters)
  - UAC escalation detection and invocation
- **Pattern**: Always redirect output to files or pipes; use `find` command for filtering rather than PowerShell's `Where-Object` in direct command substitution
- **Error Handling**: PowerShell return codes flow through batch via `!errorLevel!`

### Parameter-Driven Behavior
Command-line flags control execution mode (not flags during main run):
- `-help`: Display usage guide
- `-log`: Show existing logs and their location
- `-cleanup`: Remove temp files manually
- `-clear [-q]`: Delete all chkdskA*.txt logs (with optional quiet mode)
- `-select`: Select specific volumes to check

**Pattern**: Parameter handling happens early via series of `if /i` blocks; each flag exits with `/b` to prevent further execution.

### File Management Convention
All temporary and output files use the `chkdskA` prefix in `%tmp%`:
- `chkdskA_Devices` - Volume list (intermediate)
- `chkdskA_Result` - Raw chkdsk output (intermediate)
- `chkdskA_VolumeErrors` - Volume names + error codes (intermediate)
- `tmpchkdskA_DevicesSelect` - User-selected volumes (persists across UAC escalation)
- `chkdskAlog_[timestamp].txt` - Final consolidated log (persistent)

**Pattern**: Delete temp files post-execution via `:cleanup` subroutine — the cleanup uses `chkdskA*` wildcard pattern, so any file in `%tmp%` starting with "chkdskA" will be removed.

## Execution Flow for Modifications

When modifying this script:
1. **Permission checks** (lines 83-86) must always precede main logic—users without admin can't check disks
2. **Variable initialization** (lines 10-13) must be set before any loop that references them
3. **Timestamp generation** (`:get_timestamp` subroutine, ~line 160) should be called early for logging
4. **Volume loop** (lines 103-117) is the performance bottleneck—each iteration spawns `chkdsk` and PowerShell calls
5. **Final assembly** (lines 119-125) concatenates intermediate files; order matters for readability

## Common Patterns to Reuse

- **Subroutine invocation**: `call :subroutine_name` with `goto :eof` for returns (see `:get_timestamp`, `:cleanup`)
- **User confirmation**: Use `set /p` with case-insensitive validation (`if /i "!variable!"=="expected"`)
- **Error state check**: `if !errorLevel! NEQ 0` for detecting failures
- **Directory existence**: `if exist "!path!\file"` before delete operations

## Testing & Validation Points

- Run with `-help` to verify parameter system works
- Run with `-log` to confirm timestamp format is correct (expected: `YYYY.MM.DD.HH.MM.SS`)
- Run main script in non-elevated cmd first to verify UAC escalation triggers correctly
- Verify temp files are cleaned up in `%tmp%` after script completes
- Check final log file for all discovered volumes with their error codes

## Dependencies & Environment

- **Windows Only**: Batch script; requires Windows 10+ for PowerShell WMI support
- **Privileges**: Disk checking requires admin/elevated cmd
- **PowerShell**: Used for WMI queries and date formatting; must be available in PATH
- **chkdsk**: Native Windows utility; scans disk and returns per-volume exit codes

## Known Limitations & Notes

- Log files are permanently stored in `%tmp%` until manually cleared via `-clear` flag
- `chkdsk` requires full disk access; results may be limited if volumes are in use
- Script does not schedule checking for next restart (future enhancement opportunity)
- The `:cleanup` subroutine uses `chkdskA*` wildcard — will delete ANY file in `%tmp%` starting with "chkdskA"
- UAC escalation detects Windows Terminal (`wt.exe`) vs standard `cmd` for proper elevation method
