---
layout: post
title:  "Object Oriented Test Design in Cucumber (Part 2) - Test Services"
author: DVG
categories: testing
tags: cucumber testing service-objects
comments: true
---

**This is part of a series on object oriented integration test design. See the other parts:**

* [Part 1: Page Objects]({% post_url 2014-08-18-object-oriented-test-design-in-cucumber-part-1 %})

# Service Objects

There's been a shift in Rails the last couple years away from the fat model, skinny controller paradigm. Instead, there's a lot of momentum behind the [Service Object Pattern][7-patterns], which allows for encapsulating complex operations in small, focused plain old ruby objects.

There's a lot of advantages to small objects. Most importantly it is perfectly clear what the class does and they are easy to test as a result.

## Test Service Objects

Test Suites develop their own bits of complicated logic over time, and the Service Object Pattern can help us here as well.

Let's say you have a cucumber feature that tries to describe an HTML table with a cucumber one:

{% highlight gherkin %}
Then I should see search results like:
| Username | Email Address  |
| DVG      | dvg@github.com |
{% endhighlight %}

The default step definition would look something like this:

{% highlight ruby %}
Then(/^I should see search results like$/) do |table|
  # table is a Cucumber::AST::Table
end
{% endhighlight %}

Comparing a Cucumber Table with an HTML table is not a 1-line thing. It is possible, but it takes several steps.

First of all, [Cucumber::Ast::Table implements a #diff! method][cucumber-ast-table-diff] you can use to compare the html table to the expected table. But you need to convert the HTML Table to a 2D array.

{% highlight ruby %}
Then(/^I should see search results like$/) do |table|
  actual_table = find("#search_results").all("tr").map do |row|
    row.all("td, th").map do |cell|
      cell.text
    end
  end
  expect { table.diff!(actual_table) }.to be_nil
end
{% endhighlight %}

So here we do a double `#map` operation to convert the rows and cells into a 2D array of strings with the cell contents. This will work, but it's not reusable as it currently stands. A test service would serve us well here

{% highlight ruby %}
class TableComparison
  attr_accessor :cucumber_table, :selector
  def initialize(cucumber_table, selector)
    @cucumber_table = cucumber_table
    @selector = selector
  end

  def matches?
    cucumber_table.diff!(build_2d_array_from_html_table).nil?
  end

private
  def build_2d_array_from_html_table
    find(selector).all("tr").map do |row|
      row.all("td,th"),map { |cell| cell.text }
    end
  end  
end
{% endhighlight %}

Now we have an object that can do the heavy lifting for us

{% highlight ruby %}
Then(/^I should see search results like$/) do |table|
  expect { TableComparison.new(table, "#search_results").matches? }.to be_true
end
{% endhighlight %}

# Combine Test Services with Page Objects to keep your step definitions clean

As a final step, we'll move the validation logic to the page object, and then simply ask the page if it's correct

{% highlight ruby %}
# features/support/pages/search_results_page.rb
class SearchResultsPage < SitePrism::Page
  def has_results_matching?(table)
    TableComparison.new(table, "#search_results").matches?
  end
end

# featrues/step_definitions/search_results_page_steps.rb
Then(/^I should see search results like$/) do |table|
  expect(@app.saerch_results_page).to have_results_matching(table)
end
{% endhighlight %}


[7-patterns]:   http://blog.codeclimate.com/blog/2012/10/17/7-ways-to-decompose-fat-activerecord-models/
[cucumber-ast-table-diff]: http://www.ruby-doc.org/gems/docs/d/davidtrogers-cucumber-0.6.2/Cucumber/Ast/Table.html#method-i-diff-21
