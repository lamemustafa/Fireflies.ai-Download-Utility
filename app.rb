# ADD necessary requirements
require 'net/http'
require 'json'
require 'bundler/inline'
require 'open-uri'
require 'fileutils'
require 'CSV'

# Install additional gems
gemfile do
  source 'https://rubygems.org'
  gem 'dotenv', groups: [:development, :test]
  # gem "progressbar"

  # gems for pdf generation
  gem 'prawn'
  gem 'matrix'

  # gems for docx generation
  gem 'caracal'
end

require 'dotenv/load'
# require 'progressbar'

# For PDF generation
require 'prawn'

# For DOCX generation
require 'caracal'

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
      if video_url
        start_time = Time.now
        URI.open(video_url, "Accept-Encoding" => "gzip, deflate, br") do |content|
          File.open("#{file_name}.mp4", 'wb') do |file|
            file << content.read
          end
        end
        puts "#{Time.now - start_time}"
      end

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

      # Preare and write transcript to json file

      sentences = transcript["sentences"].map do |sentence|
        {
          "sentence"=> sentence["text"],
          "startTime"=> Time.at(sentence["start_time"]).utc.strftime("%M:%S"),
          "endTime"=> Time.at(sentence["end_time"]).utc.strftime("%M:%S"),
          "speaker_name"=> sentence["speaker_name"],
          "speaker_id"=> sentence["speaker_id"]
        }
      end
      
      # Write data to JSON file
      File.open("#{file_name}.json", 'wb') do |file|
        file << sentences.to_json
      end

      # Write data to CSV file
      CSV.open("#{file_name}.csv", "wb") do |csv|
        csv << sentences.first.keys
        sentences.each do |row|
          csv << row.values
        end
      end

      # Preapre and write data to PDF file
      Prawn::Document.generate("#{file_name}.pdf") do
        sentences.each do |sentence|
          speaker = if sentence['speaker_name']
            "#{sentence['speaker_name']}"
          else
            "Speaker #{sentence['speaker_id'].to_i + 1}"
          end

          text "<i>#{speaker}</i> - <b>#{sentence['startTime']}</b>",
          inline_format: true
          move_down 10
          text "#{sentence['sentence']}"
          move_down 10
        end
      end

      # Prepare amd write data to DOCX file
      docx = Caracal::Document.new("#{file_name}.docx")
      sentences.each do |sentence|
        speaker = if sentence['speaker_name']
          "#{sentence['speaker_name']}"
        else
          "Speaker #{sentence['speaker_id'].to_i + 1}"
        end

        docx.p  do
          text sentence['startTime'], bold: true
          br
          text speaker
          br
          text sentence['sentence']
          br
        end

        docx.save
      end

      # Preapare and write data to SRT file
      srt_content = ''
      transcript["sentences"].each_with_index do |sentence, index|
        speaker = if sentence['speaker_name']
          "#{sentence['speaker_name']}"
        else
          "Speaker #{sentence['speaker_id'].to_i + 1}"
        end

        start_time = Time.at(sentence["start_time"]).utc.strftime('%H:%M:%S,%L')
        end_time = Time.at(sentence["end_time"]).utc.strftime('%H:%M:%S,%L')

        srt_content << "#{index + 1}\n"
        srt_content << "#{start_time} --> #{end_time}\n"
        srt_content << "#{speaker}: #{sentence['text']}\n\n"
      end

      File.write("#{file_name}.srt", srt_content)

      # Prepare summary data
      summary = {
        "AI meeting summary:"=>transcript.dig("summary", "overview")&.split("\n"),
        "Action items:"=>transcript.dig("summary", "action_items")&.split("\n\n"),
        "Outline:"=>transcript.dig("summary", "outline")&.gsub(/-\s/, '')&.split("\n").reject(&:empty?),
        "Notes:"=>transcript.dig("summary", "shorthand_bullet")&.gsub(/-\s/, '')&.split("\n").reject(&:empty?)
      }
      
      # Write data to JSON file
      File.open("#{file_name}.summary.json", 'wb') do |file|
        file << summary.to_json
      end
    end
  end
end
