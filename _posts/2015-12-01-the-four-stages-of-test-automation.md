---
layout: post
title: The Four Stages of Test Automation
author: DVG
tags: cucumber testing
comments: true
---

<blockquote class="twitter-tweet" lang="en"><p lang="en" dir="ltr">the final stage of grieving is called &quot;acceptance&quot;, which is where the term &quot;acceptance testing&quot; comes from</p>&mdash; Benjamin Winkler (@abwinkler999) <a href="https://twitter.com/abwinkler999/status/668822461929103360">November 23, 2015</a></blockquote>
<script async src="//platform.twitter.com/widgets.js" charset="utf-8"></script>

I've had a lot of people ask me over the years how to get into automated testing. Some of them are developers who want to test their own code, others are non-technical testers or analysts who want to break into test engineering.

Automated Testing was my first job out of college and I did it for a long time. My understanding of how to best accomplish it changed over time and experience, and while you can't substitute a blog post for experience, knowing what the different stages look like might help you move through them faster. I've come to think of these things as the **Four Stages of Test Automation**

## Prerequisites

To work the example you need:

1. A reasonably current version of ruby
2. Git installed
3. Chrome

## Getting Started

This will be a practical lesson. If you want to follow along, you can get the getting started project at [Github][fake-amazon].

This project is a simplified version of Amazon. It will let you add products to your cart, Input shipping addresses and payment methods and finally check out. I made this up because shopping carts are a great way to demonstrate edge cases.

Once you clone the project, you just need to run:

```bash
$ bundle install
$ bin/rake db:migrate
$ bin/rake db:seed
$ bin/rails s
```

## Stage One: Simple Scripted Actions

Look at the test folder, and you can see we have a test script set up and ready to go. Based on the title we're going to test checking out with more than $35 worth of merch in our cart. Let's run it and see what happens. In a different terminal window than your application server:

```bash
$ ruby test/001_checkout_over_35_dollars.rb
```

Chances are the test ran to completion if everything was set up correctly. So it worked! Hooray! But what happens when we run it again?

```bash
$ ruby test/001_checkout_over_35_dollars.rb
```

Aha, it choked when it came to the checkout page. If you paid close attention to the runs you might see why. When we ran it the first time our user didn't have any shipping or payment methods so the forms were there, and now they are selecting our previous preferences automatically. The state of the application has changed due to our previous interactions with it.

Lets think of all the things we can that are wrong with the [test script][bad-test]

1. Everything is hard coded, which is a maintenance nightmare. Think if you had 50 tests like this. How about a thousand? One change could require days of script updating.
2. Doesn't actually test anything at all. Just goes through the scripted actions.
3. Repeats itself. The code to add an item to the cart is repeated throughout the script.
4. Relies on "known data". If the price of the first item rises about $35, the test is now invalid. If the price lowers enough that the second item doens't exceed $35, the test is now invalid.
5. Results aren't reported. You only know what happened by virtue of watching the script run.
6. No fault tolerance. If anything goes wrong, the test just dies, and any other tests you expected to run won't.
7. No one except the original designer has much hope of understanding the test without running it. This is a short test. What about a much longer one? What about when there are hundreds of tests

### This is typical

You might thing, with all those problems, that no one does testing like this, but you would be wrong.

Big companies looking to pay less for quality try to get out of having adequate testing resources by instead paying thousands of dollars for test automation licenses that let anyone record and play back scripts that look and function a LOT like this example test. They will write huge test scripts, spend a week running them every month and 3 weeks updating breaks to get them working well enough for the next test cycle. This is completely typical.

## Stage Two: Introducing a Framework

Okay, so writing scripted actions by hand is bad, so it's time to move onto stage two, in which you will introduce a testing framework. This will let you organize your test code and solve several problems

In your terminal run:

```bash
$ git checkout bad-gherkin
```

Now we've introduced Cucumber, which provides a framework for acceptance testing. It divides it up into two parts: specification and implementation.

So we rewrite our feature in plain english like so:

