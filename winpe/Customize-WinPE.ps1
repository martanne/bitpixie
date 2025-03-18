<#
.SYNOPSIS
	Customizes a Windows Preinstallation Environment (WinPE) boot image to add BitLocker support.

.DESCRIPTION
	This function automates the process of mounting, modifying, and optimizing a WinPE boot image.
	It adds necessary components for BitLocker, performs cleanup, and reduces image size for deployment.
	It follows the steps described in the official documentation:
	
	  https://learn.microsoft.com/en-us/windows/deployment/customize-boot-image

.PARAMETER WinPEMountPoint
	Specifies the (temporary) directory where the WinPE image will be mounted. This parameter is required.

.PARAMETER BasePath
	Specifies the base directory of the Windows Assessment and Deployment Kit (ADK) installation.
	Default: "C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Windows Preinstallation Environment\amd64".

.PARAMETER DismExe
	Specifies the path to the Deployment Image Servicing and Management (DISM) executable.
	Default: "C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\DISM\dism.exe".

.EXAMPLE
	Customize-WinPE -WinPEMountPoint "C:\winpe-bitpixie"

#>
function Customize-WinPE {
	param (
		[Parameter(Mandatory = $true)]
		[string]$WinPEMountPoint,
		[string]$BasePath = "C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Windows Preinstallation Environment\amd64",
		[string]$DismExe = "C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\DISM\dism.exe"
	)

	# Ensure the WinPE mount point directory exists
	if (-Not (Test-Path $WinPEMountPoint)) {
		New-Item -ItemType Directory -Path $WinPEMountPoint -Force | Out-Null
	}

	$WimImage = "$BasePath\en-us\winpe.wim"
	
	# Step 1: Skip download and install ADK
	# Step 2: Skip download of cumulative update

	# Step 3: Backup existing image
	if (-Not (Test-Path "$WimImage.backup")) {
		Copy-Item -Path $WimImage -Destination "$WimImage.backup"
	}
	
	# Step 4: Mount boot image to mount folder
	Mount-WindowsImage -Path $WinPEMountPoint -ImagePath $WimImage -Index 1
	
	# Step 5: Skip add drivers to boot image, unless needed for specific hardware
	
	# Step 6: Add optional components to boot image
	$PackagePath = "$BasePath\WinPE_OCs"
	$Packages = @(
		"WinPE-WMI.cab",
		"WinPE-SecureStartup.cab",
		"WinPE-NetFX.cab",
		"WinPE-Scripting.cab",
		"WinPE-PowerShell.cab",
		"WinPE-FMAPI.cab",
		"WinPE-SecureBootCmdlets.cab",
		"WinPE-EnhancedStorage.cab"
	)
	
	foreach ($Package in $Packages) {
		Add-WindowsPackage -PackagePath "$PackagePath\$Package" -Path $WinPEMountPoint
		$EnUSPackage = "$PackagePath\en-us\$($Package -replace '\.cab$', '_en-us.cab')"
		if (Test-Path $EnUSPackage) {
			Add-WindowsPackage -PackagePath $EnUSPackage -Path $WinPEMountPoint
		}
	}
	
	# Step 7: Skip add cumulative update (CU) to boot image

	# Step 8: Skip Copy boot files from mounted boot image to ADK installation path

	# Step 9: Perform component cleanup
	Start-Process "$DismExe" -ArgumentList " /Image:`"$WinPEMountPoint`" /Cleanup-image /StartComponentCleanup /Resetbase /Defer" -Wait -LoadUserProfile
	Start-Process "$DismExe" -ArgumentList " /Image:`"$WinPEMountPoint`" /Cleanup-image /StartComponentCleanup /Resetbase" -Wait -LoadUserProfile
	
	# Step 10: Verify all desired packages have been added to boot image
	Get-WindowsPackage -Path $WinPEMountPoint
	
	# Step 11: Unmount boot image and save changes
	Dismount-WindowsImage -Path $WinPEMountPoint -Save -Verbose
	
	# Step 12: Export boot image to reduce size
	Export-WindowsImage -SourceImagePath $WimImage -SourceIndex 1 -DestinationImagePath "$WimImage.export" -CompressionType max -Verbose
	Move-Item -Path "$WimImage.export" -Destination $WimImage -Force
}
