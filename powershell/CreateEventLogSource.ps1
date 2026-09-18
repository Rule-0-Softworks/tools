# Script to register event log source
param
(
    [Parameter(Mandatory = $true)][string]$Source
)

# Initialize the default script exit code.
$exitCode = 1

# Required for newer versions of PowerShell Core to be anble to have Windows-Specific behavior necessary to create the log source
Import-Module Microsoft.PowerShell.Management -UseWindowsPowerShell -WarningAction Ignore

# Output Execution Parameters
"Executing With the following parameters:"
"    Source: $Source"

# Create log source if does not exist
if (!([System.Diagnostics.EventLog]::SourceExists($Source))) {
    New-EventLog -LogName Application -Source $Source
    "Log source: $Source was created."
} else {
    "Log source: $Source already exists"
}