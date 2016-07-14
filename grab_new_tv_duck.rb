#### Rewrite for duck.sh
require 'pry-nav'
require 'yaml'
require 'dotenv'
require 'sendgrid-ruby'
include SendGrid

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

def send_mail(show,status)
  from = Email.new(email: 'plex_notify@tokimonsta.net')
  subject = "TV Show Download #{status}"
  to = Email.new(email: ENV['EMAIL_TO'])
  content = Content.new(type: 'text/plain', value: "#{show} was processed @ #{Time.now} with status of #{status}")
  mail = Mail.new(from, subject, to, content)
  sg = SendGrid::API.new(api_key: ENV['SENDGRID_API_KEY'])
  response = sg.client.mail._('send').post(request_body: mail.to_json)
end

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
      # send success email
      send_mail(show,"Success")
      # delete file from server
      if system("/usr/local/bin/duck -D sftp://#{username}:#{password}@#{host}#{remote_tv_dir}" + show)
        puts "#{show} was deleted from the remote server"
      else
        puts "#{show} failed to be deleted from the remote server"
        # send failure to delete email
        send_mail(show,"Failure to delete")
      end
    else
      puts "there was a problem downloading #{show}"
      # remove failed show from array of to be downloaded to prevent endless loop
      @new_tv_shows = @new_tv_shows - show
      # send general error email
      send_mail(show,"Error")
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
