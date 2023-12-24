## What is rails-simple-search?
rails-simple-search is a Ruby gem. It can help Ruby on Rails developers **quickly**
implement searching/filtering function against database. If you're not looking
for a full-text searching solution, this plugin will most probably **satisfy all**
your searching requirement.

## Why?
From time to time, I need to build pages to show a list of narrowed down records
from a database table by giving some searching criteria on some columns of the
table and/or of some referencing tables. Before I implemented this plugin, I usually
do the searching in the following way:

1. Use <%= form_tag %> to build a form in the view
2. Get the searching criteria from the params hash individually in the controller
   and put them into instance variables to be used in view
3. Build the SQL WHERE clause and sometimes the JOIN clause according to the
   values from the form
4. Run the find(:all, :conditions => [xxxxxxxx], :joins => "xxxxxxxx") with the
   WHERE and JOIN clauses

After having used this pattern a few times, I realized I could DRY it to make
future coding of this kind of searching **much simpler**. That's where the
rails-simple-search plugin comes in. 

## Installation
1. Put the following line into the Gemfile of your project
```
   gem 'rails-simple-search'
```

2. Install the gems in Gemfile
```
   $ bundle install
```

## Usage 

Let's suppose we have models of User, Address, Post and Comment. User model has_one
address, has_many posts, and has_many comments; Post model has_many comments; Comment
model belongs_to an author(of model User). We'd like to search for users according
to any combination of the following criteria:

* part of the user's email addrsss
* part of the first name or last name
* range of the user's birth date
* part of the city name of the user's address
* state of the user's address
* part of the name of any authors who commented the user's any posts

The following is how we implement this searching function with rails-simple-search:

1. Include gem into Gemfile
```  
    gem 'rails-simple-search'
```

2. Code in model (app/model/search.rb):
```
    class Search < RailsSimpleSearch::Base
    end
```

3. Code in controller: 
```
    @search = Search.new(User, params[:search])
    @users = @search.run.order('email')
```

4. Code in views:
```
    <% form_for @search, url => "/xxxxxx", data: {turbo: false} do |f| %>

      <%=f.label :email %>
      <%=f.text_field :email %>

      <%=f.label "first name or last name" %>
      <%=f.text_field "first_name_or_last_name" %>

      <%=f.label :from_birth_date %>
      <%=f.text_field :birth_date_greater_than_equal_to %>

      <%=f.label :to_birth_date %>
      <%=f.text_field :birth_date_less_than_equal_to %>

      <%=f.label :state%>
      <%=f.select "address.state_id", [['AL', 1], ...] %>  <!-- address is an association of model User -->

      <%=f.label :city %>
      <%=f.text_field "address.city" %>                    <!-- address is an association of model User -->

      <%=f.label "name of any one who commented to my posts" %>
      <%=f.text_field "posts.comments.author.first_name_or_posts.comments.author.last_name" %> 
                                                           <!-- the associations could go even deeper, isn't it POWERFUL? -->

      <%=f.submit %>
    <% end %>

    <% @users.each do |user| %>
     <%= # show the attributes of user %>
    <% end %>
```

5. Add route for the post to url "/xxxxxx" (config/route.rb)
```
    post "/xxxxxx" => "yyyyyyy#zzzzzz"
```

## Demo projects
There are 2 demo projects for this gem, one for [Rails 5](https://github.com/yzhanginwa/demo_app_for_rails_simple_search)
and one for [Rails 7](https://github.com/yzhanginwa/rails_simple_search_demo). You are encouraged to clone them to your local and
get a feel of the power of rails-simple-search.

## Version history 
For rails 2.x.x applications, you might want to use the version 0.9.0. 

From version 0.9.1 to 0.9.7, Rails 3 is supported.

From version 0.9.8 on, this gem started to support Rails 4. Version 0.9.8 is tested under Rails 4.1.1, and version 0.9.9 fixed an issue under
Rails 4.2.

From version 1.1.0 on, we started to support the "or" relation, e.g., we can use field like "first_name_or_last_name".

From version 1.1.3 on, we started to support Rails 5.

For Rails 7, please use version 1.1.9.

## License

Copyright &copy; 2012 [Ethan Zhang], released under the MIT license
