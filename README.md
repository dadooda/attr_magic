
# The tools to ease lazy attribute implementation

<!-- @import "[TOC]" {cmd="toc" depthFrom=2 depthTo=6 orderedList=false} -->

<!-- code_chunk_output -->

- [Overview](#overview)
  - [What does AttrMagic provide?](#what-does-attrmagic-provide)
- [Setup](#setup)
- [Usage example](#usage-example)
  - [`#igetset`](#igetset)
  - [`#require_attr`](#require_attr)
  - [`#igetwrite`](#igetwrite)
- [Copyright](#copyright)

<!-- /code_chunk_output -->

## Overview

*Этот текст можно прочитать на русском языке: [README-ru.md](README-ru.md).*

A lazy attribute is an accessor method that performs some computation the first time it is called,
memoizes the result into an instance variable, and returns the result. Example:

```ruby
class Person
  # @return [String]
  attr_accessor :first_name, :last_name

  attr_writer :full_name, :is_admin

  def initialize(attrs = {})
    attrs.each { |k, v| public_send("#{k}=", v) }
  end

  # @return [String]
  def full_name
    @full_name ||= begin
      [first_name, last_name].compact.join(" ").strip
    end
  end

  # @return [Boolean]
  def is_admin
    return @is_admin if defined? @is_admin
    @is_admin = !!full_name.match(/admin/i)
  end
end
```

Methods `#full_name` и `#is_admin` are lazy attributes.

### What does AttrMagic provide?

For classes that have lazy attributes, AttrMagic provides:

1. `#igetset` and `#igetwrite` for simple memoization of any values, including `false` and `nil`.
2. `#require_attr` to validate attributes which are required by the given computation.

## Setup

Add to you project's `Gemfile`:

```ruby
gem "attr_magic"
#gem "attr_magic", git: "https://github.com/dadooda/attr_magic"
```

## Usage example

To use feature, let's load it into a class:

```ruby
class Person
   AttrMagic.load(self)
   …
end
```

AttrMagic methods are now available in the `Person` class.
Let's see how we can use them.

### `#igetset`

In the example above, method `#full_name` memoizes the result with the `||=` operator.
This suits us, because the result of the computation is a string.

As to `#is_admin`, its much more verbose: the result can be `false`,
thus operator `||=` won't work.

Both methods can be written using `#igetset`:

```ruby
class Person
  …
  def full_name
    igetset(__method__) { [first_name, last_name].compact.join(" ").strip }
  end

  def is_admin
    igetset(__method__) { !!full_name.match(/admin/i) }
  end
end
```

Now our methods are short, uniform, and easy to read.

Also, the computation in `#is_admin` is clearly visible, whereas previously it was obscured
by repetitions of *is_admin* inside the method already named by this word.

### `#require_attr`

In the example above, method `#first_name` returns an empty string even if attributes
`first_name` and `last_name` are unassigned or blank.

Such behavior cannot be considered completely sane.
Most likely, the result of `#full_name` will be displayed in the info block about a person
or be used when addressing a person.
An empty string, even “legitimately” computed, may cause confusion.

Of course, it's not the `Person` instance's fault that neither `first_name` nor `last_name`
were assigned values prior to calling `#full_name`. Garbage in — garbage out.

However, rather than behaving deliberately “harmful” by returning inarticulate blankness,
`#full_name` could be *helpful* by signalling about this situation and helping us tackle it promptly.

Suppose we decided, that in order to compute `#full_name` properly,
we at least need a non-blank `first_name`. An implementation could look like this:

```ruby
class Person
  …
  def full_name
    igetset(__method__) do
      require_attr :first_name
      [first_name, last_name].compact.join(" ").strip
    end
  end
end
```

Let's see how it works:

```ruby
Person.new.full_name
# RuntimeError: Attribute `first_name` must not be nil: nil
```

Not bad! Instead of getting dumb blankness, we've got an exception pointing straight at the reason:
unassigned `first_name`. However, the `nil` phrasing might sound a bit confusing
when talking about string values.
Also, what if `first_name` is assigned, but is empty or blank? Let's see:

```ruby
Person.new(first_name: "").full_name
# => ""

Person.new(first_name: " ").full_name
# => ""
```

Our `require_attr` doesn't react to an empty/blank string yet,
despite our decision to ensure that `first_name` is *non-blank*.
Let's tune the code a bit:

```ruby
# We need this for `Object#present?`.
require "active_support/core_ext/object/blank"

class Person
  …
  def full_name
    igetset(__method__) do
      require_attr :first_name, :present?
      #require_attr :first_name, :not_blank?   # Also possible.
      [first_name, last_name].compact.join(" ").strip
    end
  end
end
```

Let's try it again:

```ruby
Person.new.full_name
# RuntimeError: Attribute `first_name` must be present: nil

Person.new(first_name: " ").full_name
# RuntimeError: Attribute `first_name` must be present: " "

Person.new(first_name: "Joe").full_name
# => "Joe"
```

Now the message is more meaningful and the requirement is met.

We've learned that `#require_attr` makes it possible to perform a trivial validation
of another attribute, needed for a given computation to succeed.

### `#igetwrite`

Method `#igetset`, described above, operates instance variables directly:
checks for being defined, gets and sets. This is sufficient in most cases.

Sometimes, however, proper setting of an attribute demands calling its write accessor,
such as `#name=`.

In such cases, `#igetwrite` comes in handy.
After performing the computation, it saves the value to the object by calling a write accessor.

## Copyright

The product is free software distributed under the terms of the MIT license.

— © 2017-2023 Alex Fortuna
