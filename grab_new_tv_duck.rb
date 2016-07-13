#### Rewrite for duck.sh
require 'pry-nav'
require 'yaml'
require 'dotenv'
require_relative 'DownloadProgress'
Dotenv.load

Encoding.default_external = Encoding::UTF_8
Encoding.default_internal = Encoding::UTF_8

start = Time.now
puts "Started script at #{start}"

# Set vars from .env
remote_tv_dir = ENV['REMOTE_TV_DIR']
local_tv_dir = ENV['LOCAL_TV_DIR']
host = ENV['HOST']
username = ENV['USERNAME']
password = ENV['PASSWORD']

# Load list of tv_shows already downlaoded; if the list doesn't exist create an empty array
if File.exist?('downloaded_tv.yaml')
  @downloaded_tv = YAML.load_file('downloaded_tv.yaml')
else
  @downloaded_tv = []
end

# Get list of shows in directory
tv_shows = `/usr/local/bin/duck -l sftp://#{username}:#{password}@#{host}#{remote_tv_dir}`.split
@new_tv_shows = []
tv_shows.each do |show|
  if show.end_with? ".mkv"
    @new_tv_shows << show
  end
end

# Determine tv_shows to download
to_download = @new_tv_shows - @downloaded_tv

until @new_tv_shows - @downloaded_tv == []
  puts "Will download the following shows #{to_download}"
  to_download.each do |show|
    puts "downloading #{show} to #{local_tv_dir}"
    # if the show downloads, add the show to the downloaded_show hash; overwrite file if it exists already; surpress progress output
    if system("/usr/local/bin/duck -q -e overwrite -d sftp://#{username}:#{password}@#{host}#{remote_tv_dir}" + show + " " + local_tv_dir)
      puts "The show: #{show} downloaded successfully"
      @downloaded_tv << show
      # delete file from server
      if system("/usr/local/bin/duck -D sftp://#{username}:#{password}@#{host}#{remote_tv_dir}" + show)
        puts "#{show} was deleted from the remote server"
      else
        puts "#{show} failed to be deleted from the remote server"
      end
    else
      puts "there was a problem downloading #{show}"
    end
  end
  puts "all up-to-date"
end

# Overwrite list of downloaded tv_shows with updated array
File.open('downloaded_tv.yaml', "w+") do |file|
  file.write(@downloaded_tv.to_yaml)
end

finish = Time.now
puts "Finished script at #{finish}. Took #{finish - start} to complete"
