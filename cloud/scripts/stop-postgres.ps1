param(
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroup,

    [Parameter(Mandatory=$true)]
    [string]$ServerName
)

$ErrorActionPreference = "Stop"

Write-Output "Connecting to Azure..."
Connect-AzAccount -Identity

Write-Output "Checking current state of server '$ServerName'..."
$server = Get-AzPostgreSqlFlexibleServer -ResourceGroupName $ResourceGroup -Name $ServerName

if ($server.State -ne "Ready") {
    Write-Output "Server '$ServerName' is not currently running (state: $($server.State)). Skipping stop."
    exit 0
}

Write-Output "Stopping PostgreSQL server '$ServerName' in resource group '$ResourceGroup'..."

try {
    Stop-AzPostgreSqlFlexibleServer -ResourceGroupName $ResourceGroup -Name $ServerName
    Write-Output "Success: server '$ServerName' stop command completed."
}
catch {
    Write-Error "Failed to stop server '$ServerName': $_"
    throw
}
