﻿<#
.SYNOPSIS
	This script performs the installation or uninstallation of an application(s).
	# LICENSE #
	PowerShell App Deployment Toolkit - Provides a set of functions to perform common application deployment tasks on Windows.
	Copyright (C) 2017 - Sean Lillis, Dan Cunningham, Muhammad Mashwani, Aman Motazedian.
	This program is free software: you can redistribute it and/or modify it under the terms of the GNU Lesser General Public License as published by the Free Software Foundation, either version 3 of the License, or any later version. This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
	You should have received a copy of the GNU Lesser General Public License along with this program. If not, see <http://www.gnu.org/licenses/>.
.DESCRIPTION
	The script is provided as a template to perform an install or uninstall of an application(s).
	The script either performs an "Install" deployment type or an "Uninstall" deployment type.
	The install deployment type is broken down into 3 main sections/phases: Pre-Install, Install, and Post-Install.
	The script dot-sources the AppDeployToolkitMain.ps1 script which contains the logic and functions required to install or uninstall an application.
.PARAMETER DeploymentType
	The type of deployment to perform. Default is: Install.
.PARAMETER DeployMode
	Specifies whether the installation should be run in Interactive, Silent, or NonInteractive mode. Default is: Interactive. Options: Interactive = Shows dialogs, Silent = No dialogs, NonInteractive = Very silent, i.e. no blocking apps. NonInteractive mode is automatically set if it is detected that the process is not user interactive.
.PARAMETER AllowRebootPassThru
	Allows the 3010 return code (requires restart) to be passed back to the parent process (e.g. SCCM) if detected from an installation. If 3010 is passed back to SCCM, a reboot prompt will be triggered.
.PARAMETER TerminalServerMode
	Changes to "user install mode" and back to "user execute mode" for installing/uninstalling applications for Remote Destkop Session Hosts/Citrix servers.
.PARAMETER DisableLogging
	Disables logging to file for the script. Default is: $false.
.EXAMPLE
    powershell.exe -Command "& { & '.\Deploy-Application.ps1' -DeployMode 'Silent'; Exit $LastExitCode }"
.EXAMPLE
    powershell.exe -Command "& { & '.\Deploy-Application.ps1' -AllowRebootPassThru; Exit $LastExitCode }"
.EXAMPLE
    powershell.exe -Command "& { & '.\Deploy-Application.ps1' -DeploymentType 'Uninstall'; Exit $LastExitCode }"
.EXAMPLE
    Deploy-Application.exe -DeploymentType "Install" -DeployMode "Silent"
.NOTES
	Toolkit Exit Code Ranges:
	60000 - 68999: Reserved for built-in exit codes in Deploy-Application.ps1, Deploy-Application.exe, and AppDeployToolkitMain.ps1
	69000 - 69999: Recommended for user customized exit codes in Deploy-Application.ps1
	70000 - 79999: Recommended for user customized exit codes in AppDeployToolkitExtensions.ps1
.LINK
	http://psappdeploytoolkit.com
