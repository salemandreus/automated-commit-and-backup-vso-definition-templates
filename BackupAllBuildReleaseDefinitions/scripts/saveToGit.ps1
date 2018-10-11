<#
SYNOPSIS
    Automatically commits files (eg backups) to version control.
	
	(Clones a remote repo, replaces a specified directory and commits the file or directory to version control.)

SYNTAX 
    Script Arguments
        -srchost -repo $(GIT_LOCAL_REPO) -branchName $(GIT_BRANCH) -remoteRepo $(GIT_REMOTE_REPO) -remoteRepoUrl $(GIT_REMOTE_URL) -gitFilePath $(GIT_FILE_PATH) -commitMsg $(GIT_COMMIT_MESSAGE) -sourceFilePath $(GIT_SOURCEFILE_COPY_PATH)
    
    Running from within a script:
        pushd $scriptLoc
        .\SaveToGit.ps1  -repo $gitRepo -branchName $branchName -remoteRepoUrl $remoteRepoUrl -gitFilePath $gitFilePath -commitMsg $commitMsg -sourceFilePath $archive
        popd

DEPENDENCIES
    See SYNTAX for build variables as script parameters 

IMPORTED MODULES
    none
#>

Param
    (
    [parameter(Mandatory=$true)]     # Git repo 
    [String] $branchName,
    [parameter(Mandatory=$true)]     
    [String] $remoteRepoUrl,
    [parameter(Mandatory=$true)]      # Locations add 
    [String] $repoLocation,
    [parameter(Mandatory=$true)]
    [String] $sourceFilePath,
    [parameter(Mandatory=$true)]
    [String] $gitFilePath,
    [parameter(Mandatory=$true)]
    [String] $commitMsg
    )

$repo = "$repoLocation\$(split-path $remoteRepoUrl -Leaf)"

function Check-ForErrors
{
    if($LastExitCode -eq 0)
    {
        Write-Host "Completed git operation successfully."
    }
    # else throw error
    else
    {
        Write-Host $output
        throw "Failed: $outputString"
    } 
}

function New-Repo
{   
    # cleanup existing repo the
    
    if (test-path $repo)
    {
        # Clean old location if exists
        Write-host "Cleaning old repo location: $repo"
        Remove-Item -Path $repo -Recurse -Force
    }
    
    Write-host "Creating new repo: $repo"
    pushd $repoLocation
    
    # Clone                                                                 # cleanup then recreating the repo via cloning before adding the changes is just a better safeguard for automating commits without getting merge conflicts
    ($output1 = git clone $remoteRepoUrl ) 2>&1 | Write-Host                # piping this way outputs logs but prevents git push in powershell throwing false error in VSTS and breaking the build
    Check-ForErrors
    popd
}

function Replace-Item
{
    # Remove current version from newly cloned repo            - otherwise does not remove old definitions that were deleted
    Remove-Item $repo$($gitFilePath) -Recurse -Force
    Copy-Item -Path $sourceFilePath -Destination $repo$($gitFilePath) -Recurse -Force
}

function Save-ToRemoteBranch
{
    pushd $repo
    git add $repo$($gitFilePath)                                        # add directory/file
    git commit -m $commitMsg                                     # commit
    Write-host "Pushing file to git repo origin at $remoteRepoUrl"            
    #git pull origin $branchName                             # pull     
    
    # push changes                                                        # push
    ($output1 = git push ) 2>&1 | Write-Host                # piping this way outputs logs but prevents git push in powershell throwing false error in VSTS logs and breaking the build
    Check-ForErrors
    popd
}

# Script
Write-host "Committing item to git vcs..."

# Create Repo
New-Repo 
                     
# Import file to location
Replace-Item       
                    
# Add file to VCS
Save-ToRemoteBranch