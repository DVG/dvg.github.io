---
layout: post
title: Full Stack Integration Testing with Rails, Ember and Cucumber
author: DVG
comments: true
---

# Full Stack Integration Testing with Rails, Ember and Cucumber

I've been doing a lot of hacking on Ember CLI lately, and it's been a lot of fun. I really like the advantages having a completely separate JS stack brings to the table as opposed to having it embedded in the Rails Asset Pipeline, but along with it comes the question of how to get full-on integration testing done. Most of the approaches to this involve faking the API in some way. Since this in an in-house service that my team also develops, I'd like to have the ability to set up state in the backend and test it on the front-end.

## Developing a Full Stack Cucumber Solution

I know, I know. Some of you don't like Cucumber. I get it. But I happen to like it and I live in a world where we have business analysts who work with us to develop the Gherkin scenarios, so that's what I wanted to use. If you don't want to use it, drop in RSpec or the Integration Testing Tool of your choice.

### Goals

1. The test suite should have the ability to establish backend state like the test suite was the native app. In our case, that means the test suite needs access to the FactoryGirl factories and the Rails Models.
2. The test suite should access the front-end like a real user would, through the browser
3. The test suite will be able to start and stop the stack

## Getting started

For this, I started from scratch, if you just want the cucumber stuff, feel free to skip ahead to the Cucumber section:

```bash
$ mkdir full-stack-cukes && cd full-stack-cukes
$ rails new backend
$ ember new frontend
```

In practice, a git submodule or similar construct would do the trick to reference the existing projects.

## Setting up the Rails Project

My Gemfile looks like this:

```ruby
source 'https://rubygems.org'
gem 'rails', '4.1.5'
gem 'sqlite3'
gem 'spring',        group: :development
gem 'responders'                    # provides respond_to
gem 'active_model_serializers'      # Ember-friendly JSON Formatting
group :development, :test do
  gem 'rspec-rails'
  gem 'factory_girl_rails'
end
```

This is as barebones as it gets without going for Rails-API. Since we aren't going to serve assets from this project we can get rid of all the asset-pipeline stuff. So lets finish getting set up:

```bash
$ bundle install
$ rails g rspec:install
```

### Routes

```ruby
Rails.application.routes.draw do
  namespace :api, defaults: { format: 'json' } do
    resources :posts
  end
end
```

Pretty basic. The `format: 'json'` default lets the responders gem know that anything going to /api will be considered JSON.

### Controller

I didn't bother with any generators here:


```ruby
module Api
  class PostsController < ApplicationController
    respond_to :json
    def index
      respond_with Post.all
    end

  end
end
```

So now we have a JSON api that we can hit at localhost:3000/api/posts, but first we need a model:

### Model

```bash
$ rails g model post title:string body:text
$ rake db:migrate
```

This will give you your basic model, the migration, and the factory since we have factory girl rails installed.

## Ember

With the backend set up, it's time to switch to the frontend folder. I use the following packages to get everything lined up with my preferences:

```bash
$ npm install ember-cli-coffeescript --save-dev
$ npm install ember-cli-emblem --save-dev
$ npm install ember-cli-sass --save-dev
```

"That's a real Railsy stack you've got there". Yeah, I know. I like what I like!

I won't go through the steps I took to switch the auto-generated files to coffeescript and emblem, but you can check it out in the git repo at the end if you like.

### Application Adapater/Serializer

```bash
$ ember generate adapater application
$ ember generate serializer application
```

```coffee
`import DS from 'ember-data'`

ApplicationAdapter = DS.RESTAdapter.extend
  namespace: 'api'

`export default ApplicationAdapter`
```

```coffee
`import DS from 'ember-data'`

ApplicationSerializer = DS.ActiveModelSerializer.extend()

`export default ApplicationSerializer`
```

These just set us up to talk to our backend api

### Model and Route

```bash
$ ember generate model post
$ ember generate route posts
```

```coffee
`import DS from 'ember-data'`

Post = DS.Model.extend
  title: DS.attr()
  body: DS.attr()

`export default Post`
```

```coffee
`import Ember from 'ember'`

PostsRoute = Ember.Route.extend
  model: (params) ->
    @store.find('post')

`export default PostsRoute`
```

### Templates

First the application template:

```emblem
#container.container
  nav.navbar.navbar-default role="navigation"
  .container-fluid
    .navbar-header
      link-to "index" class="navbar-brand"
        | Full Stack
    .collapse.navbar-collapse
      ul.nav.navbar-nav
        li
          link-to "posts"
            | Posts

  outlet
```

And the posts template:

```emblem
each post in controller
  h2 #{post.title}
  p
    post.body
```

## Cucumber Project

