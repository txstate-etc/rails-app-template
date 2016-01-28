# Rails app template for Texas State ETC.
# 

FILES_PATH = File.join(File.expand_path(File.dirname(__FILE__)),'files')

def source_paths
  [FILES_PATH] + Array(super)
end

def get_user_info
  values = ['netID', 'first name', 'last name'].map do |prompt|
    ask("#{prompt}: ").strip.tap { |v| return unless v.present?}
  end
  "login: '#{values[0]}', admin: true, first_name: '#{values[1]}', last_name: '#{values[2]}'"
end

#-------------------------------------------#
# Stuff we need to prompt for.
# Save the results locally, so we only have to do it once. 
#-------------------------------------------#
SEEDS_PATH = File.join(FILES_PATH, 'db', 'seeds.rb')
unless File.exist?(SEEDS_PATH)
  puts
  say 'Enter your netID and name to be seeded into the database.'
  say 'You won\'t be able to log in through CAS without it.'
  say 'You can create as many users as you want.'
  say 'Press ENTER when finished...'
  while true
    user = get_user_info
    break unless user.present? 
    create_file SEEDS_PATH unless File.exist?(SEEDS_PATH)
    append_to_file SEEDS_PATH, "User.create(#{user})\n"
    say "Appended 'User.create(#{user})' to seeds.rb."
    say 'Enter another user or press ENTER if finished...'
  end
end


#-------------------------------------------#
# .hgignore / .gitignore - delete the one you don't use
#-------------------------------------------#
append_to_file '.gitignore', 'config/secrets.yml'
copy_file '.hgignore'


#-------------------------------------------#
# Gemfile 
#-------------------------------------------#

# Specify required ruby version
insert_into_file 'Gemfile', "\nruby '#{RUBY_VERSION}'", after: "source 'https://rubygems.org'\n"

# Remove gems we don't use
gsub_file "Gemfile", /^.*coffee.*$/i,''

# Uncomment gems we do use
uncomment_lines "Gemfile", /therubyracer/ 
uncomment_lines "Gemfile", /capistrano-rails/ 

# Install common gems
gem 'omniauth-cas', :github => 'txstate-etc/omniauth-cas', :ref => 'c2c538c371'
gem 'exception_notification'
gem 'whenever', require: false
gem 'daemons', require: false
gem 'delayed_job'
gem 'delayed_job_active_record'

gem_group :development do
  gem 'thin'
  gem 'capistrano-passenger', require: false
  gem 'rvm1-capistrano3', require: false
end

gem_group :deploy do
  gem 'passenger', require: false
end

run 'bundle install'

#-------------------------------------------#
# User controller/models
#-------------------------------------------#
generate 'scaffold', 'user login:uniq first_name last_name admin:boolean --no-stylesheets'
inject_into_class 'app/models/user.rb', "User", "def full_name; \"\#{first_name} \#{last_name}\"; end\n"
inject_into_class 'app/models/user.rb', "User", "has_many :auth_sessions\n"


#-------------------------------------------#
# Authentication controller/models
#-------------------------------------------#
generate 'model', 'auth_session credentials:uniq user:references'
copy_file 'app/controllers/auth_sessions_controller.rb'
copy_file 'app/models/auth_session.rb', force: true


#-------------------------------------------#
# Application controller/layout
#-------------------------------------------#
inside 'app/controllers' do 
  copy_file 'application_controller.rb', force: true
end

inside 'app/views/layouts' do 
  insert_into_file 'application.html.erb', after: "<head>\n" do 
      <<-EOF
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta charset="UTF-8">
<link rel="icon" type="image/png" sizes="64x64" href="<%= asset_path 'favicon.png' %>">
<link rel="apple-touch-icon" href="<%= asset_path 'touchicon.png' %>">
      EOF
  end

  insert_into_file 'application.html.erb', after: "<body>\n" do 
      <<-EOF
<h1>#{app_name.titleize}</h1>

<div id="user-info">
  <% if current_user.present? %>
    logged in as <%= current_user.full_name %>. (<%= link_to "logout", logout_path %>)
  <% elsif cas_user.present? %>
    logged in as <%= cas_user %>. (<%= link_to "logout", logout_path %>)      
  <% else %>
    <%= link_to "login", login_path %>
  <% end %>
</div>
      EOF
  end

  gsub_file 'application.html.erb', %r{</title>},  ' : Texas State University</title>'
end

directory 'app/assets/images'

#-------------------------------------------#
# Lib
#-------------------------------------------#
directory 'lib'


#-------------------------------------------#
# Public
#-------------------------------------------#
inside 'public' do
  uncomment_lines 'robots.txt', /User-agent: \*/
  uncomment_lines 'robots.txt', /Disallow: \//
end


#-------------------------------------------#
# Config
#-------------------------------------------#
inside 'config' do

  # application.rb
  application "config.active_job.queue_adapter = :delayed_job\n"
  application "config.time_zone = 'Central Time (US & Canada)'\n"
  application do
    <<-EOF
