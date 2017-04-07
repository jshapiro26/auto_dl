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
  # save list of files to be downloaded
  FILES=$(rclone ls $REMOTE_HOST_NAME:$REMOTE_HOST_PATH)
  # echo files into lockfile to view whats being downloaded easily
  /bin/echo $FILES > $LOCK_FILE
  # Download files
  /usr/local/bin/rclone moveto -v $REMOTE_HOST_NAME:$REMOTE_HOST_PATH $LOCAL_HOST_NAME:$TEMP_DIR
  RESULT=$?
  # Post to Slack on success/fail of download
  if [ $RESULT -eq 0 ] && [ ! -z "$FILES" ]; then
    /bin/mv $TEMP_DIR* $POST_PROCESS_DIR
    /bin/curl -X POST --data-urlencode "payload={'text': 'The following files have been downloaded locally, removed from the remote host and moved into the post processing directory: ${FILES}'}" $SLACK_ENDPOINT
  elif [ $RESULT ! -eq 0 ] && [ ! -z "$FILES" ]; then
    /bin/curl -X POST --data-urlencode "payload={'text': 'The following files failed to download locally: ${FILES}'}" $SLACK_ENDPOINT
  fi
  # remove lock file when done running
  /bin/rm -f $LOCK_FILE
else
  echo "Files are currently being downloaded, skipping run"
fi