So instead of having the features directory embeded in one of the projects, we're choosing to have it as it's own project. The frontend and backend apps are embedded in this. In practice, I have the api and front end installed as git submodules and have a script that pulls down updates, but in the [example project][github-repo], they're just two folders inside of cucumber project.

### Gemfile

So here is the dependency list I ended up with, and what each gem is for:

```ruby
source "https://rubygems.org"

gem "cucumber"            # Human Readable Specification by Example
gem "watir-webdriver"     # Browser Automation
gem 'page-object'         # Page Object Pattern for Watir Webdriver
gem "phantomjs"           # Attempts to install phantom if you don't already have it
gem 'childprocess'        # For managing the running Rails and Ember Apps
gem "activesupport"       # For Autoloading model classes like Rails
gem "activerecord"        # Database Access
gem 'sqlite3'             # The Database Used by the Rails App, change as needed
gem "factory_girl"        # For Creating Fixture Data
gem 'database_cleaner'    # Clean the Database between runs
gem 'rspec-expectations'  # Expectations Library
gem 'byebug'              # Ruby 2.0 Debugging
```

Run `bundle install` to install everything

### Configuration

Since we're going to be connecting to the Rails test database, we're going to need a database.yml file. In practice, I just symlinked the version inside `backend/config/`, however, in this example project, since it uses SQLite, we'll need to give it it's own database.yml so it's relative path will be correct

```yaml
# config/database.yml
test:
  adapter: sqlite3
  pool: 5
  timeout: 5000
  database: backend/db/test.sqlite3
```

Next, I wanted a global configuration object that I could depend on elsewhere in the suite. I settled on this:

```ruby
class Cukes
  require 'active_support/configurable'
  include ActiveSupport::Configurable

  self.configure do |config|
    config.root = Dir[File.dirname(File.expand_path('../', __FILE__))].first
    config.rails_root = File.join(config.root, "backend")
    config.rails_started_message = "WEBrick::HTTPServer#start: pid="
    config.ember_root = File.join(config.root, "frontend")
    config.ember_started_message = "Build successful"
    config.host = "http://localhost:4200"
    config.browser = ENV["BROWSER"] || :phantomjs
    config.startup_timeout = 45
  end

end
```

### Starting Up the Underlying Applications

The rails and ember apps need to be up and running before the cukes start to execute. I originally tried to use the foreman gem to accomplish this, but I ran into trouble where the processes were just orphaned when the cucumber run ended instead of being terminated. So I built my own object to manage it instead using the `childprocess` gem

#### Extending ChildProcess

Child process supports two ways of ending a process, sending it the TERM and KILL signals. In practice, it does both in that order depending on how well it goes. The rails and development servers, however, expect to receive the SIGINT signal to interrupt the process and shut down. So I made a little monkey patch:

```ruby
module ChildProcess
  module Unix
    class Process < AbstractProcess
      def interrupt
        send_signal "SIGINT"
      end
    end
  end
end
```

#### ApplicationManager

So here's the process I went through to build my ApplicationManager object:

```ruby
class ApplicationManager
  require 'childprocess'
  attr_accessor :rails, :ember, :rails_log, :ember_log

  def initialize
    @rails = ChildProcess.build("sh", "-c", "BUNDLE_GEMFILE=Gemfile bundle exec rails s -e test")
    @rails.leader = true
    @rails.cwd = Cukes.config.rails_root
    @rails_log = @rails.io.stdout = @rails.io.stderr = Tempfile.new('rails-log')

    @ember = ChildProcess.build("ember", "serve", "--proxy", "http://localhost:3000")
    @ember.leader = true
    @ember.cwd = Cukes.config.ember_root
    @ember_log = @ember.io.stdout = @ember.io.stderr = Tempfile.new("ember-log")
  end
end
```

This bit: `BUNDLE_GEMFILE=Gemfile` is important because it will make the command use the Rails app's Gemfile instead of defaulting to the one in the cucumber bundle. Otherwise all this code does is set up the commands necessary to run the servers and directs their output to a couple temporary log files.

Now I wanted two messages the instance will accept: `start_stack` and `stop_stack`.

```ruby
  def start_stack
    rails.start
    ember.start
    wait_for_processes_started
  end
```

The `start` method will kick off the processes. However ChildProcess can't really detect when the processes have reached a point where we can start interacting with them. So a private method called `wait_for_processes_started` will monitor the log files to see when they're up

```ruby
  def wait_for_processes_started
    begin
      Timeout::timeout(Cukes.config.startup_timeout) do
        loop { break if processes_started? }
      end
    rescue Timeout::Error => e
      rails.interrupt
      ember.interrupt
      wait_for_processes_to_exit
      raise "Unable to start the application"
    end
  end

  def processes_started?
    open(rails_log).read.include?(Cukes.config.rails_started_message) &&
    open(ember_log).read.include?(Cukes.config.ember_started_message)
  end
```