config.action_mailer.smtp_settings = {
      address: Rails.application.secrets.smtp_host,
      domain: Rails.application.secrets.domain_name
    }
    EOF
  end

  # environments
  inside 'environments' do
    
    # development.rb
    comment_lines 'development.rb', /config.action_mailer.raise_delivery_errors/
    environment nil, env: 'development' do
      <<-EOF
      
  # ActionMailer Config
  config.action_mailer.default_url_options = { :host => 'localhost', :port => DEFAULT_SERVER_PORT }
  config.action_mailer.delivery_method = :smtp
  config.action_mailer.raise_delivery_errors = true
  config.action_mailer.perform_deliveries = true
      EOF
    end

    # production.rb
    environment nil, env: 'production' do
      <<-EOF

  # ActionMailer Config
  config.action_mailer.default_url_options = { :host => Rails.application.secrets.host_name }
  config.action_mailer.delivery_method = :smtp
  config.action_mailer.perform_deliveries = true
  config.action_mailer.raise_delivery_errors = false

  # ExceptionNotification Config
  Rails.application.config.middleware.use ExceptionNotification::Rack,
  :email => {
    :email_prefix => "[#{app_name.titleize}] ",
    :sender_address => %{"#{app_name.titleize} Error" <nobody@\#{Rails.application.secrets.domain_name}>},
    :exception_recipients => Rails.application.secrets.exception_recipients
  }
      EOF
    end


    # staging.rb
    create_file 'staging.rb' do
      <<-EOF
# Based on production defaults
require Rails.root.join("config/environments/production")

Rails.application.configure do
  # Put any custom staging settings here.
end
      EOF
    end

  end

  # initializers
  directory 'initializers'

  # boot.rb
  append_to_file 'boot.rb' do
    <<-EOF

DEFAULT_SERVER_PORT = #{rand(3001..7999)}

# set default port for dev server
require 'rails/commands/server'
module Rails
  class Server
    def default_options
      super.merge({
        :Port => DEFAULT_SERVER_PORT
      })
    end
  end
end
    EOF
  end

  # database.yml
  template 'database.yml', force: true

  # secrets.yml
  template 'secrets.yml.sample'
  template 'secrets.yml.sample', 'secrets.yml', force: true
  gsub_file "secrets.yml", /secret_key_base: .*$/i do 
    "secret_key_base: #{app_secret}"
  end
  
  # whenever
  copy_file 'schedule.rb'

  # routes.rb
  route "get '/auth/:provider/callback', to: 'auth_sessions#create'"
  route "get '/logout', to: 'auth_sessions#destroy', as: 'logout'"
  route "get '/login/error' => 'auth_sessions#error', :as => :authentication_error"
  route "root 'users#index'"

end


#-------------------------------------------#
# Capistrano
#-------------------------------------------#
run 'bundle exec cap install'

# Capfile
prepend_to_file 'Capfile' do 
  <<-EOF
# Monkey patch DSL to set default roles on servers
module Capistrano
  module DSL
    def server(name, properties={})
      properties[:roles] = %w{web app db} unless properties.key? :roles
      super(name, properties)
    end
  end
end
  EOF
end

uncomment_lines 'Capfile', /'capistrano\/bundler'/
uncomment_lines 'Capfile', /capistrano\/rails\/assets/
uncomment_lines 'Capfile', /capistrano\/rails\/migrations/
uncomment_lines 'Capfile', /'capistrano\/passenger'/
insert_into_file 'Capfile', "require 'rvm1/capistrano3'\n", before: "\n# Load custom tasks"
insert_into_file 'Capfile', "require 'whenever/capistrano'\n", before: "\n# Load custom tasks"

# deploy/*.rb
inside 'config/deploy' do
  create_file 'production.rb', "server 'ruby-stack.its.txstate.edu'\n", force: true
  create_file 'staging.rb', "server 'ruby-stack.staging.its.txstate.edu'\n", force: true
end

# deploy.rb
inside 'config' do
  gsub_file "deploy.rb", /my_app_name/i, app_name
  gsub_file "deploy.rb", %r{'git@example.com:me/my_repo.git'}, '"https://github.com/txstate-etc/#{fetch(:application)}"'
  gsub_file "deploy.rb", /namespace :deploy do.*?\nend\n/m, ''

  append_to_file 'deploy.rb' do
    <<-'EOF'

set :user, 'rubyapps'

set :ssh_options, { user: fetch(:user) }

# Set rvm version to the same as we use in development
set :rvm1_ruby_version, "ruby-#{IO.read('Gemfile').match(/^ruby '([^']+)'$/)[1]}@#{IO.read('.ruby-gemset').chomp}"

# Default deploy_to directory is /var/www/my_app
set :deploy_to, "/home/#{fetch(:user)}/#{fetch(:application)}"

set :passenger_restart_with_touch, true

set :linked_files, %w{config/secrets.yml}
set :linked_dirs, %w{backups log tmp/pids public/system}

before 'deploy', 'rvm1:install:rvm'
before 'deploy', 'rvm1:install:ruby'
before 'deploy', 'rvm_local:alias:create'
after 'deploy:publishing', 'delayed_job:restart'

    EOF
  end
end


#-------------------------------------------#
# Delayed Job
#-------------------------------------------#
generate 'delayed_job:active_record'


#-------------------------------------------#
# Create the database
#-------------------------------------------#
if File.exist?(SEEDS_PATH)
  inside 'db' do
    copy_file 'seeds.rb', force: true
  end
end

rake 'db:migrate:reset db:seed'
