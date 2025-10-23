# Network Troubleshooting Script - Scheduled Task Version

# Set up working directory
$workingDir = "C:\NetDiag"
if (-not (Test-Path $workingDir)) {
    New-Item -ItemType Directory -Path $workingDir | Out-Null
    Write-Host "Created working directory: $workingDir"
}

Set-Location $workingDir
Write-Host "Working directory set to: $workingDir`n"

# Identify and store the default gateway
$defaultGateway = (Get-NetRoute -DestinationPrefix "0.0.0.0/0" |
                   Where-Object {$_.NextHop -ne "0.0.0.0"} |
                   Select-Object -First 1).NextHop

Write-Host "Default Gateway: $defaultGateway"

# Run traceroute and capture the first 3 hops
Write-Host "`nRunning traceroute..."
$traceResult = Test-NetConnection -ComputerName "8.8.8.8" -TraceRoute

$hop1 = $traceResult.TraceRoute[0]
$hop2 = $traceResult.TraceRoute[1]
$hop3 = $traceResult.TraceRoute[2]

Write-Host "Hop 1: $hop1"
Write-Host "Hop 2: $hop2"
Write-Host "Hop 3: $hop3"

# Define ping targets
$pingTargets = @(
    @{Name="Gateway"; Address=$defaultGateway},
    @{Name="Hop1"; Address=$hop1},
    @{Name="Hop2"; Address=$hop2},
    @{Name="Hop3"; Address=$hop3},
    @{Name="Google"; Address="google.com"},
    @{Name="Cloudflare"; Address="cloudflare.com"}
)

Write-Host "`nCreating scheduled tasks for continuous pings (10 minute duration)..."

# Create scheduled tasks for each target
foreach ($target in $pingTargets) {
    $taskName = "NetDiag_Ping_$($target.Name)"

    # Create the script that will run
    $pingScript = @"
Start-Transcript -Path C:\NetDiag\$($target.Address).txt -Append
Write-Host 'Pinging $($target.Name) - $($target.Address)'
Ping.exe -t $($target.Address) | Where-Object {`$_ -match 'Reply from|Request timed out|Destination host unreachable'} | ForEach-Object {'{0} - {1}' -f (Get-Date),`$_}
Stop-Transcript
"@

    # Define the action
    $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-WindowStyle Hidden -ExecutionPolicy Bypass -Command `"$pingScript`""

    # Define the trigger (run immediately)
    $trigger = New-ScheduledTaskTrigger -Once -At (Get-Date)

    # Define settings
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -ExecutionTimeLimit (New-TimeSpan -Days 1)

    # Register the task to run as SYSTEM
    $principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -RunLevel Highest

    # Remove existing task if it exists
    $existingTask = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
    if ($existingTask) {
        Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
    }

    # Register the new task
    Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Settings $settings -Principal $principal | Out-Null

    # Start the task immediately
    Start-ScheduledTask -TaskName $taskName

    Write-Host "Created and started task: $taskName"
}

Write-Host "`nAll scheduled tasks created and started. They will run for 10 minutes."
Write-Host "Check C:\NetDiag\ for transcripts."
Write-Host "Use 'Get-ScheduledTask -TaskName NetDiag_*' to view tasks."
Write-Host "Tasks will auto-complete after 10 minutes."
