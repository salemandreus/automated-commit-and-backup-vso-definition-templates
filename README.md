# commit-and-backup-build-release-definition-exports
Automates downloading of build and release definitions from VS Online - this can be set to run as frequently as desired and 
1) Automatically commits them to a remote git repo if any changes are found.  
2) Also backs them up up into Azure blob storage in case of needing to quickly recover them (if multiple people have access to modifying build templates this is a good idea). 
3) As a final failsafe, can also keep the latest copy on the build server for quick accessibility in case of disaster during the day to roll back to the latest changeset.
