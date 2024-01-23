
require 'net/http'
require 'json'
require 'bundler/inline'

gemfile do
  source 'https://rubygems.org'
  gem 'dotenv', groups: [:development, :test]
end

require 'dotenv/load'

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

base_url = "https://api.fireflies.ai"
path = "/graphql"
endpoint = "#{base_url}#{path}"

parsed_uri = URI.parse(endpoint)

authorization_token = "Bearer #{ENV['FIREFLIES_API_KEY']}"
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


res = Net::HTTP.start(
  parsed_uri.host,
  parsed_uri.port,
  use_ssl: true
) do |http|
    res = http.request(req)
end

puts res.inspect
