#### Rewrite for duck.sh
require 'pry-nav'
require 'yaml'
require 'dotenv'
require 'httparty'
include HTTParty

Dotenv.load

Encoding.default_external = Encoding::UTF_8
Encoding.default_internal = Encoding::UTF_8

start = Time.now
puts "Started script at #{start}"

# Create lock file to prevent race conditions
if File.exist?('downloading_tv.lock')
  puts "TV shows are currently downloading, skipping run."
  finish = Time.now
  puts "Finished script at #{finish}. Took #{finish - start} to complete"
  exit 0
else
  File.open('downloading_tv.lock', "w+")
  puts "Created lockfile"
end

# Set vars from .env
remote_tv_dir = ENV['REMOTE_TV_DIR']
local_tv_dir = ENV['LOCAL_TV_DIR']
host = ENV['HOST']
username = ENV['USERNAME']
password = ENV['PASSWORD']

# Send Slack
def send_slack(show,status)
  @response = HTTParty.post(ENV['SLACK_WEBHOOK_URL'],
    {
      :body => "payload={'username': 'SeedBoxDL', 'text': '#{show} completed with status: #{status}', 'icon_emoji': ':metal:'}"
    }
  )
end

# Load list of tv_shows already downlaoded; if the list doesn't exist create an empty array
if File.exist?('downloaded_tv.yaml')
  @downloaded_tv = YAML.load_file('downloaded_tv.yaml')
else
  @downloaded_tv = []
end

# Get list of shows in directory
tv_shows = `/usr/local/bin/duck -l sftp://#{username}:#{password}@#{host}#{remote_tv_dir}`.gsub("\n", "  ").gsub(/(\r).*( successful...)/, "").split("  ")
@new_tv_shows = []
tv_shows.each do |show|
  if show.end_with? ".mkv"
    @new_tv_shows << show
  else
    @new_tv_shows << show + "/"
  end
end

# Determine tv_shows to download
to_download = @new_tv_shows - @downloaded_tv

until @new_tv_shows - @downloaded_tv == []
  puts "Will download the following shows #{to_download}"
  to_download.each do |show|
    puts "downloading #{show} to #{local_tv_dir}"
    # if the show downloads, add the show to the downloaded_show hash; overwrite file if it exists already; surpress progress output
    if system("/usr/local/bin/duck -q -e overwrite -r 2 -d sftp://#{username}:#{password}@#{host}#{remote_tv_dir}" + show + " " + local_tv_dir)
      puts "The show: #{show} downloaded successfully"
      @downloaded_tv << show
      # send success email
      send_slack(show,"Downloaded Successfully")
      # delete file from server
      if system("/usr/local/bin/duck -D sftp://#{username}:#{password}@#{host}#{remote_tv_dir}" + show)
        puts "#{show} was deleted from the remote server"
      else
        puts "#{show} failed to be deleted from the remote server"
        # send failure to delete email
        send_slack(show,"Failed to delete")
      end
    else
      puts "there was a problem downloading #{show}"
      # remove failed show from array of to be downloaded to prevent endless loop
      @new_tv_shows = @new_tv_shows - show
      # send general error email
      send_slack(show,"Error")
    end
  end
  puts "all up-to-date"
end

# Overwrite list of downloaded tv_shows with updated array
File.open('downloaded_tv.yaml', "w+") do |file|
  file.write(@downloaded_tv.to_yaml)
end

if File.exist?('downloading_tv.lock')
  File.delete('downloading_tv.lock')
  puts "Deleted lockfile"
end

finish = Time.now
puts "Finished script at #{finish}. Took #{finish - start} to complete"
