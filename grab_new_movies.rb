require 'net/sftp'
require 'pry-nav'
require 'yaml'
require 'dotenv'
require_relative 'DownloadProgress'
Dotenv.load

# Load list of movies already downlaoded; if the list doesn't exist create an empty array
if File.exist?('downloaded_movies.yaml')
  @downloaded_movies = YAML.load_file('downloaded_movies.yaml')
else 
  @downlaoded_movies = []
end
# Set vars from .env
remote_movie_dir = ENV['REMOTE_MOVIE_DIR']
local_movie_dir = ENV['LOCAL_MOVIE_DIR']
host = ENV['HOST']
username = ENV['USERNAME']
password = ENV['PASSWORD']

Net::SFTP.start(host, username, :password => password ) do |sftp|
  # List items in Movies directory; add to array
  @movies = []
  sftp.dir.foreach(remote_movie_dir) do |entry|
    if entry.name.end_with? ".mkv"
      @movies << entry.name
    else
      puts "ignoring #{entry.name}"
    end
  end

  # Compare movies in remote dir to list of downlaoded movies
  to_download = @movies - @downloaded_movies
  # download all movies that haven't been downloaded; add to downloaded hash
  until @movies - @downloaded_movies == []
    to_download.each do |movie|
      # if the movie downloads, add the movie to the downloaded_movie hash
      if sftp.download!(remote_movie_dir + movie, local_movie_dir + movie, :read_size => 65536, :progress => DownloadProgress.new)
        @downloaded_movies << movie
        # delete file from server
      else
        puts "there was a problem downloading #{movie}"
      end
    end
    puts "all up-to-date"
  end
end

# Overwrite list of downloaded movies with updated array
File.open('downloaded_movies.yaml', "w+") do |file|
  file.write(@downloaded_movies.to_yaml)
end
 