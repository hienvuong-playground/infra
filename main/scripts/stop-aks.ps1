param(
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroup,

    [Parameter(Mandatory=$true)]
    [string]$ClusterName
)

Write-Output "Connecting to Azure..."
Connect-AzAccount -Identity

Write-Output "Checking current state of cluster '$ClusterName'..."
$cluster = Get-AzAksCluster -ResourceGroupName $ResourceGroup -Name $ClusterName

if ($cluster.PowerState.Code -ne "Running") {
    Write-Output "Cluster '$ClusterName' is not currently running (state: $($cluster.PowerState.Code)). Skipping stop."
    exit 0
}

Write-Output "Stopping AKS cluster '$ClusterName' in resource group '$ResourceGroup'..."

try {
    Stop-AzAksCluster -ResourceGroupName $ResourceGroup -Name $ClusterName -ErrorAction Stop
    Write-Output "Success: cluster '$ClusterName' stop command completed."
}
catch {
    Write-Error "Failed to stop cluster '$ClusterName': $_"
    throw
}