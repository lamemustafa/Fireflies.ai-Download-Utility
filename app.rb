# ADD necessary requirements
require 'net/http'
require 'json'
require 'bundler/inline'
require 'open-uri'
require 'fileutils'

# Install additional gems
gemfile do
  source 'https://rubygems.org'
  gem 'dotenv', groups: [:development, :test]
  # gem "progressbar"
end

require 'dotenv/load'
# require 'progressbar'

# Fireflies.ai supports GraphQL, thus the required grapghql query to fetch
# data via POST API call
query = """
query Transcripts(
        $limit: Int
        $skip: Int
    ) {
        transcripts(
          limit: $limit
          skip: $skip
        ) {
            id
            sentences {
              index
              speaker_name
              speaker_id
              text
              raw_text
              start_time
              end_time
              ai_filters {
                task
                pricing
                metric
                question
                date_and_time
                text_cleanup
                sentiment
              }
            }
            title
            host_email
            organizer_email
            user {
              user_id
              email
              name
              num_transcripts
              recent_meeting
              minutes_consumed
              is_admin
              integrations
            }
            fireflies_users
            participants
            date
            transcript_url
            audio_url
            video_url
            duration
            meeting_attendees {
              displayName
              email
              phoneNumber
              name
              location
            }
            summary {
              action_items
              keywords
              outline
              overview
              shorthand_bullet
            }
          }
      }
"""

# Base request parameters
base_url = "https://api.fireflies.ai"
path = "/graphql"
endpoint = "#{base_url}#{path}"
parsed_uri = URI.parse(endpoint)
authorization_token = "Bearer #{ENV['FIREFLIES_API_KEY']}"

# Post request definition
req = Net::HTTP::Post.new(
  parsed_uri.path,
  {
    'Authorization': authorization_token,
    'Content-Type': 'application/json'
  }
)

req.body = {
  "query": query,
  "variables": {
    "limit": 1,
    "skip": 0
  }
}.to_json

# Persistent connection to fetch data
res = Net::HTTP.start(
  parsed_uri.host,
  parsed_uri.port,
  use_ssl: true
) do |http|
    res = http.request(req)
end

puts "Response code is #{res.code}"

# Root directory for downloads
base_path = "."

# Execute when a valid response is fetched
if res.code == "200"
  data = JSON.parse(res.body).dig("data","transcripts")
  # Execute when transcripts data is available
  unless data.empty?
    data.each do |transcript|
      # Parsed fields from response
      audio_url = transcript["audio_url"]
      video_url = transcript["video_url"]
      meeting_timestamp = transcript["date"]
      file_title = transcript["title"]

      # Directory and filename based on response
      file_timestamp = "#{
        Time.at(meeting_timestamp/1000).strftime('%Y-%m-%d/%H:%M:%S.%3N')
        }" if meeting_timestamp
      
      directory = if file_timestamp.empty?
        "#{base_path}/downloads"
      else
        "#{base_path}/#{file_timestamp}"
      end

      file_name = "#{directory}/#{file_title}"

      # Create directory if doesn't exist
      FileUtils.mkdir_p(directory) unless File.directory?(directory)

      # Download the audio file
      if audio_url
        start_time = Time.now
        URI.open(audio_url, "Accept-Encoding" => "gzip, deflate, br") do |content|
          File.open("#{file_name}.mp3", 'wb') do |file|
            file << content.read
          end
        end
        puts "#{Time.now - start_time}"
      end

      # Download the video file
      # if video_url
      #   start_time = Time.now
      #   URI.open(video_url, "Accept-Encoding" => "gzip, deflate, br") do |content|
      #     File.open("#{file_name}.mp4", 'wb') do |file|
      #       file << content.read
      #     end
      #   end
      # end

      ## Experiment with Net/Http file download 
      # start_time = Time.now
      # begin
      #   parsed_uri = URI.parse(video_url)
      #   Net::HTTP.start(
      #     parsed_uri.host,
      #     parsed_uri.port,
      #     use_ssl: true
      #   ) do |http|
      #     request = Net::HTTP::Get.new parsed_uri
      #     request["Accept-Encoding"] = "gzip, deflate, br"
      #     http.request(request) do |response|
      #       File.open("video6.mp4", "wb") do |file|
      #         response.read_body do |chunk|
      #           file.write chunk
      #         end
      #       end
      #     end
      #   end    
      # rescue StandardError => e
      #   puts e.inspect
      # end
      # puts "#{Time.now - start_time}"
    end
  end
end