So this will wait for our configured timeout for the servers to come up. If they don't come up in time, they'll get interrupted. Now for stopping:

```ruby
  def stop_stack
    rails.interrupt
    ember.interrupt
    wait_for_processes_to_exit
  end

  def wait_for_processes_to_exit
    begin
      Timeout::timeout(5) do
        loop { break if rails.exited? && ember.exited? }
      end
    rescue Errno::ESRCH => e
      # Already stopped the process, no biggie
    rescue Timeout::Error => e
      raise "Unable to exit processes. pids: #{rails.pid}, #{ember.pid}"
    end
  end
```

This will bring down the processes when we're done. For the full class, see the [class on github][application-manager]

### env.rb

Okay, now for env.rb. This is the main file that loads our cucumber environment, but don't feel like you need to put everything in here. Everything under support is loaded, so you can break this up into multiple files if you like.

```ruby
require 'factory_girl'
require 'active_record'
require 'database_cleaner'
require 'active_support/dependencies'
require 'page-object'
require 'page-object/page_factory'
require_relative '../../config/cukes'
require_relative './application_manager'
```

So first all our requires. Since this isn't a rails project, you need to require everything by default, or use Bunder.require to do it automatically. I prefer to load everything as needed

#### Reaching into the Rails App

Now we're gonna rely on the enclosed Rails App to use the factory girl factories that are already there, saving us from duplicating the effort

```ruby
# Require Models
ActiveSupport::Dependencies.autoload_paths += Dir.glob File.join(Cukes.config.rails_root, "app/models")
# Require Factories
Dir["#{Cukes.config.rails_root}/spec/factories/*.rb"].each { |f| require f }
```

If your models have class references outside of the models directory, to a Service Object, for example, you may have to autoload more directories. Next, lets connect to the test db:

```ruby
database_yml = File.expand_path('../../../config/database.yml', __FILE__)
if File.exists?(database_yml)
  active_record_configuration = YAML.load_file(database_yml)
  ActiveRecord::Base.configurations = active_record_configuration
  config = ActiveRecord::Base.configurations['test']
  ActiveRecord::Base.establish_connection(config)
else
  raise "Please create #{database_yml} first to configure your test database"
end
```

#### Bring up the Stack

Now we use our ApplicationManager object to bring up the servers:

```ruby
manager = ApplicationManager.new
manager.start_stack
at_exit do
  manager.stop_stack
end
```

Finally, we just need to do some normal configuration for database cleaner, page object and factory girl:

```ruby
# Database Cleaner to clear out the test DB between tests
require 'database_cleaner/cucumber'
DatabaseCleaner.strategy = :truncation
Around do |scenario, block|
    DatabaseCleaner.cleaning(&block)
end

# Page Object Stuff
PageObject.javascript_framework = :jquery # Ember uses Jquery Under the hood
World(PageObject::PageFactory)

# Shorthand FactoryGirl
include FactoryGirl::Syntax::Methods
```

You can see the [full file][env] at Github

### posts.feature

Here is our simple feature:

```gherkin
Feature: Posts

  Scenario: List of Posts
    Given a post exists titled "Hello World!"
    When I visit the list of psots
    Then I should see a post titled "Hello World!"

  Scenario: Create a post
    Given no posts exist
    When I create a post titled "Orange is the New Black"
    Then I should see a post titled "Orange is the New Black"
```

Let's automate this!

```ruby
Given(/^a post exists titled "(.*?)"$/) do |title|
  create(:post, title: title)
end

Given(/^no posts exist$/) do
  # Nothing to do!
end

When(/^I visit the list of psots$/) do
  visit PostsIndex
end

When(/^I create a post titled "(.*?)"$/) do |title|
  visit PostsNew
  on PostsNew do |page|
    page.create_post(title: title, body: "Some Body")
  end
end

Then(/^I should see a post titled "(.*?)"$/) do |title|
  on PostsIndex do |page|
    page.wait_for_ajax
    expect(page).to have_a_post_titled(title)
  end
end
```

We're using the PageObject gem and WatirWebdriver to automate these examples. The PageObjects themselves are pretty simple, the only thing I think is worth pointing out for testing an Ember App is using the `intialize_page` hook to wait for ajax to complete:

```ruby
class PostsNew
  include PageObject
  page_url "#{Cukes.config.host}/posts/new"

  def initialize_page
    wait_for_ajax
  end
end
```

That's pretty much it. With all this in place we now have full stack integration testing with Rails and Ember. I hope the ideas here can help you out in your own testing.

[github-repo]:   https://github.com/DVG/full-stack-cukes
[application-manager]: https://github.com/DVG/full-stack-cukes/blob/master/features/support/application_manager.rb
[env]: https://github.com/DVG/full-stack-cukes/blob/master/features/support/env.rb
