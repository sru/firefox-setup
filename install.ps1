# Find out OS architecture.
# `[Environment]::Is64BitOperatingSystem` works for newer PowerShell. :'(
If ((Get-WmiObject Win32_OperatingSystem).OSArchitecture -eq '64-bit') {
	$os = 'win64'
}
else {
	$os = 'win'
}

$webClient = New-Object System.Net.WebClient

# Download Firefox.
$installerUrl = "https://download.mozilla.org/?product=firefox-latest&os=${os}&lang=en-US"
$installerPath = "${env:TEMP}\firefox-setup.exe"
$webClient.DownloadFile($installerUrl, $installerPath)
Write-Output 'Downloaded Firefox setup.'

# Install Firefox.
# `/S` for silent installation (no GUI).
$installerProc = Start-Process -FilePath $installerPath -ArgumentList @('/S') -PassThru
$installerProc.WaitForExit()
Write-Output 'Installed Firefox.'

$firefoxRoot = 'C:\Program Files\Mozilla Firefox'

# Enable AutoConfig.
# $autoConfigUrl = 'https://raw.githubusercontent.com/sru/install-firefox/master/autoconfig.js'
# $autoConfigPath = "${firefoxRoot}\defaults\pref\autoconfig.js"
# $webClient.DownloadFile($autoConfigUrl, $autoConfigPath)
# Write-Output 'Enabled AutoConfig.'

# Download configuration.
# $configUrl = 'https://raw.githubusercontent.com/sru/install-firefox/master/config.js'
# $configPath = "${firefoxRoot}\config.js"
# $webClient.DownloadFile($configUrl, $configPath)
# Write-Output 'Downloaded configuration.'

$distributionPath = "${firefoxRoot}\distribution"
# Ensure the path exists.
New-Item -Path $distributionPath -ItemType Directory -ErrorAction SilentlyContinue | Out-Null

# Create policies.json file.
$policiesJson = @'
{
	"policies": {
		"DisableMasterPasswordCreation": true
	}
}
'@
Set-Content `
	-Path "${distributionPath}\policies.json"
	-Encoding ASCII
	-Value $policiesJson
Write-Output 'Created policies.json file.'

# Download addons.

$addons = @(
	@{
		Name = 'ublock-origin';
		AccountId = '11423598';
		AddonId = 'uBlock0@raymondhill.net'
	},
	@{
		Name = 'https-everywhere';
		AccountId = '5474073';
		AddonId = 'https-everywhere@eff.org'
	}
)

$addonUrl = 'https://addons.mozilla.org/en-US/firefox/addon/{0}/'

# The latest addon URL is found on https://stackoverflow.com/a/55593381.
# {0} is the addon name, the last part of the path of URL to the addon page.
# {1} is the account ID, the last part of the path of the URL on user link on the addon page.
$addonDownloadUrl = 'https://addons.mozilla.org/firefox/downloads/latest/{0}/addon-{1}-latest.xpi'

# https://developer.mozilla.org/en-US/docs/Mozilla/Add-ons/WebExtensions/Distribution_options/Sideloading_add-ons
# https://support.mozilla.org/en-US/kb/deploying-firefox-with-extensions
# Sideloading addons is disabled from version 74 and on.
$addonPath = "${distributionPath}\extensions"

# Ensure the addon path exists.
New-Item -Path $addonPath -ItemType Directory -ErrorAction SilentlyContinue | Out-Null

ForEach ($addon in $addons) {
	Write-Output "Downloading addon `"$($addonUrl -f $addon.Name)`"."
	$webClient.DownloadFile(
		($addonDownloadUrl -f $addon.Name, $addon.AccountId),
		"${addonPath}\$($addon.AddonId).xpi"
	)
}

Write-Output 'Downloaded addons.'

# Start Firefox.
Start-Process "${firefoxRoot}\firefox.exe"
Write-Output 'Started Firefox.'

Write-Output 'Done! Enjoy.'

# Close IE.
(Get-Process iexplore) | ForEach-Object { $_.CloseMainWindow() }

# Close the parent CMD window.
$parentProcessId = (Get-WmiObject -Class Win32_Process -Filter "ProcessId = '$PID'").ParentProcessId
$parentProcess = Get-Process -Id $parentProcessId
If ($parentProcess.ProcessName -match 'cmd|powershell') {
	$parentprocess.CloseMainWindow()
}
