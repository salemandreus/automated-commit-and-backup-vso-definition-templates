 <#
SYNOPSIS
    Add a local file as a blob

SYNTAX 
    Set context
        $dstContext = New-AzureStorageContext -StorageAccountName $dstStorage -SasToken $dstSAS  
    Add blob  
        Add-Blob -storage $storage -container $container -context $context -blob $blob -file $file  
    
DEPENDENCIES
    Requires storage context objects to be created to access storage accounts (see SYNTAX)
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
        Import-Module "$workingDir\$blobModulesSubpath\Add.psm1"         
#>    

Function  Add-Blob
{
    param
        (
        [Parameter(Mandatory=$True)]       
        [String]$storage,
        [Parameter(Mandatory=$True)]       
        [Object]$context,
        [Parameter(Mandatory=$True)]       
        [String]$container,
        [Parameter(Mandatory=$True)]       
        [String]$blob,
        [Parameter(Mandatory=$True)]       
        [String]$file
        )

    Write-Host "Uploading Blob: $($blob.ToUpper()) to Container: $($container.ToUpper())"
    
    # Set Content
    $UploadFile = @{
        Context = $context;
        Container = $container;
        File = $file; 
        Blob = $blob;
        }
    Set-AzureStorageBlobContent @UploadFile

    #test uploaded
    $check = Get-AzureStorageBlob -Container $UploadFile.Container -Blob $UploadFile.Blob -Context $UploadFile.Context 
    if ($check -eq $null)
    {
        throw "failed to upload."
    }
    else
    {
        $check
        write-host "Uploaded successfully."
    } 
}