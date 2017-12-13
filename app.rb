require 'twilio-ruby'
require 'sinatra'
require 'sinatra/json'
require 'dotenv'
require 'faker'
require 'patron'
require 'pry'

# Load environment configuration
Dotenv.load

set :public_folder, File.dirname(__FILE__) + '/public'


# Render home page
get '/' do
  redirect '/backoffice/index.html'
#  File.read(File.join('public', 'index.html'))
end

# Generate a token for use in our Video application
get '/token' do
  # Create a random username for the client
  identity = Faker::Internet.user_name.gsub(/[^0-9a-z_]/i, '')

  capability = Twilio::JWT::ClientCapability.new ENV['TWILIO_ACCOUNT_SID'],
    ENV['TWILIO_AUTH_TOKEN']
  # Create an application sid at
  # twilio.com/console/phone-numbers/dev-tools/twiml-apps and use it here
  outgoing_scope = Twilio::JWT::ClientCapability::OutgoingClientScope.new(ENV['TWILIO_TWIML_APP_SID'])
  incoming_scope = Twilio::JWT::ClientCapability::IncomingClientScope.new('test-client-name')
  capability.add_scope(outgoing_scope)
  capability.add_scope(incoming_scope)

  # Generate the token and send to client
  json :identity => identity, :token => capability.to_jwt
end

post '/voice' do
  twiml = Twilio::TwiML::VoiceResponse.new do |r|
    if params['To'] and params['To'] != ''
      r.dial(record: "record-from-answer-dual",
             caller_id: ENV['TWILIO_CALLER_ID']) do |d|
        # wrap the phone number or client name in the appropriate TwiML verb
        # by checking if the number given has only digits and format symbols
        if params['To'] =~ /^[\d\+\-\(\) ]+$/
          d.number(params['To'])
        else
          d.client(params['To'])
        end
      end
    else
      r.say("Thanks for calling!")
    end
  end

  content_type 'text/xml'
  twiml.to_s
end

post '/transcript' do
  json = JSON.parse(params.fetch("AddOns"))
  url = ["results", "voicebase_transcription", "payload",
         0, "url"].reduce(json) {|m, p| m.fetch(p) }
  uri = URI.parse(url)
  auth = [ENV.fetch("TWILIO_ACCOUNT_SID"),
          ENV.fetch("TWILIO_AUTH_TOKEN")]
  headers = {'User-Agent' => 'acdc/0.1'}
  patron = Patron::Session.new(timeout: 20,
                               connect_timeout: 20,
                               username: ENV.fetch("TWILIO_ACCOUNT_SID"),
                               password: ENV.fetch("TWILIO_AUTH_TOKEN"),
                               base_url: uri.merge('/'),
                               headers: headers )
  xcript = JSON.parse(patron.get(uri.path).body)
  IO::File.open("/tmp/transcript/#{Time.new.to_i}","w") do |f|
    f.write(xcript.to_json)
  end
  "OK"
end
