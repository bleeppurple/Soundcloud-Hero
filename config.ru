require 'rubygems'
gem 'soundcloud-ruby-api-wrapper'
require 'soundcloud'
require 'active_support'
require 'sinatra/base'
require 'ruby-debug'
require "warden"
require "warden_oauth"

  # importing yaml for config settings
  
  CONFIG = YAML::load(File.read('config.yaml'))
  
  

  # example of extentions to helpers for sinatra but could just as easily be any other rack based framework...

module Sinatra
  module Helpers
  
    def authenticate!
      env['warden'].authenticate!
    end
    
    def sc_hero!
      authenticate!
      @SCuser= env['warden'].user
      
      # generate Oauth token's again
      @consumer = OAuth::Consumer.new(
        CONFIG['soundcloud']['oauth']['consumer_key'], 
        CONFIG['soundcloud']['oauth']['consumer_secret'],
        CONFIG['soundcloud']['oauth']['options'] )
       @access_token = OAuth::AccessToken.new(@consumer, @SCuser.token, @SCuser.secret)
       
      # register soundcloud
      @soundcloud = Soundcloud.register({:access_token => @access_token})
    end
    
  end # end module Helpers
end  # end module Sinatra

  # This could easily be an AR/DM table class

class SCUser
  
  attr_accessor :token
  attr_accessor :secret
  attr_accessor :acc_token
  
  def initialize(token, secret)
    @token = token
    @secret = secret    
  end
  
end # end class SCUser

  # NOTE: Normally here you use AR/DM to fetch up the user given an access_token and an access_secret

Warden::OAuth.access_token_user_finder(:soundcloud) do |access_token|
   SCUser.new(access_token.token, access_token.secret)
end

class SinApp < Sinatra::Base

# to start the Oauth process point the user to http://HOST/?warden_oauth_provider=soundcloud'
# E.G. http://localhost:4567/?warden_oauth_provider=soundcloud'

  get '/' do 
 
  sc_hero!
  pp env['warden']
  puts "authenticated"
  puts "trying to call soundcloud"
  @me = @soundcloud.User.find_me
  puts "made call with soundcloud api"
  puts "anything you want!"
  end

end # end class Sinapp

class ErrorApp
  
  def self.call(env)
    if env['warden.options'][:oauth].nil?
      [401, {'Content-Type' => 'text/plain'}, "You are not authenticated"]
    else
      access_token = env['warden.options'][:oauth][:access_token]
      [401, {'Content-Type' => 'text/plain'}, "No user with the given access token"]
    end
  end

end

app = Rack::Builder.new do
  use Rack::Session::Cookie
  use Warden::Manager do |config|
    config.oauth(:soundcloud) do |soundcloud|
      # 
      soundcloud.consumer_key CONFIG['soundcloud']['oauth']['consumer_key']
      soundcloud.consumer_secret CONFIG['soundcloud']['oauth']['consumer_secret']
      soundcloud.options CONFIG['soundcloud']['oauth']['options']   
    end
    config.default_strategies CONFIG['soundcloud']['default_strategies']
    config.failure_app = ErrorApp

  end
  run SinApp

end

run app



