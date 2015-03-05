---
layout: post
title: Apply ActiveModel Validations by Policy
author: DVG
comments: true
---

I'm currently working on a form where a couple attributes of the underlying model can drastically affect the validations are necessary. There are around 13 attributes, and 25 permutations of validations.

I don't really like the idea of the form class topping out at hundreds of lines of conditional methods, so I started looking into what I could accomplish by applying what I'm calling a `Validation Policy` on the specific instance.

First, let's go over what *didn't* work.

## Best Laid Plans

My first idea was to simply open up the singleton class of a given instance of the form and include a module containing validation macros. It looked something like this

```ruby
module ValidationPolicy
  def apply_validation_policy(policy)
    singleton_class.instance_eval do
      include policy
    end
  end
end

class Form
  include ActiveModel::Model
  include ValidationPolicy

  attr_accessor :foo, :bar
end

module FooPolicy
  extends ActiveSupport::Concern
  included do
    validates :foo, presence: true
  end
end
```

Seemed simple enough, right? Just need to add a method to make @form determine it's policies based on it's attributes and we're good to go!

Unfortunately, that's not the case here.

```
form = Form.new
form.valid? # => true
form.apply_validation_policy FooPolicy
form.valid? # => true
```

So started the googling. I discovered a [gist][gist-of-broken-dreams] of various cuts at doing this sort of thing, none of which seemed to work on my version of Rails. Then I found a [issue on the Rails issue tracker][rails-issue] that pointed out that the singleton_class does not inherit the necessary state from the superclass for the validations to work.

So the official answer is: Use inheritance.

After messing around with some anonymous class options that felt super hacky, and looking at a number of form and validation gems, I was just about to throw in the towel when I had another idea.

## Extend the wheel, don't reinvent it

Rails conditional validations already provide what I want, I just want to mess with the conditions at the instance level without polluting the form class.

So i set out to make this the new class:

```ruby
class Form
  include ActiveModel::Model
  include ValidationPolicy
  attr_accessor :foo, :bar

  validates :foo, presence: true, if: :foo_presence_required_by_policy
end
```

It's not quite the empty slate I had originally in mind, but the validations are all defined in the class, they are just activated by the individual policy via a clean method-naming convention

So now I just needed a way to define these conditional methods. I decided to stick with the mixin concept with a single DSL method.

```ruby
module FooPolicy
  extend ActiveSupport::Concern

  included do
    require_validation_of :foo, presence: true
  end
end
```

With this as the goal, I added this to the validation policy module

```ruby
module ValidationPolicy
  extend ActiveSupport::Concern

  included do
    def self.require_validation_of(name, options)
      if options[:presence]
        self.send(:define_method, "#{name.to_s}_presence_required_by_policy") do
          true
        end
      end

      # other types of validations
    end
  end
end
```

Now the bits are all in place, but I do want to avoid blowing up during validations if a policy hasn't been applied.

```ruby
module ValidationPolicy
  # ...
  def method_missing(name, *args, &block)
    if name.match /required_by_policy$/
      return false
    end
    super
  end
end
```

This will make sure that validations won't blow up with a NoMethodError if a particular policy doesn't apply.

```
form = Form.new
form.valid? # => true
form.apply_validation_policy FooPolicy
form.valid? # => false
```

I really like the result. Now I can extract complex validation logic into tiny modules that will be easier to find and maintain than dozens of conditional methods on the Form class. If you have complicated validation needs, I hope you will find this helpful.

EDIT:

I took this one step further, and wrapped up the declarations in another class macro:

```ruby
module ValidationsPolicy
  # ...
  included do
    def self.validates_presence_of_by_policy(attribute)
      self.validates attribute, presence: true, if: "#{attribute.to_s}_presence_required_by_policy".to_sym
    end
  end
end
```

[gist-of-broken-dreams]: https://gist.github.com/thechrisoshow/2236521
[rails-issue]: https://github.com/rails/rails/issues/5449