```gherkin
Feature: Free Shipping on Orders over $35

  Scenario: Free Shipping on Orders over $35
    Given a product costing $25
    And a product costing $11
    And a user "bradley.temple@gmail.com" with the password "supersecret"
    When I visit the log on page
    And I fill in "user_email" with "bradley.temple@gmail.com"
    And I fill in "user_password" with "supersecret"
    And click the button with the text "Sign in using our secure server"
    And I view the list of products
    And I click on the product costing $25
    And I click the "add_to_cart" button
    And I click on the shopping cart
    And I click the "Proceed to Checkout" link
    Then there should be the shipping option "$5.99 Standard USPS Parcel Post (3-5 Business Days)"
    And I view the list of products
    And I click on the product costing $11
    And I click the "add_to_cart" button
    And I click on the shopping cart
    And I click the "Proceed to Checkout" link
    Then there should be the shipping option "FREE Super Saver Shipping (3-5 Business Days)"
```

We can run the feature by doing:

```bash
$ cucumber features/free_shipping_on_orders_over_35_dollars.feature
```

It works, and it tells us that everything passed. We've addressed several of our problems. We now have actual expectations being set on the application, we are creating fresh data with each test run, so the application state is better controlled, results are reported so we can see what happened during the test run and if one test fails the rest will still run.

But there are still problems. Take a look at the implementation side:

```ruby
Given(/^a product costing \$25$/) do
  @product_25 = create(:product, price: 25)
end

Given(/^a product costing \$11$/) do
  @product_11 = create(:product, price: 11)
end

Given(/^a user "(.*?)" with the password "(.*?)"$/) do |email, password|
  @user = create(:user, email: email, password: password)
end

When(/^I visit the log on page$/) do
  visit "/users/sign_in"
end

When(/^I fill in "(.*?)" with "(.*?)"$/) do |field, value|
  fill_in field, with: value
end

When(/^click the button with the text "(.*?)"$/) do |text|
  click_button text
end

When(/^I view the list of products$/) do
  click_link "My Fake Amazon"
end

When(/^I click on the product costing \$25$/) do
  click_link @product_25.name
end

When(/^I click on the product costing \$11$/) do
  click_link @product_11.name
end

When(/^I click the "(.*?)" button$/) do |text|
  click_button text
end

When(/^I click the "(.*?)" link$/) do |text|
  click_link text
end

Then(/^there should be the shipping option "(.*?)"$/) do |text|
  expect(page.all("span.shipping-option").map(&:text)).to include text
end

Then(/^I click on the shopping cart$/) do
  click_link "shopping-cart"
end
```

See how the "plain english" is just a wrapper around very simple capybara calls? This isn't much of a maintenance improvement at all.

So our problems are now:

1. Harded Coded Values. Now we have all kinds of information in the feature file, and it's extremely prone to being broken.
2. Repeats itself.
3. Implementation is just a thin wrapper around capybara calls
4. Super wordy. The feature file contains TOO MUCH low-level information. It's still a test script. Someone can't tell what the business rules are by reading this unless they take the time to parse the information out of all the scenarios. This is a specification for application behavior, not UI, and should not concern itself with the UI.

However, getting past this stage where you think of tests as scripts is **really, really, really hard**. This is the place so many people get stuck, get tied up in maintenance nightmares and eventually hire a half dozen people to spend their days manually clicking around in the application. However, comfort taking things up to a higher level will yield a much better result.

## Stage 3: Improving Gherkin

```bash
$ git checkout good-gherkin
```

This stage will elude you until you are comfortable enough with the framework features and the abstraction of thinking of features at a higher level, but now look at the feature:

```gherkin
Feature: Shipping Options

  We have an array of shipping options available on Fake Amazon. The most basic is Standard Shipping, which ships via
  USPS parcel post, and is expected to be delivered in 3-5 Business Days. On orders over $35, we offer free super saver shipping.
  This is still a 3-5 day delivery, but we take care of the shipping cost.

  For Fake Amazon Prime Customers, we offer Free 2-Day shipping on any order regardless of how much it costs. We offer no-rush shipping which is also free, but ships more cheaply in exchange for a bonus of $1 digital goods credit. Finally we offer prime customers next-day shipping for $3.99 per item.

  Scenario: Only Standard Shipping for orders under $35
    Given I am logged in as a regular user
    And I have a cart with 1 product worth $34
    When I checkout
    Then I should only have the option for standard shipping

  Scenario: Only Standard Shipping for orders exactly $35
    Given I am logged in as a regular user
    And I have a cart with 1 product worth $35
    When I checkout
    Then I should only have the option for standard shipping

  Scenario: Standard and FREE Super-Saver Shipping on Orders over $35
    Given I am logged in as a regular user
    And I have a cart with 1 product worth $36
    When I checkout
    Then I should have the following shipping options:
      | $5.99 Standard USPS Parcel Post (3-5 Business Days) |
      | FREE Super Saver Shipping (3-5 Business Days)       |


  Scenario Outline: Shipping Options for Prime Customers
    Given I am logged in as a prime user
    And I have a cart with 1 product worth $<value>
    When I checkout
    Then I should have the following shipping options:
      | FREE Prime Two Day Shipping                                                     |  
      | $3.99 Prime Next Day Delivery                                                   |  
      | FREE Prime No Rush Shipping (5-7 Business Days). Get $1 Digital Product Credit! |  

    Examples:
      | value |  
      | 34    |  
      | 35    |  
      | 36    |  
```

