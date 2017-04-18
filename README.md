# auto_dl

This repo is used to watch and download files from a remote source to a local temporary directory. Once files have finished downloading, move them from the temporary directory to a post processing directory for other applications to pick-up.

Setup an incoming webhook on slack to use for these scripts.

## rclone_move.sh
Download all files from a remote to local temporary directory and move to a post processing directory when download is complete. Delete the files from remote and post list of successfully downloded files to a slack incoming webhook.
### setup
- Download the appropriate version of rclone for your host: [https://rclone.org/downloads/](https://rclone.org/downloads/).
- Copy the binary to `/usr/local/bin/` and make it executable.
- On the host:
  - Run `rclone config` and follow the wizard to setup your remote destination that you will be downloading files from (i.e. SFTP, Gogle Drive), give it a friendly name.
  - Run `rclone config` again to setup your host as a rclone destination, give it a friendly name.
- If you will only be using the script to download files from a single directory, set the config varibles on lines 14-20.
- If you will be using this script to watch multiple directories:
  - Copy `config_vars_sample` to a name of your choice in the same directory as the script.
  - Set the config vars in the file.
  - Run the script and pass the name of the file as an argument: `rclone_move.sh name_of_file` 
- Copy `config_vars_sample` as many times needed to a new file and repeat the previous steps.