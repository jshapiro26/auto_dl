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
  FILES=$(/usr/local/bin/rclone lsd $REMOTE_HOST_NAME:$REMOTE_HOST_PATH | awk '{print $5}')
  # echo files into lockfile to view whats being downloaded easily
  /bin/echo $FILES > $LOCK_FILE
  # Download files
  /usr/local/bin/rclone moveto -v $REMOTE_HOST_NAME:$REMOTE_HOST_PATH $LOCAL_HOST_NAME:$TEMP_DIR
  RESULT=$?
  # Post to Slack on success/fail of download
  if [ $RESULT -eq 0 ] && [ -n "$FILES" ]; then
    for FILE in $FILES
    do
      /usr/local/bin/rclone rmdirs $REMOTE_HOST_NAME:$REMOTE_HOST_PATH/$FILE
      /bin/mv $TEMP_DIR$FILE $POST_PROCESS_DIR
    done
    /bin/curl -X POST --data-urlencode "payload={'text': 'The following files have been downloaded locally, removed from the remote host and moved into the post processing directory: ${FILES}'}" $SLACK_ENDPOINT
  elif [ $RESULT -ge 1 ] && [ -n "$FILES" ]; then
    /bin/curl -X POST --data-urlencode "payload={'text': 'The following files failed to download locally: ${FILES}'}" $SLACK_ENDPOINT
  fi
  # remove lock file when done running
  /bin/rm -f $LOCK_FILE
else
  echo "Files are currently being downloaded, skipping run"
fi