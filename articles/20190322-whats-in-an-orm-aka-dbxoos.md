What's in an ORM, aka DB::Xoos
whats-in-an-orm-aka-dbxoos
programming, rakudo

Using an ORM makes your code look a little cleaner.  Today we can take a look at Xoos, an ORM aimed at making your life simpler, your code cleaner, and not getting in the way of your development.

This article will cover implementing an ERD in your code and show example uses.

Key features of Xoos:

- flexible configuration (YAML files as well as classes, or just one or the other)
- relational modeling made easy
- convenience methods on both rows & models
- validation

### quick terminology

#### model

You can think of this in database terms as a table but in the rest of the article a `model` is meant to mean the class+{convenience methods}+{optional yaml}

If you're coming from DBIx this can be thought of the same as a resultclass.

#### row

Think of this in terms of the row class+{convenience methods}+{columns inherited from the model}

### set up

Using zef we'll install Xoos (if YAML::Parser::LibYAML fails to install or you don't want to install libyaml, then don't fret - you don't need it and it's just in the article to demonstrate YAML models).

`zef install DB::Xoos YAML::Parser::LibYAML`

SQLite3, we'll create the following ERD.

![Database-ER-Diagram](/i/erd.png)

```
example$ sqlite3 xoos.sqlite3
SQLite version 3.19.3 2017-06-27 16:48:08
Enter ".help" for usage hints.

sqlite> create table books (book_id integer primary key autoincrement, title varchar(64) not null, author_id integer not null, date_published date, price float not null);

sqlite> create table authors (author_id integer primary key autoincrement, name varchar(64) not null, birth_date date);

sqlite> create table customers (customer_id integer primary key autoincrement, email_address varchar(64) not null, name varchar(64) not null, date_registered date default (datetime('now','localtime')));

sqlite> create table orders (order_id integer primary key autoincrement, customer_id integer not null, order_date date default (datetime('now','localtime')));

sqlite> create table order_details (order_detail_id integer primary key autoincrement, order_id integer not null, book_id integer not null);

sqlite> .quit
```

That's it for setup.  Now we can start using Xoos and implementing our application.

### commence coding!

This example is going to contain a `lib` directory and a bunch of other scripts for doing useful things with our models/rows.

#### ORM setup

Now we must create our ORM classes.

We'll develop two of the models, one with standard perl6 and one using YAML, the rest of ERD can be implemented as a practice _or_ the entire project can be downloaded at the end of the article.

##### App::Model::Book

In our path we're going to use the prefix of `App` for our models and rows.  If you haven't already and you're following along, then create the directory `lib/App/Model` and then edit the file `lib/App/Model/Book.pm6`.

```perl
use DB::Xoos::Model;
unit class App::Model::Book does DB::Xoos::Model['books'];

qw<...>
```

Here we are simply defining our class and telling DB::Xoos to use the table `books` as our source of data for this model.  Next we'll let the ORM know what columns are available.

```perl
has @.columns = [
  book_id => {
   type           => 'integer',
   is-primary-key => True,
   auto-increment => True,
  },
  title => {
    type     => 'varchar',
    nullable => False,
    length   => '64',
  },
  author_id => {
    type   => 'varchar',
    nullable => False,
    length => '64',
  },
  date_published => {
    type   => 'date',
  },
  price => {
    type   => 'float',
  },
];
```

Fairly straight forward.  Using `is-primary-key` on multiple columns will allow you to key off of multiple columns, creating a compounded key.

```perl
has @.relations = [
  authors => {
    :has-one,
    :model<Author>,
    :relate(author_id => 'author_id'),
  },
  order_details => {
    :has-many,
    :model<OrderDetails>,
    :relate(book_id => 'book_id'),
  },
];
```

Here we're defining the relationships that models have with other models.  We have a 1:N with `:has-many` and a 1:1 with `:has-one`.

After that our model is defined and if we have no `row` methods we would like to implement then we're done.

##### App::Model::OrderDetail

If you haven't already and you're following along, then create and edit the file `models/orderdetail.yaml`.

```yaml
table: order_details
name: OrderDetail
columns:
  order_detail_id:
    type: integer
    nullable: false
    is-primary-key: true
    auto-increment: true
  order_id:
    type: integer
    nullable: false
  book_id:
    type: integer
    nullable: false
relations:
  book:
    has-one: true
    model: Book
    relate:
      book_id: book_id
  order:
    has-one: true
    model: Order
    relate:
      order_id: order_id
```

