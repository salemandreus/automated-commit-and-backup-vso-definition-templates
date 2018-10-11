 <#
SYNOPSIS
    Deletes oldest X blobs in a container.
    Keeps the number of blobs specified.

SYNTAX 
    set context
        $dstContext = New-AzureStorageContext -StorageAccountName $dstStorage -SasToken $dstSAS  
    Remove oldest blobs  
        Remove-OldestBlobs-storage $storage -container $container -context $storageContext -keeplatest $keeplatest
    
DEPENDENCIES
    Requires storage context objects to be created to access storage accounts. (See SYNTAX).
    Scripts should use an SAS token with the appropriate permissions set - limit prod permissions! 

IMPORT MODULE
    Script Arguments:
        -blobModulesSubpath $(PSMODULES_BLOB_SUBPATH) 
      
    Script:  
        param
        (
        [Parameter(Mandatory=$True)]       
        [String]$blobModulesSubpath
        )

        $workingDir = "$(Split-path $(Split-Path $script:MyInvocation.MyCommand.Path))" 
        Import-Module "$workingDir\$blobModulesSubpath\RemoveOldest.psm1"
#>

function Remove-OldestBlobs
{
    param
        (
        [Parameter(Mandatory=$True)]       
        [int]$keeplatest,
        [Parameter(Mandatory=$True)]       
        [String]$storage,
        [Parameter(Mandatory=$True)]       
        [Object]$context,
        [Parameter(Mandatory=$True)]       
        [String]$container
        )  
        
        if ($keeplatest -lt 1)  # Safeguards against null/zero - which would result in deleting all!
        {
            Write-host "Not removing any old blobs from container $($container.ToUpper()) as no number to keep is specified" -f DarkYellow
            $remaining = Get-AzureStorageBlob -Context $context -Container $container | Sort-Object { $_.lastmodified  } -descending  | Select-Object

        }
        
        else 
        {
            # Remove Oldest Blobs
            $found =  Get-AzureStorageBlob -Context $context -Container $container | Sort-Object { $_.lastmodified  } -descending   
            $remove = Get-AzureStorageBlob -Context $context -Container $container | Sort-Object { $_.lastmodified  } -descending  | Select-Object -Skip $keeplatest 
         
            write-host "Blobs Found:" -f Magenta ; $found | % {write-host $_.Name -f darkmagenta}
            Write-host "`nRemoving oldest blobs `nKeeping latest: $keeplatest `nNumber To Remove: $($remove.count)" -f Magenta

            $remove | % { Write-host "Removing: $($_.name)" -f DarkCyan }
            $remove | % {Remove-AzureStorageBlob -Blob $_.Name -Container $Container -Context $context -Force }
        

            # Check Removed
            $remaining = Get-AzureStorageBlob -Context $context -Container $container | Sort-Object { $_.lastmodified  } -descending  | Select-Object 
            $notDeleted = $remove | ?{$($remaining.name) -ccontains $($_.name)}      
        
            if ($notDeleted) 
            { 
                Throw "Failed to delete old blobs: $($notDeleted.name) "
            }
            elseif ($remove -eq $null)
            {
                Write-host "No old extra blobs to remove" -f Green
            }
            else
            {
                $remove | % { Write-host "Removed: $($_.name)" -f Cyan }
            }
            write-host "Blobs Remaining:" -f Magenta ; $remaining | % {write-host $_.Name -f darkmagenta}
        }
        write-host "Blobs Remaining: " -f DarkYellow;  $remaining.count 
        # show number of blobs in container
        
}