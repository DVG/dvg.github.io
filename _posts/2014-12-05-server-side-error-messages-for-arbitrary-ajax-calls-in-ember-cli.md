---
layout: post
title: Server Side Error Messages for Arbitrary Ajax Calls in Ember CLI
author: DVG
comments: true
---

Ember Data provides a lot of convenience when dealing with persistant objects, but in any application with a scope larger than a CRUD you'll eventually need to make an arbitrary ajax request of some kind that doesn't match up well with Ember Data.

Consider the following [Ember Simple Auth][ember-simple-auth] authenticator:

```coffeescript
`import Ember from 'ember'`
`import Base from 'simple-auth/authenticators/base'`
`import ENV from '../config/environment'`
 
CustomAuthenticator = Base.extend
  authenticate: (options) ->
    self = @
    new Ember.RSVP.Promise (resolve, reject) ->
      self.makeRequest(options).then ((response) ->
        Ember.run ->
          # Handle success
      ), (xhr, status, error) ->
        Ember.run ->
          reject xhr.responseJSON or xhr.responseText

  makeRequest: (data, resolve, reject) ->
    Ember.$.ajax
      url: "/api/v1/sessions"
      type: 'POST'
      data: data
      dataType: 'json'
```

If the user doesn't successfully authenticate, we want to tell them what went wrong. For example, if they sent a blank form, they may get back something like this:

```json
{
  errors: {
    base: ["Access Denied"],
    username: ["can't be blank"],
    password: ["can't be blank"]
  }
}
```

If this was an ember data `save()` call with the ActiveModelAdapter, we could use [DS.Errors][ds-errors] to handle the errors. I want to make a simple object that exposes a similar interface. Namely:

1. Should be able to get errors via errors.fieldName
2. Should be able to get a list of all errors via errors.messages
3. Both should be arrays of objects with a message property
4. Everything should quack like an Ember Object

## Getting Started on the SimpleErrors Object

For simplicity, I want to just be able to assign the json response to the SimpleErrors object, like so:

```coffeescript
authenticate: ->
  self = @
  @_super()
  .then null, (error) =>
    self.set 'errors', SimpleErrors.create(error)
```

This will, in effect set the "errors" property on the SimpleErrors object to the JSON Response. However it will be a normal Javascript Object and not an Ember.Object. Let's fix that:

```coffeescript
SimpleError = Ember.Object.extend
  init: ->
    @set('emberized_errors', Ember.Object.create(@get('error')))
```

Now we've made another local property to hold the Ember Object equivalent of the errors object.

### Getting Errors for Properties
  
DS.Errors exposes individual fields error messages by looking them up as properties. However we don't know ahead of time what the errors are going to be. So we need a method to lookup errors for arbitrary properties. Fortunately, ember exposes `unknownProperty` which works a bit like ruby's `method_missing`

```coffeescript
unknownProperty: (key) ->
  errors = @_errorsFor(key)
  arr = Ember.A([])
  errors.map (item) ->
    arr.pushObject
     message: item
  arr

_errorsFor: (property) ->
  Ember.A @get('emberized_errors').get(property)
```

Now we can look up error message associated with arbitray properties. Which means you can display property error messages just like explained in the DS.Errors documentation:

{% highlight html %}
{% raw %}
<label>Username: {{input value=username}} </label>
{{#each errors.username}}
  <div class="error">
    {{message}}
  </div>
{{/each}}
{% endraw %}
{% endhighlight %}

### Displaying all messages

We still need the capability to return all error messages, for this we will use a computed property:

```coffeescript
messages: (->
  errors = @get('errors')
  allErrors = []
  for own prop, value of errors
    allErrors = allErrors.concat errors[prop]
  @_generateMessages(allErrors)
).property('errors')

# Allows you to look up arbitrary errors
unknownProperty: (key) ->
  errors = @_errorsFor(key)
  @_generateMessages(errors)

_generateMessages: (array) ->
  arr = Ember.A([])
  array.map (item) ->
    arr.pushObject
      message: item
  arr
```

Here we moved generating the messages objects into it's own method, and we build a full list of errors from the errors supplied initially. Now we have the flexible interface that can be use for any arbitrary ajax call.

Another extension to this might be a fullMessages computed property that automatically prepends the property name to the message ala rails, but I'm pretty happy with this approach. The full class is below, I hope you found this useful

```coffeescript
`import Ember from 'ember'`

SimpleError = Ember.Object.extend
  # errors should be assigned a json object with the errors
  # errors:
  #   base: ["Access Denied"]
  #   username: ["can't be blank"]
  #   password: ["can't be blank"]

  messages: (->
    errors = @get('errors')
    allErrors = []
    for own prop, value of errors
      allErrors = allErrors.concat errors[prop]
    @_generateMessages(allErrors)
  ).property('errors')

  # Allows you to look up arbitrary errors
  unknownProperty: (key) ->
    errors = @_errorsFor(key)
    @_generateMessages(errors)

  _errorsFor: (property) ->
    Ember.A @get('emberized_errors').get(property)

  _generateMessages: (array) ->
    arr = Ember.A([])
    array.map (item) ->
      arr.pushObject
        message: item
    arr

  init: ->
    @set('emberized_errors', Ember.Object.create(@get('errors')) )

`export default SimpleError`
```

[ds-errors]: http://emberjs.com/api/data/classes/DS.Errors.html
[ember-simple-auth]: https://github.com/simplabs/ember-simple-auth

