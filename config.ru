require 'rubygems'
gem 'soundcloud-ruby-api-wrapper'
require 'soundcloud'
require 'active_support'
require 'sinatra/base'
require 'ruby-debug'
require "warden"
require "warden_oauth"

  # example of extentions to helpers for sinatra but could just as easily be any other rack based framework...

module Sinatra
  module Helpers
  
    def authenticate!
      env['warden'].authenticate!
    end
    
    def sc_hero!
      authenticate!
      @sc= env['warden'].user
      @sc.acc_token
      @soundcloud = Soundcloud.register({:access_token => @sc.acc_token})
    end
    
  end # end module Helpers
end  # end module Sinatra

  # This could easily be an AR/DM table class

class SCUser
  
  attr_accessor :token
  attr_accessor :secret
  attr_accessor :acc_token
  
  def initialize(token, secret, object)
    @token = token
    @secret = secret
    @acc_token = object    
  end
  
end # end class SCUser

  # NOTE: Normally here you use AR/DM to fetch up the user given an access_token and an access_secret
  #       the full access_token object has been included (3rd arg) as a hack untill I get more familar with warden
  #       this mucks up the warden user auth a bit and it may not hold between sessions
  #       It will work between sessions if the user object only has a access token and access secret 
  #       --- not an access object
  #       ie.  SCUser.new(access_token.token, access_token.secret) works 

Warden::OAuth.access_token_user_finder(:soundcloud) do |access_token|
   SCUser.new(access_token.token, access_token.secret, access_token)
end

class SinApp < Sinatra::Base

# to start the Oauth process point the user to http://HOST/?warden_oauth_provider=soundcloud'
# E.G. http://localhost:4567/?warden_oauth_provider=soundcloud'

  get '/' do  
  sc_hero!
  puts "authenticated"
  puts "trying to call soundcloud"
  @me = @soundcloud.User.find_me
  puts "made call with soundcloud api"
  #do anything you want!
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
      soundcloud.consumer_key "YOUR KEY"
      soundcloud.consumer_secret "YOUR SECRET"
      soundcloud.options :site => 'http://api.soundcloud.com',
        :request_token_path => "/oauth/request_token",
        :access_token_path => "/oauth/access_token",
        :authorize_path => "/oauth/authorize",
        :scheme => :query_string
      #debugger   
    end
    config.default_strategies :soundcloud_oauth
    config.failure_app = ErrorApp

  end
  run SinApp

end

run app



