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

For this, I started from scratch:

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
