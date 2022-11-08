<#
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
Param (
	[Parameter(Mandatory = $false)]
	[ValidateSet('Install', 'Uninstall', 'Repair')]
	[string]$DeploymentType = 'Install',
	[Parameter(Mandatory = $false)]
	[ValidateSet('Interactive', 'Silent', 'NonInteractive')]
	[string]$DeployMode = 'Interactive',
	[Parameter(Mandatory = $false)]
	[switch]$AllowRebootPassThru = $false,
	[Parameter(Mandatory = $false)]
	[switch]$TerminalServerMode = $false,
	[Parameter(Mandatory = $false)]
	[switch]$DisableLogging = $false
)

Try {
	## Set the script execution policy for this process
	Try { Set-ExecutionPolicy -ExecutionPolicy 'ByPass' -Scope 'Process' -Force -ErrorAction 'Stop' } Catch {}

	##*===============================================
	##* VARIABLE DECLARATION
	##*===============================================
	##* Variables: Application
	[string]$appVendor = 'ESRI'
	[string]$appName = 'ArcGIS Pro'
	[string]$appVersion = '2.9.32739'
	[string]$appArch = 'x64'
	[string]$appLang = 'EN'
	[string]$appRevision = '01'
	[string]$appScriptVersion = '1.1.0'
	[string]$appScriptDate = '2022.06.10'
	[string]$appScriptAuthor = 'JBSMITH, KTEUTON'

	##* Variables: Install Titles (Only set here to override defaults set by the toolkit)
	[string]$installName = "$appName ($appVersion)"
	[string]$installTitle = "$appName ($appVersion)"

	##*===============================================
	##* ANCHOR: VARIABLES - Template
	##* Changeable Array(s)/Variable(s)
	##*===============================================
	# Template array(s)/variable(s) used within the PSADT.
	
	##* InstallationWelcomeCloseApps
	# Used with the PSADT 'Show-InstallationWelcome -CloseApps' function.
	# Mainly used in the Pre-Installation and Pre-Uninstallation phases.
	# This variable will tell users what needs to be closed during install/uninstall phases.
	$CloseApps = "hh=Help Window,DocDefragmenter=ArcGIS Pro,ArcGIS Document Defragmenter,MXDDoctor=MXD Doctor,pythonw=Python Windows,python=Python CMD Prompt,ArcCatalog,ArcGISAdmin=ArcGIS Adminsitrator,ArcGlobe,ArcMap,ArcScene"
    
	##* Prerequisite Application install parameters.
	# Prerequisite application 1 name.
	$PrereqApp1Name = "Microsoft ODBC Driver 17 for SQL Server"
	# Prerequisite application 1 install path.
	$PrereqApp1InstallPath = "$PSScriptRoot\Files\Microsoft ODBC Driver 17 for SQL Server.msi"
	# Prerequisite application 1 install parameters.
	$PrereqApp1InstallParam = "IACCEPTMSODBCSQLLICENSETERMS=YES REBOOT=ReallySuppress /QN"

	##* Application install parameters.
	# 64-bit application
	# 64-bit application install name.
	$64bitAppInstallName = "ArcGIS Pro"
	# Application install Path.
	$64bitAppInstallPath = "$PSScriptRoot\Files\ArcGIS Pro\ArcGISPro.msi"
	# Application  install parameters.
	$64bitAppInstallParam = "ALLUSERS=1 ENABLEEUEI=0 ACCEPTEULA=yes CHECKFORUPDATESATSTARTUP=0 REBOOT=ReallySuppress /QN" 
	# Application patch. 
	$64bitAppInstallPatch = "$PSScriptRoot\Files\ArcGIS Pro\ArcGIS_Pro_293_179947.msp"
	# Application patch parameters.
	$64bitAppInstallPatchParam = "REBOOT=ReallySuppress /QN"

	# 32-bit application
	# 32-bit application install name.
	#$32bitAppInstallName = "" 
	# Application install Path.
	#$32bitAppInstallPath = ""
	# Application install parameters.
	#$32bitAppInstallParam = ""

	##* Remove Application Names 
	# Mainly used in the Pre-Installation, Pre-Uninstallation, Uninstallation and Post-Uninstallation phases.
	# These scalable Array(s)/Variable(s) are used to remove previous application(s) by name.
	# ! Add ArcGIS Pro with next package update.
	$RemoveAppNamesMSI = @("ArcGIS VBA Compatibility", "Microsoft ODBC Driver 11 for SQL Server", "Microsoft ODBC Driver 13 for SQL Server", "Microsoft ODBC Driver 13.1 for SQL Server", "Microsoft ODBC Driver 18 for SQL Server")
	#$RemoveAppNamesEXE = @("")

	##* Application uninstall parameters.
	# 64-bit application
	# 64-bit application uninstall name.
	#$64bitAppUninstallName = ""
	# Application uninstall path.
	#$64bitAppUninstallPath = ""
	# Application uninstall parameters.
	#$64bitAppUninstallParam = ""

	# 32-bit application
	# 32-bit application uninstall name.
	#$32bitAppUninstallName = "" 
	# Application uninstall path.
	#$32bitAppUninstallPath = ""
	# Application uninstall parameters.
	#$32bitAppUninstallParam = ""
    
	##* Application Settings File Name
	# Names of files used for application settings.
	#[string[]]$appSettingsNames = @("")

	##* Application Settings Directory
	# Directory where application settings be reside.
	#[string[]]$appSettingsDirs = @("")
    
	## Set variables to match script variables
	# These Variable(s) keep the spaces the PSADT script removes. These can and are used in titles, messages, logs and the PIRK information for the application being installed.
	$apVendor = $appVendor
	$apName = $appName
	$apversion = $appVersion
	$apScriptVersion = $appScriptVersion

	##*===============================================
	##* ANCHOR: VARIABLES - Author
	##* Changeable Array(s)/Variable(s)
	##*===============================================
	# If the template array(s)/variable(s) aren't enough, add more array(s)/variable(s) here.


	
	##*===============================================
	##* Do not modify section below
	#region DoNotModify

	## Variables: Exit Code
	[int32]$mainExitCode = 0

	## Variables: Script
	[string]$deployAppScriptFriendlyName = 'Deploy Application'
	[version]$deployAppScriptVersion = [version]'3.8.3'
	[string]$deployAppScriptDate = '30/09/2020'
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
		If ($mainExitCode -eq 0) { [int32]$mainExitCode = 60008 }
		Write-Error -Message "Module [$moduleAppDeployToolkitMain] failed to load: `n$($_.Exception.Message)`n `n$($_.InvocationInfo.PositionMessage)" -ErrorAction 'Continue'
		## Exit the script, returning the exit code to SCCM
		If (Test-Path -LiteralPath 'variable:HostInvocation') { $script:ExitCode = $mainExitCode; Exit } Else { Exit $mainExitCode }
	}

	#endregion
	##* Do not modify section above
	##*===============================================
	##* END VARIABLE DECLARATION
	##*===============================================

	If ($deploymentType -ine 'Uninstall' -and $deploymentType -ine 'Repair') {
		##*===============================================
		##* ANCHOR: PRE-INSTALLATION
		##*===============================================
		[string]$installPhase = 'Pre-Installation'

		# Check if there is a pending restart.
		# If there is a pending restart, prompt the user to restart the device.
		If ((Get-PendingReboot).IsSystemRebootPending -eq $True) {
			# Show install completed prompt.
			Write-Log -Message "Showing pending restart prompt."
			Show-InstallationPrompt -Icon "Warning" -PersistPrompt -ButtonMiddleText "OK" -Title "Device Restart Needed" -Message "The changes to $apName can't be completed at this time.`n `n Please save your work and restart your device.`n `n Questions or issues? `n Please contact the IT Service Desk: `n ITServiceDesk@co.tuolumne.ca.us"		
			Write-Log -Message "Exiting script with error: pending restart."
			Exit-Script -ExitCode 69000
		}

		# Check if deployment is interactive. 
		# If yes (it is interactive), show install prompt.
		If ($DeployMode -eq "Interactive") {
			$dialog = (Show-InstallationPrompt -Icon "Information" -PersistPrompt -ButtonMiddleText "OK" -Message "Changes are going to be made to your device. `n `n Please save your work and close all windows. `n `n To defer the changes, click the defer button on the next screen.")
		}

		# Check if user accepted the install prompt.
		# If yes (it was accepted), show close application(s) prompt. Do not allow application(s) to start during install. 
		If ($dialog -eq "OK") { 
			Show-InstallationWelcome -CloseApps "$CloseApps" -MinimizeWindows $false -PersistPrompt -DeferDays "3" -BlockExecution -AllowDefer -DeferTimes "3"
		}
		
		# Check the version of the application installed. If that version is less than what the package will be installing, install the applicaiton.
		# For each item in the array...
		# Check if previous MSI versions of application are installed.  
		# If application is installed, uninstall previous MSI versions of application.
		# If uninstall failed, log results. Exit script. 
		$RemoveAppNamesMSICheckVersion = Get-InstalledApplication -Name "$64bitAppInstallName" -Exact | Select-Object DisplayVersion -expand DisplayVersion
		If ($RemoveAppNamesMSICheckVersion -le $appVersion) {
			Foreach ($RemoveAppNameMSI in $RemoveAppNamesMSI) {
				# Check if previous MSI versions of application are installed.  
				$RemoveAppNamesMSICheck = Get-InstalledApplication -Name "$RemoveAppNameMSI"
				If ($null -ne $RemoveAppNamesMSICheck) {
					# Uninstall previous MSI versions of application(s).    
					Try {  
						Write-Log -Message "Previous MSI versions of $RemoveAppNameMSI are installed. Removing..." 
						Remove-MSIApplications -Name "$RemoveAppNameMSI"
						$RemoveAppNamesMSICheck = ""
					}
					# If uninstall failed, log results. Exit script.
					Catch [System.Exception] {
						Write-Log -Message "Uninstaling previous MSI versions of $RemoveAppNameMSI failed with error: $_."
						Write-Log -Message "Exiting script with error."
						Exit-Script -ExitCode 1627
					}
				}
				# Else, log results from check.
				Else {
					Write-Log -Message "Previous MSI versions of $RemoveAppNameMSI are not installed."
				}
			}
		}
		# Else, log that the installed version is newer and countinue.
		Else {
			Write-log -Message "Newer version of $apName is already installed. Skipping the uninstall..."
		}
		
		#Remove old versions of prerequisite applications.
		# For each item in the array...
		# Check if previous MSI versions of application are installed.  
		# If application is installed, uninstall previous MSI versions of application.
		# If uninstall failed, log results. Exit script. 
		# ! Use code above to replace below with next package update.
		# Check if previous MSI versions of application are installed.  
		$RemoveAppNamesMSICheck = Get-InstalledApplication -Name "$64bitAppInstallName" -Exact | Select-Object DisplayVersion -expand DisplayVersion
		If ($RemoveAppNamesMSICheck -lt $appVersion) {
			# Uninstall previous MSI versions of application(s).    
			Try {  
				Write-Log -Message "Previous MSI versions of $64bitAppInstallName are installed. Removing..." 
				Remove-MSIApplications -Name "$64bitAppInstallName"
				$RemoveAppNamesMSICheck = ""
			}
			# If uninstall failed, log results. Exit script.
			Catch [System.Exception] {
				Write-Log -Message "Uninstaling previous MSI versions of $64bitAppInstallName failed with error: $_."
				Write-Log -Message "Exiting script with error."
				Exit-Script -ExitCode 1627
			}
		}
		# Else if current version is already installed, log results from check.
		ElseIf ($RemoveAppNamesMSICheck -eq $appVersion) {
			Write-Log -Message "$64bitAppInstallName is already installed."
		}
		# Else, log results from check.
		Else {
			Write-Log -Message "Previous MSI versions of $64bitAppInstallName are not installed."
		}

		# Check if previous versions of package information registry key (PIRK) exist. 
		# If package information registry key (PIRK) exists, remove previous versions of package information registry key (PIRK).
		# If removal failed, log results. Exit script. 
		# Else, log results from check.
		If (Test-Path -Path "HKLM:\SOFTWARE\Tuolumne County\Package Information\$apName*") { 
			# Remove previous versions of package information registry key (PIRK).
			Try {
				Write-Log -Message "Previous versions of package information registry key (PIRK) exist. Removing..."
				Remove-Item -Path "HKLM:\SOFTWARE\Tuolumne County\Package Information\$apName*" -Force
				Write-Log -Message "Removing previous versions of package information registry key (PIRK) complete."
			}
			# If removal failed, log results. Exit script. 
			Catch [System.Exception] {
				Write-Log -Message "Removing previous versions of package information registry key (PIRK) failed with error: $_"
				Write-Log -Message "Exiting script with error."
				Exit-Script -ExitCode 1627
			}
		}
		# Else, log results from check. 
		Else { 
			Write-Log -Message "Previous versions of package information registry key (PIRK) do not exist."  
		}

		##*===============================================
		##* ANCHOR: INSTALLATION
		##*===============================================
		[string]$installPhase = 'Installation'

		## Handle Zero-Config MSI Installations
		If ($useDefaultMsi) {
			[hashtable]$ExecuteDefaultMSISplat = @{ Action = 'Install'; Path = $defaultMsiFile }; If ($defaultMstFile) { $ExecuteDefaultMSISplat.Add('Transform', $defaultMstFile) }
			Execute-MSI @ExecuteDefaultMSISplat; If ($defaultMspFiles) { $defaultMspFiles | ForEach-Object { Execute-MSI -Action 'Patch' -Path $_ } }
		}

		# Show installation progress message window.
		Show-InstallationProgress -StatusMessage "Installing `n `n $apName ($apversion) `n `n Please Wait..." 

		# Install prerequisite application 1.
		# If installation failed, log results. Exit script. 
		$RemovePrereqAppNamesCheck1 = Get-InstalledApplication -Name "$PrereqApp1Name"
		If ($null -eq $RemovePrereqAppNamesCheck1) {
			Try {
				Write-log -Message "Installing $PrereqApp1Name."
				Execute-MSI -Action Install -Path "$PrereqApp1InstallPath" -Parameters "$PrereqApp1InstallParam"
				Write-Log -Message "Installing $PrereqApp1Name complete." 
			}
			# If install failed, log results. Exit script.
			Catch [System.Exception] {
				Write-Log -Message "Installing $PrereqApp1Name failed with error: $_."
				Write-Log -Message "Exiting script with error."
				Exit-Script -ExitCode 1627
			}
		}

		# Check the version of the application installed. If that version is less than what the package will be installing, install the applicaiton.
		# Else, log that the installed version is newer and countinue.
		# Install application(s).
		# If installation failed, log results. Exit script.
		# Check if previous MSI versions of application are installed.
		# ! Remove with next package update.
		$RemoveAppNamesMSICheckVersion = Get-InstalledApplication -Name "$64bitAppInstallName" -Exact | Select-Object DisplayVersion -expand DisplayVersion
		If ($RemoveAppNamesMSICheckVersion -lt $appVersion) {
			Try {
				Write-log -Message "Previous older versions of $apName are installed. Installing $apName ($apversion)."
				Execute-MSI -Action Install -Path "$64bitAppInstallPath" -Parameters "$64bitAppInstallParam"
				Execute-MSI -Action Patch -Path "$64bitAppInstallPatch" -Parameters "$64bitAppInstallPatchParam"
				Write-Log -Message "Installing $apName ($apversion) complete." 
			}
			# If install failed, log results. Exit script.
			Catch [System.Exception] {
				Write-Log -Message "Installing $apName ($apversion) failed with error: $_."
				Write-Log -Message "Exiting script with error."
				Exit-Script -ExitCode 1627
			}
		}
		# Else, log that the installed version is newer and countinue.
		Else {
			Write-log -Message "Newer version of $apName is already installed. Skipping the install..."
		}

		##* Every package should have a package information registry key (PIRK), which details what the $apversion and $apScriptVErsion are, along with any other information.
		# Create package information registry key (PIRK).
		# If creation failed, log results. Exit script.
		Try {
			Write-Log -Message "Creating package information registry key (PIRK)."
			Set-RegistryKey -Key "HKLM:\Software\Tuolumne County\Package Information" -Name "Readme" -Value "These Package Information Registry Keys (PIRKs) are used for SCCM application detection. Please do not modify unless you know what you are doing." -Type String
			Set-RegistryKey -Key "HKLM:\Software\Tuolumne County\Package Information\$apName ($apversion)" -Name "apVersion" -Value "$apversion" -Type String
			Set-RegistryKey -Key "HKLM:\Software\Tuolumne County\Package Information\$apName ($apversion)" -Name "apScriptVersion" -Value "$apScriptVErsion" -Type String
			Write-Log -Message "Creating package information registry key (PIRK) complete." 
		}
		# If creation failed, log results. Exit script.
		Catch [System.Exception] {
			Write-Log -Message "Creating package information registry key (PIRK) failed with error: $_."
			Write-Log -Message "Exiting script with error."
			Exit-Script -ExitCode 1627
		}

		##*===============================================
		##* ANCHOR: POST-INSTALLATION
		##*===============================================
		[string]$installPhase = 'Post-Installation'

		# Show install completed prompt.
		Write-Log -Message "Showing installation completed prompt."
		Show-InstallationPrompt -Title "Install Completed"  -Icon "Information" -PersistPrompt -ButtonMiddleText "OK" -Message "Your installation of $apName ($apversion) has completed.`n `n Please close any remaining prompts/windows that may have opened.`n `n Questions or issues? `n Please contact the IT Service Desk: `n ITServiceDesk@co.tuolumne.ca.us"	

	}
	ElseIf ($deploymentType -ieq 'Uninstall') {
		##*===============================================
		##* ANCHOR: PRE-UNINSTALLATION
		##*===============================================
		[string]$installPhase = 'Pre-Uninstallation'

		# Check if deployment is interactive.
		# If yes (it is interactive), show close application(s) prompt. Do not allow application(s) to start during install. 
		If ($DeployMode -eq "Interactive") {
			Show-InstallationWelcome -CloseApps "$CloseApps" -MinimizeWindows $false -PersistPrompt -DeferDays "3" -BlockExecution -AllowDefer -DeferTimes "3"
		}

		##*===============================================
		##* ANCHOR: UNINSTALLATION
		##*===============================================
		[string]$installPhase = 'Uninstallation'

		## Handle Zero-Config MSI Uninstallations
		If ($useDefaultMsi) {
			[hashtable]$ExecuteDefaultMSISplat = @{ Action = 'Uninstall'; Path = $defaultMsiFile }; If ($defaultMstFile) { $ExecuteDefaultMSISplat.Add('Transform', $defaultMstFile) }
			Execute-MSI @ExecuteDefaultMSISplat
		}

		# For each item in the array...
		# Check if previous MSI versions of application are installed.  
		# If application is installed, uninstall previous MSI versions of application.
		# If uninstall failed, log results. Exit script. 
		Foreach ($RemoveAppNameMSI in $RemoveAppNamesMSI) {
			# Check if previous MSI versions of application are installed.  
			$RemoveAppNamesMSICheck = Get-InstalledApplication -Name "$RemoveAppNameMSI"
			If ($null -ne $RemoveAppNamesMSICheck) {
				# Uninstall previous MSI versions of application(s).    
				Try {  
					Write-Log -Message "Previous MSI versions of $RemoveAppNameMSI are installed. Removing..." 
					Remove-MSIApplications -Name "$RemoveAppNameMSI"
					$RemoveAppNamesMSICheck = ""
				}
				# If uninstall failed, log results. Exit script.
				Catch [System.Exception] {
					Write-Log -Message "Uninstaling previous MSI versions of $RemoveAppNameMSI failed with error: $_."
					Write-Log -Message "Exiting script with error."
					Exit-Script -ExitCode 1627
				}
			}
			# Else, log results from check.
			Else {
				Write-Log -Message "Previous MSI versions of $RemoveAppNameMSI are not installed."
			}
		}

		# Check if previous MSI versions of application are installed.  
		# ! Remove with next package update.
		$RemoveAppNamesMSICheck = Get-InstalledApplication -Name "$64bitAppInstallName"
		If ($null -ne $RemoveAppNamesMSICheck) {
			# Uninstall previous MSI versions of application(s).    
			Try {  
				Write-Log -Message "Previous MSI versions of $64bitAppInstallName are installed. Removing..." 
				Remove-MSIApplications -Name "$64bitAppInstallName"
				$RemoveAppNamesMSICheck = ""
			}
			# If uninstall failed, log results. Exit script.
			Catch [System.Exception] {
				Write-Log -Message "Uninstaling previous MSI versions of $64bitAppInstallName failed with error: $_."
				Write-Log -Message "Exiting script with error."
				Exit-Script -ExitCode 1627
			}
		}
		# Else, log results from check.
		Else {
			Write-Log -Message "Previous MSI versions of $64bitAppInstallName are not installed."
		}

	# Check if previous versions of package information registry key (PIRK) exist. 
	# If package information registry key (PIRK) exists, remove previous versions of package information registry key (PIRK).
	# If removal failed, log results. Exit script. 
	# Else, log results from check.
	If (Test-Path -Path "HKLM:\SOFTWARE\Tuolumne County\Package Information\$apName*") { 
		# Remove previous versions of package information registry key (PIRK).
		Try {
			Write-Log -Message "Previous versions of package information registry key (PIRK) exist. Removing..."
			Remove-Item -Path "HKLM:\SOFTWARE\Tuolumne County\Package Information\$apName*" -Force
			Write-Log -Message "Removing previous versions of package information registry key (PIRK) complete."
		}
		# If removal failed, log results. Exit script. 
		Catch [System.Exception] {
			Write-Log -Message "Removing previous versions of package information registry key (PIRK) failed with error: $_"
			Write-Log -Message "Exiting script with error."
			Exit-Script -ExitCode 1627
		}
	}
	# Else, log results from check. 
	Else { 
		Write-Log -Message "Previous versions of package information registry key (PIRK) do not exist."  
	}

	##*===============================================
	##* ANCHOR: POST-UNINSTALLATION
	##*===============================================
	[string]$installPhase = 'Post-Uninstallation'



}
ElseIf ($deploymentType -ieq 'Repair') {
	##*===============================================
	##* ANCHOR: PRE-REPAIR
	##*===============================================
	[string]$installPhase = 'Pre-Repair'

	## <Perform Pre-Repair tasks here>

	##*===============================================
	##* ANCHOR: REPAIR
	##*===============================================
	[string]$installPhase = 'Repair'

	## Handle Zero-Config MSI Repairs
	If ($useDefaultMsi) {
		[hashtable]$ExecuteDefaultMSISplat = @{ Action = 'Repair'; Path = $defaultMsiFile; }; If ($defaultMstFile) { $ExecuteDefaultMSISplat.Add('Transform', $defaultMstFile) }
		Execute-MSI @ExecuteDefaultMSISplat
	}
		
	# <Perform Repair tasks here>

	##*===============================================
	##* ANCHOR: POST-REPAIR
	##*===============================================
	[string]$installPhase = 'Post-Repair'

	## <Perform Post-Repair tasks here>

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