Now our scenarios are short and punchy. They only talk about what's needed to get the point across. They demonstrate the boundaries of the business rules. It's easy for a non-techincal person to get the point, and easy for a technical person to understand how our feature works. It's possible to do behavior driven development with this feature, because we can simply alter this file to match the desired behavior and then use cucumber to drive the development.

However, the implementation side still has some issues. Check out the shipping_options_steps file:

```ruby
Given(/^I have a cart with 1 product worth \$(\d+)$/) do |price|
  @user.cart.add create(:product, price: price.to_f)
end

When(/^I checkout$/) do
  visit "/carts/1/checkout"
end

Then(/^I should only have the option for standard shipping$/) do
  expect(page.all("span.shipping-option").map(&:text)).to include "$5.99 Standard USPS Parcel Post (3-5 Business Days)"
end

Then(/^I should have the following shipping options:$/) do |table|
  expect(page.all("span.shipping-option").map(&:text)).to eq table.raw.flatten
end
```

We've still got hard-coded values here. Several steps are bound to shipping options being contained in a span with the shipping-option class, which is something extremely likely to get changed.

And in authentication_steps.rb:

```ruby
Given(/^I am logged in as a regular user$/) do
  @user = create(:user)
  visit "/users/sign_in"
  fill_in "user_email", with: @user.email
  fill_in "user_password", with: @user.password
  click_button "Sign in using our secure server"
end


Given(/^I am logged in as a prime user$/) do
  @user = create(:user, prime_member: true)
  visit "/users/sign_in"
  fill_in "user_email", with: @user.email
  fill_in "user_password", with: @user.password
  click_button "Sign in using our secure server"
end
```

We are repeating ourself here. Doing the exact same thing in two different functions with a different user. If the authentication flow changes, we'll have to make multiple changes to cope.

Which brings us to the last stage:

## Stage 4: Page Objects

```bash
$ git checkout page-object
```

This last stage calls on the test engineer to be as clever with the test code as the developer should be with the production code, which means another leap in abstraction to provide easier maintenance and understanding.

I talk more about page objects [in a previous post][page-object-post], so I'll just go over the highlights. Now the shipping options steps use a light interface to the application to navigate around and make expectations:

```ruby
Given(/^I have a cart with 1 product worth \$(\d+)$/) do |price|
  @user.cart.add create(:product, price: price.to_f)
end

When(/^I checkout$/) do
  @app.navigate_to :checkout_page
end

Then(/^I should only have the option for standard shipping$/) do
  @app.on(:checkout_page) do |page|
    expect(page).to have_only_standard_shipping_option
  end

end

Then(/^I should have the following shipping options:$/) do |options|
  @app.on(:checkout_page) do |page|
    expect(page).to have_shipping_options options
  end
end
```

And we can now simply log into the app as whatever user we like without repeating ourselves:

```ruby
Given(/^I am logged in as a regular user$/) do
  @user = create(:user)
  @app.login_as(@user)
end


Given(/^I am logged in as a prime user$/) do
  @user = create(:user, prime_member: true)
  @app.login_as(@user)
end
```

At this stage, we have finally addressed all the problems with our original test script back in stage one and have a test suite that is deterministic, flexible, easy to maintain and extend.

[fake-amazon]: https://github.com/DVG/fake-amazon
[bad-test]: https://github.com/DVG/fake-amazon/blob/master/test/001_checkout_over_35_dollars.rb
[page-object-post]: http://dvg.github.io/testing/2014/08/18/object-oriented-test-design-in-cucumber-part-1.html
