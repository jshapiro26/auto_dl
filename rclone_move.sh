#!/bin/bash
set -e
# set path to lockfile
LOCK_FILE=
# config variables
# run rclone config to setup your rclone remote and local
REMOTE_HOST_NAME=
REMOTE_HOST_PATH=
LOCAL_HOST_NAME=
POST_PROCESS_DIR=
TEMP_DIR=
SLACK_ENDPOINT=
# if lockfile is not present create lock file and run logic
if [ ! -f $LOCK_FILE ]; then
  /bin/touch $LOCK_FILE
  # save list of directories and files to be downloaded
  DIRS=$(/usr/local/bin/rclone lsd $REMOTE_HOST_NAME:$REMOTE_HOST_PATH | awk '{print $5}')
  FILES=$(/usr/local/bin/rclone ls $REMOTE_HOST_NAME:$REMOTE_HOST_PATH --include "/*.mkv" | awk '{print $2}')
  ALL_FILES=${DIRS}'\n'${FILES}
  # echo files into lockfile to view whats being downloaded easily
  /bin/echo $ALL_FILES > $LOCK_FILE
  # Download files
  /usr/local/bin/rclone moveto -v $REMOTE_HOST_NAME:$REMOTE_HOST_PATH $LOCAL_HOST_NAME:$TEMP_DIR
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
    /bin/curl -X POST --data-urlencode "payload={'text': 'The following files have been downloaded locally, removed from the remote host and moved into the post processing directory: ${FILES}'}" $SLACK_ENDPOINT
  # Post to slack on failure
  elif [ $RESULT -ge 1 ] && [ -n "$ALL_FILES" ]; then
    /bin/curl -X POST --data-urlencode "payload={'text': 'The following files failed to download locally: ${FILES}'}" $SLACK_ENDPOINT
  fi
  # remove lock file when done running
  /bin/rm -f $LOCK_FILE
else
  echo "Files are currently being downloaded, skipping run"
fi