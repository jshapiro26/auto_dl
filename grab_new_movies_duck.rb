#### Rewrite for duck.sh
require 'pry-nav'
require 'yaml'
require 'dotenv'
require_relative 'DownloadProgress'
Dotenv.load

Encoding.default_external = Encoding::UTF_8
Encoding.default_internal = Encoding::UTF_8

# Set vars from .env
remote_movie_dir = ENV['REMOTE_MOVIE_DIR']
local_movie_dir = ENV['LOCAL_MOVIE_DIR']
host = ENV['HOST']
username = ENV['USERNAME']
password = ENV['PASSWORD']

start = Time.now
puts "Started script at #{start}"

# Load list of movies already downlaoded; if the list doesn't exist create an empty array
if File.exist?('downloaded_movies.yaml')
  @downloaded_movies = YAML.load_file('downloaded_movies.yaml')
else
  @downlaoded_movies = []
end

# Get list of movies in directory
movies = `/usr/local/bin/duck -l sftp://#{username}:#{password}@#{host}#{remote_movie_dir}`.split
@new_movies = []
movies.each do |movie|
  if movie.end_with? ".mkv"
    @new_movies << movie
  end
end

# Determine Movies to download
to_download = @new_movies - @downloaded_movies

until @new_movies - @downloaded_movies == []
  puts "Will download the following movies #{to_download}"
  to_download.each do |movie|
    puts "downloading #{movie} to #{local_movie_dir}"
    # if the movie downloads, add the movie to the downloaded_movie hash; overwrite file if it exists already; surpress progress output
    if system("/usr/local/bin/duck -e overwrite -d sftp://#{username}:#{password}@#{host}#{remote_movie_dir}" + movie + " " + local_movie_dir)
      puts "The Movie: #{movie} downloaded successfully"
      @downloaded_movies << movie
      # delete file from server
      if system("/usr/local/bin/duck -D sftp://#{username}:#{password}@#{host}#{remote_movie_dir}" + movie)
        puts "#{movie} was deleted from the remote server"
      else
        puts "#{movie} failed to be deleted from the remote server"
      end
    else
      puts "there was a problem downloading #{movie}"
    end
  end
  puts "all up-to-date"
end

# Overwrite list of downloaded movies with updated array
File.open('downloaded_movies.yaml', "w+") do |file|
  file.write(@downloaded_movies.to_yaml)
end

finish = Time.now
puts "Finished script at #{finish}. Took #{finish - start} to complete"