As you can see this is essentially doing what we did above without necessitating the explicit creation of the entire class.

*Note: using yaml doesn't preclude you from putting model methods in a class App::Model::OrderDetail but it can make your model class methods look cleaner!*

##### App::Model::\*

The rest of the model creations would be redundant so, the rest of the exercise is left as just that (or it's available at the end of the article).

That's it!  Your models are ready to be used, the rest of the code is going to be in scripts placed in the `bin/` folder.

### Example Usage

#### First ORM usage

We'll list what models we have available to us from ORM, this script is called `show-models`.  All of the following examples will assume you've done the same code up to and including the `.connect` and will be omitted for brevity.

```perl
use DB::Xoos::SQLite;

my $xoos = DB::Xoos::SQLite.new;

$xoos.connect('sqlite://xoos.sqlite3', :options({
    :prefix<App>,               # loads classes from App::Model::*
    model-dirs => [qw<models>], # for our yaml column definitions
}));

"Successfully loaded models:\n  {$xoos.loaded-models.join("\n  ")}".say;
```

This script should output something like:

```
Successfully loaded models:
  Customer
  Author
  OrderDetail
  Order
  Books
```

While not entirely useful, it does let us know that everything loaded well.  Now let's fill up our tables.

#### Loading data into tables from CSV

This script will use `Text::CSV` and load data from `data/books.csv` and generate other made up data.  This is a truncated version because it's mostly long and repititous for our use.  Generating customers, orders, and order details is left to the user or, again, you can find a full script in the file at the end of the article.

```perl
qw<snipped setup for Xoos>;
use Text::CSV;

my @rows    = csv(:in('data/books.csv'));

my $book = $xoos.model('Book');
my $auth = $xoos.model('Author');

# generate book and author data from csv
for @rows[1..*] -> $row {

  # determine whether an author by that name exists, this isn't
  # robust as there may be many authors by the same name
  my $author = $auth.search({
    name => $row[1] eq '' ?? 'unknown' !! $row[1];
  });

  # if an author was found, use it
  if $author.count {
    $author .=first;
  } else {
    $author = $auth.new-row;
    $author.name($row[1] eq '' ?? 'unknown' !! $row[1]);
    $author.update;
  }

  # create our book and generate a random price
  $book.new-row({
    author_id => $author.author_id,
    title     => $row[0],
    price     => (299 .. 5000).pick(1)[0] / 100,
  }).update;
}
```

#### Viewing or finding customer information

In this example we'll be using a relationship on customer to get the number of orders and how many items each order contained. The script _also_ uses a convenience method built upon the `App::Row::Customer` to show how many total items they've ordered.

```perl
use DB::Xoos::SQLite;
my DB::Xoos::SQLite $db .=new;


multi MAIN(:$email?, :$name, :$customer-id) {

  $db.connect('sqlite://xoos.sqlite3', :options({
    model-dirs => [qw<models>],
    prefix     => 'App',
  }));


  my %search;
  my $customers = $db.model('Customer');

  %search<customer_id> = $customer-id if $customer-id.defined;
  %search<name>        = %(
    'like' => '%' ~ $name ~ '%',
  ) if $name.defined;
  %search<email_address>        = %(
    'like' => '%' ~ $email ~ '%',
  ) if $email.defined;

  if %search.keys {
    $customers .=search(%search);
    say "Searching with params:";
    dd %search;
  }
  say 'Customer info:';
  printf "| %-14s | %-17s | %-14s | %-12s | %-14s |\n", qw<customer_id email name orders order-items>;
  say 'x' x 87;

  for $customers.all -> $customer {
    printf "| %-14s | %-17s | %-14s | %-12s | %-14s |\n",
      $customer.customer_id,
      $customer.email_address,
      $customer.name,
      $customer.orders.count,
      $customer.total-order-items; # this uses the row level convenience method in App::Row::Customer
  }

  say 'x' x 87;

}
```

If you have questions or would like to see more, exploring this or other topics, please ping me @tony-o in #perl6 on freenode.

Here is a link to files for this guide [github repo](https://github.com/tony-o/perl6-xoos-guide), [zip file](https://github.com/tony-o/perl6-xoos-guide/archive/master.zip)
