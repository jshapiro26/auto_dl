# auto_dl

This repo is used to watch and download files from a remote source to a local temporary directory. Once files have finished downloading, move them from the temporary directory to a post processing directory for other applications to pick-up.

Setup an incoming slackwebhook to use for these scripts.

## rclone_move.sh
Download all files from a remote to local; delete files from remote and post list of successfully downloded files to slack incoming webhook.
### setup
- Download the appropriate version of rclone for your host: [https://rclone.org/downloads/](https://rclone.org/downloads/).
- On the host you will be running the script from:
  - Run `rclone config` and follow the wizard to setup your remote destination that you will be downloading files from.
  - Run `rclone config` again to setup your local directory that you'd like to download rclone into.
- Set your config variables in the script and cron/run.

## grab\_new\_tv_duck.rb
Download (SFTP) all Folders and/or `.mkv` files from a remote directory to a local directory. After each file is downloaded, remove from remote, post to slack and move to secondary directory for post processing.
### setup
- Download duck binary for sftp: [https://duck.sh/](https://duck.sh/).
- Make sure ruby is installed, run `bundle install`,
- Copy `.env_sample` to `.env` and enter your secrets.
- Cron or run the script: `ruby grab_new_tv_duck.rb`.