#!/bin/bash
set -e
###########################################################
## To watch multiple remote directories, set config vars ##
## in a file at the same path as the script by copying   ##
## the config_vars_sample to a name of your choice. End  ##
## the name with .confg for it to be git-ignored. At run ##
## of the script, pass the name of your config file      ##
## as an arg. Otherwise set your config vars below.      ##
###########################################################
if [ -n "$1" ]; then
  source ./$1
else
  LOCK_FILE=
  REMOTE_HOST_NAME=
  REMOTE_HOST_PATH=
  LOCAL_HOST_NAME=
  POST_PROCESS_DIR=
  TEMP_DIR=
  SLACK_ENDPOINT=
fi
# If the lockfile exists, check that files are actually being downloaded
# by checking the contexts of the file; it will be empty upon a failed connection.
if [ -f $LOCK_FILE ]; then
  LOCK_CONTENTS=$(cat $LOCK_FILE)
  if [ -z "$LOCK_CONTENTS" ]; then
    echo "Script failed previously, removing lockfile to allow script to run"
    /bin/rm -f $LOCK_FILE
  fi
fi
# if lockfile is not present create lock file and run logic
if [ ! -f $LOCK_FILE ]; then
  /bin/touch $LOCK_FILE
  # save list of directories and files to be downloaded
  DIRS=$(/usr/local/bin/rclone lsd $REMOTE_HOST_NAME:$REMOTE_HOST_PATH | awk '{print $5}'| tr '\n' ' ')
  FILES=$(/usr/local/bin/rclone ls $REMOTE_HOST_NAME:$REMOTE_HOST_PATH --include "/*.mkv" | awk '{print $2}'| tr '\n' ' ')
  # Determine if nothing, files, directories or both will be downloaded
  if [ -z "$DIRS" ] && [ -z "$FILES" ]; then
    ALL_FILES=""
  elif [ -z "$DIRS" ] && [ -n "$FILES" ]; then
    ALL_FILES=$FILES
  elif [ -n "$DIRS" ] && [ -z "$FILES" ]; then
    ALL_FILES="$DIRS"
  elif [ -n "$DIRS" ] && [ -n "$FILES" ]; then
    ALL_FILES=${DIRS}' '${FILES}
  fi
  # echo files into lockfile to view whats being downloaded easily
  /bin/echo -e $ALL_FILES > $LOCK_FILE
  # Download files
  /usr/local/bin/rclone moveto -v $REMOTE_HOST_NAME:$REMOTE_HOST_PATH $LOCAL_HOST_NAME:$TEMP_DIR --transfers=10
  RESULT=$?
  # Proceed if succeeded to download files
  if [ $RESULT -eq 0 ] && [ -n "$ALL_FILES" ]; then
    # Move all files from temp directory to post processing directory
    for FILE in $ALL_FILES
    do
      /bin/mv $TEMP_DIR$FILE $POST_PROCESS_DIR
    done
    # Cleanup empty directories left behind by rclone on remote
    for DIR in $DIRS
    do
      /usr/local/bin/rclone rmdirs $REMOTE_HOST_NAME:$REMOTE_HOST_PATH/$DIR
    done
    # Post to slack with list of suceeded files
    /bin/curl -X POST --data-urlencode "payload={'text': 'The following files have been downloaded locally, removed from the remote host and moved into the post processing directory: ${ALL_FILES}'}" $SLACK_ENDPOINT
  # Post to slack on failure
  elif [ $RESULT -ge 1 ] && [ -n "$ALL_FILES" ]; then
    /bin/curl -X POST --data-urlencode "payload={'text': 'The following files failed to download locally: ${ALL_FILES}'}" $SLACK_ENDPOINT
  fi
  # remove lock file when done running
  echo "Done downloading files, removing lockfile"
  /bin/rm -f $LOCK_FILE
else
  echo "Files are currently being downloaded, skipping run"
fi