#>
[CmdletBinding()]
## Suppress PSScriptAnalyzer errors for not using declared variables during AppVeyor build
[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseDeclaredVarsMoreThanAssignments", "", Justification="Suppresses AppVeyor errors on informational variables below")]
Param (
	[Parameter(Mandatory=$false)]
	[ValidateSet('Install','Uninstall')]
	[string]$DeploymentType = 'Install',
	[Parameter(Mandatory=$false)]
	[ValidateSet('Interactive','Silent','NonInteractive')]
	[string]$DeployMode = 'Interactive',
	[Parameter(Mandatory=$false)]
	[switch]$AllowRebootPassThru = $false,
	[Parameter(Mandatory=$false)]
	[switch]$TerminalServerMode = $false,
	[Parameter(Mandatory=$false)]
	[switch]$DisableLogging = $false
)

Try {
	## Set the script execution policy for this process
	Try { Set-ExecutionPolicy -ExecutionPolicy 'ByPass' -Scope 'Process' -Force -ErrorAction 'Stop' } Catch { Write-Error "Failed to set the execution policy to Bypass for this process." }

	##*===============================================
	##* VARIABLE DECLARATION
	##*===============================================
	## Variables: Application
	[string]$appVendor = 'Wacom'
	[string]$appName = 'Cintiq 13HD Drivers'
	[string]$appVersion = '6.3.37'
	[string]$appArch = 'x64'
	[string]$appLang = 'EN'
	[string]$appRevision = '01'
	[string]$appScriptVersion = '3.7.0.1'
	[string]$appScriptDate = '10/28/2019'
	[string]$appScriptAuthor = 'Steve Patterson'
	##*===============================================
	## Variables: Install Titles (Only set here to override defaults set by the toolkit)
	[string]$installName = ''
	[string]$installTitle = ''

	##* Do not modify section below
	#region DoNotModify

	## Variables: Exit Code
	[int32]$mainExitCode = 0

	## Variables: Script
	[string]$deployAppScriptFriendlyName = 'Deploy Application'
	[version]$deployAppScriptVersion = [version]'3.7.0'
	[string]$deployAppScriptDate = '02/13/2018'
	[hashtable]$deployAppScriptParameters = $psBoundParameters

	## Variables: Environment
	If (Test-Path -LiteralPath 'variable:HostInvocation') { $InvocationInfo = $HostInvocation } Else { $InvocationInfo = $MyInvocation }
	[string]$scriptDirectory = Split-Path -Path $InvocationInfo.MyCommand.Definition -Parent

	## Dot source the required App Deploy Toolkit Functions
	Try {
		[string]$moduleAppDeployToolkitMain = "$scriptDirectory\AppDeployToolkit\AppDeployToolkitMain.ps1"
		If (-not (Test-Path -LiteralPath $moduleAppDeployToolkitMain -PathType 'Leaf')) { Throw "Module does not exist at the specified location [$moduleAppDeployToolkitMain]." }
		If ($DisableLogging) { . $moduleAppDeployToolkitMain -DisableLogging } Else { . $moduleAppDeployToolkitMain }
	}
	Catch {
		If ($mainExitCode -eq 0){ [int32]$mainExitCode = 60008 }
		Write-Error -Message "Module [$moduleAppDeployToolkitMain] failed to load: `n$($_.Exception.Message)`n `n$($_.InvocationInfo.PositionMessage)" -ErrorAction 'Continue'
		## Exit the script, returning the exit code to SCCM
		If (Test-Path -LiteralPath 'variable:HostInvocation') { $script:ExitCode = $mainExitCode; Exit } Else { Exit $mainExitCode }
	}

	#endregion
	##* Do not modify section above
	##*===============================================
	##* END VARIABLE DECLARATION
	##*===============================================

	If ($deploymentType -ine 'Uninstall') {
		##*===============================================
		##* PRE-INSTALLATION
		##*===============================================
		[string]$installPhase = 'Pre-Installation'

		## Show Welcome Message, close Internet Explorer if needed, verify there is enough disk space to complete the install, and persist the prompt
		Show-InstallationWelcome -CloseApps 'wacomdesktopcenter' -CheckDiskSpace -PersistPrompt

		## Show Progress Message (with the default message)
		Show-InstallationProgress

		## <Perform Pre-Installation tasks here>


		##*===============================================
		##* INSTALLATION
		##*===============================================
		[string]$installPhase = 'Installation'

		## Handle Zero-Config MSI Installations
		If ($useDefaultMsi) {
			[hashtable]$ExecuteDefaultMSISplat =  @{ Action = 'Install'; Path = $defaultMsiFile }; If ($defaultMstFile) { $ExecuteDefaultMSISplat.Add('Transform', $defaultMstFile) }
			Execute-MSI @ExecuteDefaultMSISplat; If ($defaultMspFiles) { $defaultMspFiles | ForEach-Object { Execute-MSI -Action 'Patch' -Path $_ } }
		}

		## <Perform Installation tasks here>
        Execute-Process -Path "$dirFiles\WacomTablet_6.3.37-3.exe" -Parameters '/silent' -WindowStyle 'Hidden'


		##*===============================================
		##* POST-INSTALLATION
		##*===============================================
		[string]$installPhase = 'Post-Installation'

		## <Perform Post-Installation tasks here>

		## Display a message at the end of the install
		If (-not $useDefaultMsi) {

		}
	}
	ElseIf ($deploymentType -ieq 'Uninstall')
	{
		##*===============================================
		##* PRE-UNINSTALLATION
		##*===============================================
		[string]$installPhase = 'Pre-Uninstallation'

		## Show Welcome Message, close Internet Explorer with a 60 second countdown before automatically closing
		Show-InstallationWelcome -CloseApps 'wacomdesktopcenter' -CloseAppsCountdown 60

		## Show Progress Message (with the default message)
		Show-InstallationProgress

		## <Perform Pre-Uninstallation tasks here>


		##*===============================================
		##* UNINSTALLATION
		##*===============================================
		[string]$installPhase = 'Uninstallation'

		## Handle Zero-Config MSI Uninstallations
		If ($useDefaultMsi) {
			[hashtable]$ExecuteDefaultMSISplat =  @{ Action = 'Uninstall'; Path = $defaultMsiFile }; If ($defaultMstFile) { $ExecuteDefaultMSISplat.Add('Transform', $defaultMstFile) }
			Execute-MSI @ExecuteDefaultMSISplat
		}

		# <Perform Uninstallation tasks here>
        Execute-Process -Path "C:\Program Files\Tablet\Wacom\32\Remove.exe" -Parameters '/u /silent' -WindowStyle 'Hidden'

		##*===============================================
		##* POST-UNINSTALLATION
		##*===============================================
		[string]$installPhase = 'Post-Uninstallation'

		## <Perform Post-Uninstallation tasks here>


	}

	##*===============================================
	##* END SCRIPT BODY
	##*===============================================

	## Call the Exit-Script function to perform final cleanup operations
	Exit-Script -ExitCode $mainExitCode
}
Catch {
	[int32]$mainExitCode = 60001
	[string]$mainErrorMessage = "$(Resolve-Error)"
	Write-Log -Message $mainErrorMessage -Severity 3 -Source $deployAppScriptFriendlyName
	Show-DialogBox -Text $mainErrorMessage -Icon 'Stop'
	Exit-Script -ExitCode $mainExitCode
}


# SIG # Begin signature block
# MIIOaQYJKoZIhvcNAQcCoIIOWjCCDlYCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQU0qftebMwIZu0YEhw5JQ1XNhw
# T3CggguhMIIFrjCCBJagAwIBAgIQBwNx0Q95WkBxmSuUB2Kb4jANBgkqhkiG9w0B
# AQsFADB8MQswCQYDVQQGEwJVUzELMAkGA1UECBMCTUkxEjAQBgNVBAcTCUFubiBB
# cmJvcjESMBAGA1UEChMJSW50ZXJuZXQyMREwDwYDVQQLEwhJbkNvbW1vbjElMCMG
# A1UEAxMcSW5Db21tb24gUlNBIENvZGUgU2lnbmluZyBDQTAeFw0xODA2MjEwMDAw
# MDBaFw0yMTA2MjAyMzU5NTlaMIG5MQswCQYDVQQGEwJVUzEOMAwGA1UEEQwFODAy
# MDQxCzAJBgNVBAgMAkNPMQ8wDQYDVQQHDAZEZW52ZXIxGDAWBgNVBAkMDzEyMDEg
# NXRoIFN0cmVldDEwMC4GA1UECgwnTWV0cm9wb2xpdGFuIFN0YXRlIFVuaXZlcnNp
# dHkgb2YgRGVudmVyMTAwLgYDVQQDDCdNZXRyb3BvbGl0YW4gU3RhdGUgVW5pdmVy
# c2l0eSBvZiBEZW52ZXIwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQDL
# V4koxA42DQSGF7D5xRh8Gar0uZYETUmkI7MsYC7BiOsiywwqWmMtwgcDdaJ+EJ2M
# xEKbB1fkyf9yutWb6gMYUegJ8PE41Y2gd5D3bSiYxFJYIlzStJw0cjFWrGcnlwC0
# eUk0n9UsaDLfByA3dCkwfMoTBOnsxXRc8AeR3tv48jrMH2LDfp+JNkPVHGlbVoAs
# 1rmt/Wp8Db2uzOBroDzuWZBel5Kxs0R6V3LVfxZOi5qj2OrEZuOZ0nJwtSkNzTf7
# emQR85gLYG2WuNaOfgLzXZL/U1RektzgxqX96ilvJIxbfNiy2HWYtFdO5Z/kvwbQ
# JRlDzr6npuBJGzLWeTNzAgMBAAGjggHsMIIB6DAfBgNVHSMEGDAWgBSuNSMX//8G
# PZxQ4IwkZTMecBCIojAdBgNVHQ4EFgQUpemIbrz5SKX18ziKvmP5pAxjmw8wDgYD
# VR0PAQH/BAQDAgeAMAwGA1UdEwEB/wQCMAAwEwYDVR0lBAwwCgYIKwYBBQUHAwMw
# EQYJYIZIAYb4QgEBBAQDAgQQMGYGA1UdIARfMF0wWwYMKwYBBAGuIwEEAwIBMEsw
# SQYIKwYBBQUHAgEWPWh0dHBzOi8vd3d3LmluY29tbW9uLm9yZy9jZXJ0L3JlcG9z
# aXRvcnkvY3BzX2NvZGVfc2lnbmluZy5wZGYwSQYDVR0fBEIwQDA+oDygOoY4aHR0
# cDovL2NybC5pbmNvbW1vbi1yc2Eub3JnL0luQ29tbW9uUlNBQ29kZVNpZ25pbmdD
# QS5jcmwwfgYIKwYBBQUHAQEEcjBwMEQGCCsGAQUFBzAChjhodHRwOi8vY3J0Lmlu
# Y29tbW9uLXJzYS5vcmcvSW5Db21tb25SU0FDb2RlU2lnbmluZ0NBLmNydDAoBggr
# BgEFBQcwAYYcaHR0cDovL29jc3AuaW5jb21tb24tcnNhLm9yZzAtBgNVHREEJjAk
# gSJpdHNzeXN0ZW1lbmdpbmVlcmluZ0Btc3VkZW52ZXIuZWR1MA0GCSqGSIb3DQEB
# CwUAA4IBAQCHNj1auwWplgLo8gkDx7Bgg2zN4tTmOZ67gP3zrWyepib0/VCWOPut
# YK3By81e6KdctJ0YVeOfU6ynxyjuNrkcmaXZx2jqAtPNHH4P9BMBSUct22AdL5FT
# /E3lJL1IW7XD1aHyNT/8IfWU9omFQnqzjgKor8VqofA7fvKEm40hoTxVsrtOG/FH
# M2yv/e7l3YCtMzXFwyVIzCq+gm3r3y0C30IhT4s2no/tn70f42RwL8TvVtq4Xejc
# OoBbNqtz+AhStPsgJBQi5PvcLKfkbEb0ZL3ViafmpzbwCjslXwo+rM+XUDwCGCMi
# 4cvc3t7WlSpvfQ0EGVf8DfwEzw37SxptMIIF6zCCA9OgAwIBAgIQZeHi49XeUEWF
# 8yYkgAXi1DANBgkqhkiG9w0BAQ0FADCBiDELMAkGA1UEBhMCVVMxEzARBgNVBAgT
# Ck5ldyBKZXJzZXkxFDASBgNVBAcTC0plcnNleSBDaXR5MR4wHAYDVQQKExVUaGUg
# VVNFUlRSVVNUIE5ldHdvcmsxLjAsBgNVBAMTJVVTRVJUcnVzdCBSU0EgQ2VydGlm
# aWNhdGlvbiBBdXRob3JpdHkwHhcNMTQwOTE5MDAwMDAwWhcNMjQwOTE4MjM1OTU5
# WjB8MQswCQYDVQQGEwJVUzELMAkGA1UECBMCTUkxEjAQBgNVBAcTCUFubiBBcmJv
# cjESMBAGA1UEChMJSW50ZXJuZXQyMREwDwYDVQQLEwhJbkNvbW1vbjElMCMGA1UE
# AxMcSW5Db21tb24gUlNBIENvZGUgU2lnbmluZyBDQTCCASIwDQYJKoZIhvcNAQEB
# BQADggEPADCCAQoCggEBAMCgL4seertqdaz4PtyjujkiyvOjduS/fTAn5rrTmDJW
# I1wGhpcNgOjtooE16wv2Xn6pPmhz/Z3UZ3nOqupotxnbHHY6WYddXpnHobK4qYRz
# DMyrh0YcasfvOSW+p93aLDVwNh0iLiA73eMcDj80n+V9/lWAWwZ8gleEVfM4+/IM
# Nqm5XrLFgUcjfRKBoMABKD4D+TiXo60C8gJo/dUBq/XVUU1Q0xciRuVzGOA65Dd3
# UciefVKKT4DcJrnATMr8UfoQCRF6VypzxOAhKmzCVL0cPoP4W6ks8frbeM/ZiZpt
# o/8Npz9+TFYj1gm+4aUdiwfFv+PfWKrvpK+CywX4CgkCAwEAAaOCAVowggFWMB8G
# A1UdIwQYMBaAFFN5v1qqK0rPVIDh2JvAnfKyA2bLMB0GA1UdDgQWBBSuNSMX//8G
# PZxQ4IwkZTMecBCIojAOBgNVHQ8BAf8EBAMCAYYwEgYDVR0TAQH/BAgwBgEB/wIB
# ADATBgNVHSUEDDAKBggrBgEFBQcDAzARBgNVHSAECjAIMAYGBFUdIAAwUAYDVR0f
# BEkwRzBFoEOgQYY/aHR0cDovL2NybC51c2VydHJ1c3QuY29tL1VTRVJUcnVzdFJT
# QUNlcnRpZmljYXRpb25BdXRob3JpdHkuY3JsMHYGCCsGAQUFBwEBBGowaDA/Bggr
# BgEFBQcwAoYzaHR0cDovL2NydC51c2VydHJ1c3QuY29tL1VTRVJUcnVzdFJTQUFk
# ZFRydXN0Q0EuY3J0MCUGCCsGAQUFBzABhhlodHRwOi8vb2NzcC51c2VydHJ1c3Qu
# Y29tMA0GCSqGSIb3DQEBDQUAA4ICAQBGLLZ/ak4lZr2caqaq0J69D65ONfzwOCfB
# x50EyYI024bhE/fBlo0wRBPSNe1591dck6YSV22reZfBJmTfyVzLwzaibZMjoduq
# MAJr6rjAhdaSokFsrgw5ZcUfTBAqesReMJx9THLOFnizq0D8vguZFhOYIP+yunPR
# tVTcC5Jf6aPTkT5Y8SinhYT4Pfk4tycxyMVuy3cpY333HForjRUedfwSRwGSKlA8
# Ny7K3WFs4IOMdOrYDLzhH9JyE3paRU8albzLSYZzn2W6XV2UOaNU7KcX0xFTkALK
# dOR1DQl8oc55VS69CWjZDO3nYJOfc5nU20hnTKvGbbrulcq4rzpTEj1pmsuTI78E
# 87jaK28Ab9Ay/u3MmQaezWGaLvg6BndZRWTdI1OSLECoJt/tNKZ5yeu3K3RcH8//
# G6tzIU4ijlhG9OBU9zmVafo872goR1i0PIGwjkYApWmatR92qiOyXkZFhBBKek7+
# FgFbK/4uy6F1O9oDm/AgMzxasCOBMXHa8adCODl2xAh5Q6lOLEyJ6sJTMKH5sXju
# LveNfeqiKiUJfvEspJdOlZLajLsfOCMN2UCx9PCfC2iflg1MnHODo2OtSOxRsQg5
# G0kH956V3kRZtCAZ/Bolvk0Q5OidlyRS1hLVWZoW6BZQS6FJah1AirtEDoVP/gBD
# qp2PfI9s0TGCAjIwggIuAgEBMIGQMHwxCzAJBgNVBAYTAlVTMQswCQYDVQQIEwJN
# STESMBAGA1UEBxMJQW5uIEFyYm9yMRIwEAYDVQQKEwlJbnRlcm5ldDIxETAPBgNV
# BAsTCEluQ29tbW9uMSUwIwYDVQQDExxJbkNvbW1vbiBSU0EgQ29kZSBTaWduaW5n
# IENBAhAHA3HRD3laQHGZK5QHYpviMAkGBSsOAwIaBQCgeDAYBgorBgEEAYI3AgEM
# MQowCKACgAChAoAAMBkGCSqGSIb3DQEJAzEMBgorBgEEAYI3AgEEMBwGCisGAQQB
# gjcCAQsxDjAMBgorBgEEAYI3AgEVMCMGCSqGSIb3DQEJBDEWBBQxCjh90vBoPPdg
# r5zg1kPcezdYOTANBgkqhkiG9w0BAQEFAASCAQCTRLcHS7ju6lYtnoufnutDwhjA
# T/Ct2x4btI6VYaZJz0Hz67hpOS3BF5ct7+E1lTJYVwTKRVqEmoIFhGyrIe2bKwBG
# ifc71lM4RBPEB41JmioR57KFRn/tffMucdswvqiD5KuapxV0/pBYIz0o1akFlK19
# vduyU85szacJqclwsUrod8x2Mp8+P7JkUgrX//th03UFlD7hDI4ajJyS0WwrzcCA
# uKewP76iBXOBn4iD8FxciX1iN3DrciBQ3SnGDXLoJV02PjoTMSt0EHRtZZbbM34Y
# r1tbycM3m+IyMW1/5HluiWwCslAvNb19ygZcAQxoOH2FIYBUisIeJOy2fBO8
# SIG # End signature block
