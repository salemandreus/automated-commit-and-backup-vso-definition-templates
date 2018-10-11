<#
SYNOPSIS
    Get Definitions:
        Core: Get all build and release definitions across all projects on VSTS as a zip.
    Save to Version Control:
        External Script: Commits them to git for versioning.
    Save to blob:
        Modules: Backs them up to blob storage.
#>

Param
    (
    [parameter(Mandatory=$true)]
    [String] $token,                  # VSTS User token 
    [parameter(Mandatory=$true)]
    [String] $SAS,                    # Signed Access Signature Token generated from Azure  
    [parameter(Mandatory=$false)]
    [Int] $keeplatest,                # number Of backups to keep
    [parameter(Mandatory=$true)]
    [String] $commitMsgPrefix         # this is a variable so it can be customised during manually triggered builds
    )

$elapsed = [System.Diagnostics.Stopwatch]::StartNew()
write-host "Started at $(get-date)" 

$ErrorActionPreference = "Continue" # so if it fails to commit it still saves to blob

# VARIABLES
$base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f "",$token)))

# Import Modules
$workingDir = "$(Split-path $(Split-Path $script:MyInvocation.MyCommand.Path))"
Import-Module "$workingDir\modules\blob\add.psm1"
Import-Module "$workingDir\modules\blob\removeOldest.psm1"

$scriptLoc = $(Split-Path $script:MyInvocation.MyCommand.Path)
$download = "$scriptLoc\definitionsTemporaryDownload\$(Get-Date -f yyyyMMdd-HHmmmss)"
$archive = "$download.zip" 
$commitMsg = "$commitMsgPrefix $(Split-Path $download -Leaf)"


# FUNCTIONS
Function Invoke-VSTSGetMethod
{
    param
    (
    [parameter(Mandatory=$true)]
    [String] $uri 
    )  
        $result = Invoke-RestMethod -Uri $uri -Method Get -ContentType "application/json" -Headers @{Authorization=("Basic {0}" -f   $base64AuthInfo)}

        if ([string]::IsNullOrEmpty($result))   # the script can fail silently on the build if returning empty
        { 
            throw "Rest call failed to return results."
        }
        if ($result.count -eq 0)
        {
            Write-Host "No $($type.ToUpper()) definitions to back up for $($project.ToUpper())"
        }

        return $result
}


function Get-ListOfDefinitions
{
    param ($project, $type)

        Write-Host "Getting $($type.ToUpper()) Definitions list for $($project.ToUpper()) :" -f DarkYellow
        
        switch ($type)
        {
            "build"   {$uri = "https://myproj.visualstudio.com/DefaultCollection/$project/_apis/build/definitions?api-version=2.0"; break }
            "release" {$uri = "https://myproj.vsrm.visualstudio.com/defaultcollection/$project/_apis/release/definitions?api-version=3.0-preview.1"; break}
        }
    
        $list = Invoke-VSTSGetMethod -uri $uri

        if ([string]::IsNullOrEmpty($list))  
        {
            throw "No $($type.ToUpper()) definitions found for $($project.ToUpper())."
        }

        Write-host "Found: $($list.count)"  -f DarkGreen
        return $list
}

Function Get-Definition
{
    param ([String] $project, [String] $type, [Object] $defInfo)

        Write-Host "Exporting: $($defInfo.Name) ID:$($defInfo.ID)  " -f DarkYellow
        
        switch ($type)
        {
            "build"   {$uri = "https://myproj.visualstudio.com/DefaultCollection/$project/_apis/build/definitions/$($defInfo.ID)?api-version=2.0"; break }
            "release" {$uri = "https://myproj.vsrm.visualstudio.com/defaultcollection/$project/_apis/release/definitions/$($defInfo.ID)?api-version=3.0-preview.1"; break }
        }
        
        $definition = Invoke-VSTSGetMethod -uri $uri
        
        if ([string]::IsNullOrEmpty($definition))
        {
            throw "Unable to Export $($defInfo.Name) ID:$($defInfo.ID)."
        }

        Write-Host "Exported: " -f DarkYellow -nonewline; Write-Host "$($definition.name) ID: $($definition.id) " -f DarkGreen  #returns name, ID and type "build" or "release" - ONLY IF RETRIEVED
        return $definition
}

Function Save-DefinitionsLocally
{
    param
        (
        [parameter(Mandatory=$true)]
        [String] $project
        )

        # Get lists of definitions for a VSTS project
        # Save all defs - .json files

        # Save Build Defs
        $builds = Get-ListOfDefinitions -project $project -type "build"
        $builds.value   | % { Get-Definition -project $project -type $_.type -defInfo $_| ConvertTo-Json -Depth 10 | New-Item -Path "$download\$project\$($_.type)\" -Name "$($_.name).json" -type  "file" -Force }
        # Save Release Defs
        $releases = Get-ListOfDefinitions -project $project -type "release"
        $releases.value | % { Get-Definition -project $project -type "release" -defInfo $_| ConvertTo-Json -Depth 10 | New-Item -Path "$download\$project\release\" -Name "$($_.name).json" -type  "file" -Force }
}

# SCRIPT

# CLEANUP downloads (parent directory)
 split-path $download | ?{Test-Path $_ } | % {remove-item $_ -Recurse ; write-host "Cleaned directory $_" -f gray }

# download all definitions
$projects= Invoke-RestMethod -Uri "https://myproj.visualstudio.com/DefaultCollection/_apis/projects?api-version=1.0" -Method Get -ContentType "application/json" -Headers @{Authorization=("Basic {0}" -f   $base64AuthInfo)}
$projects.value.name | % {Save-DefinitionsLocally -project $_}

#push to Git repo
pushd $scriptLoc
.\SaveToGit.ps1  -repoLocation "C:\gitTemp" -branchName "AutomatedBackups" -remoteRepoUrl "https://myproj.visualstudio.com/DefaultCollection/Product/_git/EnvironmentConfiguration" -gitFilePath "\CI\BuildReleaseDefinitions" -commitMsg $commitMsg -sourceFilePath "$download\"
popd 

#upload to blob 
$storageContext = New-AzureStorageContext -StorageAccountName "autobackupsstorage" -SasToken $SAS  
Compress-Archive -Path "$download\*" -DestinationPath $archive
$blob = Split-Path $archive -Leaf
Add-Blob -storage "autobackupsstorage" -container "definitions" -blob $blob -file $archive -context $storageContext

# CLEANUP: 
Remove-OldestBlobs -keeplatest $keepLatest -storage "autobackupsstorage" -container "definitions" -context $storageContext 

write-host "Elapsed Time: $($elapsed.Elapsed.ToString())"