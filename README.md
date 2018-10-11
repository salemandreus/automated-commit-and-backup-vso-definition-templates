# commit-and-backup-build-release-definition-exports
Using the VS Online API and an access token it automates downloading of build and release definitions from VS Online - this can be set to run as frequently as desired and 
Checks for changes from the last version. It then:
1) Automatically commits them to a remote git repo if any changes are found.  
2) Also backs them up up into Azure blob storage in case of needing to quickly recover them (if multiple people have access to modifying build templates this is a good idea). 
3) As a final failsafe, can also keep the latest copy on the local machine for quick accessibility in case of disaster during the day to roll back to the latest changeset.

Cleanup/maintaining latest failsafe:
Instead of relying on the blob default of automatically expiring a certain number of backups past a certain date, when it performs cleanups in blob it ensures ensure a set number of copies remain in blob storage (and max one locally) in case the build running this script fails to run, to ensure that there are always a set number of backups that are the most recent- the max to keep in blob is easily configurable via an environment variable on an automated build.
