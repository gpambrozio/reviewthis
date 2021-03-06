require 'rubygems'
require 'sinatra'
require 'json'
require 'mustache/sinatra'
require 'pony'

configure do
  set :mustache, {
     :views     => 'views/',
     :templates => 'templates/'
   }
   
  # regex's
  USER = /[^a-z0-9_]@([a-z0-9_]+)\b/i
  REVIEW = /[^a-z0-9_]#review\b/i
  EMAIL = /\b([A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,4})\b/i
end

# production vars
configure :production do
  # only run on Heroku
  set :from, 'development@getarrived.com'
  set :domain, 'getarrived.com'
  set :via, :smtp
  set :via_options, {
    :address        => "smtp.sendgrid.net",
    :port           => "25",
    :authentication => :plain,
    :user_name      => ENV['SENDGRID_USERNAME'],
    :password       => ENV['SENDGRID_PASSWORD'],
    :domain         => ENV['SENDGRID_DOMAIN'],
  }
  
end

# development vars
configure :development, :test do
    set :from, 'reviewthis@localhost'
  set :via, :sendmail
  set :via_options, {}
end

helpers do
  # mail helper. Thnx Pony!
  def mail(vars)
    body = mustache :email, {:layout=>false}, vars
    html_body = mustache :email_html, {:layout=>false}, vars    
    Pony.mail(:to => vars[:email], :from => options.from, :subject => "[#{vars[:repo_name]}] code review request from #{vars[:commit_author]}", :body => body,:html_body => html_body, :via => options.via, :via_options => options.via_options) 
  end
end

# test!
get '/' do
  if !params[:testemail].nil?
    vars = {
      :commit_id => "1234",
      :commit_message => "message",
      :commit_timestamp => 1234,
      :commit_relative_time => "2012-01-01",
      :commit_author => "test",
      :commit_url => "http://github.com",
      :repo_name => "test",
      :repo_url => "http://github.com",
      :username => "test",
      :email => "#{params[:testemail]}@#{options.domain}",
    }
    mail(vars)
  end
  "#reviewthis @github!"
end

# the meat
post '/' do
  push = JSON.parse(params[:payload])
  
  # check every commit, not just the first
  push['commits'].each do |commit|

    message = commit['message']
    
    # we've got a #reviewthis hash
    if message.match(REVIEW)
    
      # set some template vars
      vars = {
        :commit_id => commit['id'],
        :commit_message => message,
        :commit_timestamp => commit['timestamp'],
        :commit_relative_time => Time.parse( commit['timestamp'] ).strftime("%m/%d/%Y at %I:%M%p"),
        :commit_author => commit['author']['name'],
        :commit_url => commit['url'],
        :repo_name => push['repository']['name'],
        :repo_url => push['repository']['url'],        
      }
      
      # Send to our users
      message.scan(USER) do |username|
        vars[:username] = username[0]
        vars[:email] = "#{username[0]}@#{options.domain}"
        mail(vars)
      end
    
      # now let's find any email addresses
      message.scan(EMAIL) do |email|
        vars[:username] = email[0]
        vars[:email] = email[0]
        mail(vars)
      end
  
    end
    
  end
  
  return
end