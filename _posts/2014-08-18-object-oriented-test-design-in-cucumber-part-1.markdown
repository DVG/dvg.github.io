---
layout: post
title:  "Object Oriented Test Design in Cucumber (Part 1)"
author: DVG
date:   2014-08-18 17:00:00
categories: cucumber testing
---

There lots of advocacy against integration testing out there because over time they become too difficult to maintain and are hard to move with the application. Tests eventually become a burden and teams leave them behind, preferring to go without any sort of safety net to spending time updating capybara calls in 100 tests.

The root of the problem here isn't that integration testing is bad, wasteful or particularly hard, it's that we left all our good ideas about coding in the production codebase when it came time to make our tests.

# Spaghetti Definitions

Take this basic step definition for an example

{% highlight ruby %}
Given(/^I am logged in$/) do
  @user = create(:user)
  click_link "Sign In"
  fill_in "#email", with: @user.email
  fill_in "#password", with: @user.password
  click_button "Sign In"
end
{% endhighlight %}

It works! Then you run `bundle update devise` at some point and suddenly this breaks everywhere because they decided "Log In" was less likely to be confused with "Sign Up". Or maybe someone decides that you should be able to sign in with username or email, and the id of the email field changes to `"#user_identifier"` or something.

Not a big deal the first few times, but as your app grows in size and complexity, it becomes difficult or impossible to keep your tests up to date with changes. You'll start excluded things from the CI build, deleting tests and eventually just manually testing and calling it good.

# Page Objects are your friends

The problem with using capybara or watir-webdriver statements directly in your step definitions is it breaks encapsulation. You're making calls in the global cucumber namespace to implementation details. It may be easier to get going, but make no mistake, it's technical debt.

{% highlight ruby %}
# features/support/pages/sign_in_page.rb
class SignInPage
  include Capybara::DSL
  def email_field
    find("input[id='email']")
  end
  def password_field
    find("input[id='password']")
  end
  def sign_in_button
    find("button[value='Sign In']")
  end

  def sign_in_as(user)
    email_field.set user.email
    password_field.set user.password
    sign_in_button.click
  end
end

# features/step_definitions/authentication_steps.rb
Given(/^I am logged in$/) do
  SignInPage.new.sign_in_as(create(:user))
end
{% endhighlight %}

This is a super simple implementation of a page object. The object now is an *interface* between your test and the actual browser, and your test code just sends it a message on what to do. If a detail changes, you just change the class and the `sign_in_as` message will continue to do the work of signing in.

# Page Object Libraries

In the context of a Rails project with Capybara as the integration testing driver, [Site Prism][site-prism-gh] is really the only game in town. It provides a very simple DSL that will let you build up page objects without a lot of boilerplate methods for creating element accessors.

{% highlight ruby %}
# features/support/pages/sign_in_page.rb
class SignInPage < SitePrism::Page
  element :email_field, "input[id='email']"
  element :password_field, "input[id='password']"
  element :sign_in_button, "button[value='Sign In']"

  def sign_in_as(user)
    email_field.set user.email
    password_field.set user.password
    sign_in_button.click
  end
end
{% endhighlight %}

As you can see, you get Capybara::DSL automatically, and you can use the `element` class method to define you element finders, resulting in a much cleaner class. It has loads of other features, so be sure to checkout their github page.

# Method Chaining

This is great, but sometimes you'll want to do multiple operations on each page. Sometimes it will read nicer to do each of these on their own line, sometime it will be nicer to chain methods.
{% highlight ruby %}
class PostPage < SitePrism::Page
  set_url "/posts{/id}"
  element :reply, "a[id='reply']"
  element :quick_add_comment_body, "#comment_body"
  element :quick_add_comment_submit, "button[value='Add Comment']"
  element :comment_count, "span[id='comment_count']"

  def reply_to_post
    reply.click
  end

  def quick_add_comment(text="WAT")
    quick_add_comment_body.set text
    quick_add_comment_submit.click
  end
end
{% endhighlight %}

Here we have a page object that wraps a reply link and a quick comment form. The reply link will show the quick-reply form. This could be one operation, but we'll show it as two separate steps.

{% highlight ruby %}
When(/^I quick add a comment$/) do
  # assume @post is already populated in then given step
  post_page = PostPage.new.load(id: @post.id)
  post_page.reply
  post_page.quick_add_comment "Hello World"
end
{% endhighlight %}

In this case, since it's one sequence of operations and the methods read cleanly, method chaining would be nice. This is just a matter of returning `self` from the page object

{% highlight ruby %}
class PostPage < SitePrism::Page
  def reply_to_post
    reply.click
    self
  end
end

When(/^I quick add a comment$/) do
  PostPage.new.load(id: @post.id).reply.quick_add_comment "Hello World"
end
{% endhighlight %}

Generally, I have the methods return self if the user is going to remain on the current page. If they will navigate to another page, I return an instance of that page.

{% highlight ruby %}
def sign_in_as(user)
  # sign_in code
  return HomePage.new
end
{% endhighlight %}

# An app class for managing your page instances

As a final tip, as suggested by the site prism wiki, having a class that's responsible for managing your page object instances helps clean up your tests a lot.

{% highlight ruby %}
# features/support/pages/app.rb
class App
  def home_page
    HomePage.new  
  end
end

# features/support/hooks.rb
Before do
  @app = App.new
end

# features/step_definitions/home_steps.rb
Given(/^I am on the home page$/) do
  @app.home_page.load
end
{% endhighlight %}

This also opens up some doors for meta-programming. Personally I don't like defining methods for each page object, but like the accessibility. So I implement something like this:

{% highlight ruby %}
class App
  # Page Object Accessors
  # Converts a method call to a page object class and establishes a new instance
  # @app.home_page    # => HomePage
  # @app.sign_in_page # => SignInPage
  def method_missing(name)
    klass = name.to_s.camelize
    create_page_object_or_raise_error(klass)
  end

private

  def constant_exists?(klass_string)
    Object.const_defined? klass_string
  end

  def create_page_object_or_raise_error(klass_string)
    if constant_exists? klass_string
      return klass_string.constantize.new
    else
      raise StandardError, "There's no page object currently defined called #{klass_string}. Create one under features/support/pages"
    end
  end
end
{% endhighlight %}

This lets me use the same interface of `@app.page_klass_name`, but I don't have to define methods for each one, and it will also fail a test if I try to use a page object I haven't defined yet.

That's all for this introductory post on Object Oriented Testing. Next time we'll cover Test Services

[site-prism-gh]:   https://github.com/natritmeyer/site_prism
