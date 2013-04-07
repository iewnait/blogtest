set :stages, %w(production sandbox)
set :default_stage, "sandbox"
require 'capistrano/ext/multistage'

set :application, "blogtest"
set :application_path, "/home/deployer/apps/blogtest/current"
set :repository,  "git@github.com:iewnait/blogtest.git"

default_run_options[:pty] = true

set :scm, :git # You can set :scm explicitly or Capistrano will make an intelligent guess based on known version control directory names
# Or: `accurev`, `bzr`, `cvs`, `darcs`, `git`, `mercurial`, `perforce`, `subversion` or `none`
set :deploy_to, "/home/deployer/apps/blogtest"

set :user, "deployer"

set :use_sudo, false

set :rvm_ruby_string, "1.9.3-p327@#{application}"
#set :rvm_install_ruby_params, '--1.9'      # for jruby/rbx default to 1.9 mode
set :rvm_install_pkgs, %w[libyaml openssl] # package list from https://rvm.io/packages
set :rvm_install_ruby_params, '--with-opt-dir=/usr/local/rvm/usr ' # package support

before 'deploy:setup', 'rvm:install_rvm'   # install RVM
before 'deploy:setup', 'rvm:install_pkgs'  # install RVM packages before Ruby
before 'deploy:setup', 'rvm:install_ruby'  # install Ruby and create gemset, or:
before 'deploy:setup', 'rvm:create_gemset' # only create gemset
before 'deploy:setup', 'rvm:import_gemset' # import gemset from file

require "rvm/capistrano"


#set :default_environment, {
#    'RUBY_VERSION' => 'ruby-1.9.3-p327',
#    'LANG'         => 'en_US.UTF-8',
#    'GEM_HOME'     => '/usr/local/rvm/gems/ruby-1.9.3-p327',
#    'GEM_PATH'     => '/usr/local/rvm/gems/ruby-1.9.3-p327:/usr/local/rvm/gems/ruby-1.9.3-p327@global',
#    'BUNDLE_PATH'  => '/usr/local/rvm/gems/ruby-1.9.3-p327:/usr/local/rvm/gems/ruby-1.9.3-p327@global'
#}

#role :web, "ec2-54-241-27-129.us-west-1.compute.amazonaws.com"                          # Your HTTP server, Apache/etc
#role :app, "ec2-54-241-27-129.us-west-1.compute.amazonaws.com"                          # This may be the same as your `Web` server
#role :db,  "ec2-54-241-27-129.us-west-1.compute.amazonaws.com", :primary => true # This is where Rails migrations will run
#role :db,  "ec2-54-241-27-129.us-west-1.compute.amazonaws.com"

namespace :deploy do
  desc "Start the Thin processes"
  task :start do
    run  <<-CMD
      cd #{application_path}; bundle exec thin -e #{rails_env} start -s 4 -P /home/deployer/
    CMD
  end

  desc "Stop the Thin processes"
  task :stop do
    run <<-CMD
      cd #{application_path}; bundle exec thin stop -s 4 -P /home/deployer/; rm ./log; rm -rf ./tmp
    CMD
  end

  desc "Restart the Thin processes"
  task :restart do
    stop
    start
  end

  desc "precompile asset"
  task :precompile_assets do
    run  <<-CMD
      cd #{application_path}; bundle exec rake assets:precompile
    CMD
  end
end

namespace :delayed_job do
  desc "Start the delayed job process"
  task :start do
    run  <<-CMD
      cd #{application_path}; RAILS_ENV=production bundle exec script/delayed_job -n 2 start --pid-dir=/home/deployer/
    CMD
  end

  desc "Stop the delayed job process"
  task :stop do
    run <<-CMD
      cd #{application_path}; RAILS_ENV=production bundle exec script/delayed_job stop --pid-dir=/home/deployer/
    CMD
  end
end

namespace :nginx do
  desc "restart Nginx server"
  task :restart do
    run "#{sudo} mv #{application_path}/config/deploy/nginx_template /etc/nginx/sites-available/#{application}"
    run "#{sudo} ln -fs /etc/nginx/sites-available/#{application} /etc/nginx/sites-enabled/#{application}"
    run "#{sudo} /etc/init.d/nginx restart"
  end
end

namespace :bundle do

  desc "run bundle install and ensure all gem requirements are met"
  task :install do
    run  <<-CMD
      cd /home/deployer/apps/blogtest/current; bundle install
    CMD
  end

end

after "deploy:start", "delayed_job:start"
after "deploy:stop", "delayed_job:stop"
before "deploy:restart", "bundle:install"
before "deploy:restart", "bundle:install"
before "deploy:restart", "deploy:precompile_assets"