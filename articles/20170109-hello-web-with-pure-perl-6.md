Hello Web! with Purée Perl 6
hello-web-with-pure-perl-6
programming, rakudo

## Let's build a website.

Websites are easy to build.  There are dozens of frameworks out there to use, perl has Mojo and Catalyst as its major frameworks and other languages also have quite a few decent options.  Some of them come with boilerplate templates and you just go from there.  Others don't and you spend your first few hours learning how to actually set up the framework and reading about how to share your DB connection between all of your controllers and blah, blah, blah.  Let's look at one of P6's web frameworks.

## Enter `Hiker`

Hiker doesn't introduce a lot of (if any) new ideas.  It does use paradigms you're probably used to and it aims to make the initialization of creating your website very straight forward and easy, that way you can get straight to work sharing your content with the English.

### The Framework

Hiker is intended to make things fast and easy from the development side.  Here's how it works.  If you're not into the bleep blop and just want to get started, skip to the Boilerplate heading.

#### Application Initialization

1. Hiker reads from the subdirectories we'll look at later.  The controllers and models are classes.
1. Looking at all controllers, initializes a new object for that class, and then checks for their `.path` attribute
  1. If Hiker can't find the path attribute then it doesn't bind anything and produces a warning
1. After setting up the controller routes, it instantiates a new object for the model as specified by the controller (`.model`)
  1. If none is given by the controller then nothing is instantiated or bound and nothing happens
  1. If a model is required by the controller but it cannot be found then Hiker refuses to bind
1. Finally, `HTTP::Server::Router` is alerted to all of the `path`s that Hiker was able to find and verify

#### The Request

1. If the path is found, then the associated class' `.model.bind` is called.
  1. The response (second parameter of `.model.bind($req, $res)`) has a hash to store information: `$res.data`
1. The controller's `.handler($req, $res)` is then executed
  1. The `$res.data` hash is available in this context
1. If the handler returns a `Promise` then Hiker waits for that to be kept (and expects the result to be True or False)
  1. If the response is already rendered and the Promise's status is True then the router is alerted that no more routes should be explored
  1. If the response isn't rendered and the Promise's result is True, then `.render` is called automagically for you
  1. If the response isn't rendered and the Promise's result is False, then the next matching route is called

### Boilerplate

Ensure you have `Hiker` installed:

```bash
$ zef install Hiker
$ rakudobrew rehash #this may be necessary to get the bin to work
```

Create a new directory where you'd like to create your project's boilerplate and `cd`.  From here we'll initialize some boilerplate and look at the content of the files.

```bash
somedir$ hiker init
==> Creating directory controllers
==> Creating directory models
==> Creating directory templates
==> Creating route MyApp::Route1: controllers/Route1.pm6
==> Creating route MyApp::Model1: models/Model1.pm6
==> Creating template templates/Route1.mustache
==> Creating app.pl6
```

Neato burrito.  From the output you can see that Hiker created some directories - controllers, models, templates - for us so we can start out organized.  In those directories you will find a few files, let's take a look.

### The Model

```perl6

use Hiker::Model;

class MyApp::Model1 does Hiker::Model {
  method bind($req, $res) {
    $res.data<who> = 'web!';
  }
}
```

Pretty straight forward.  `MyApp::Model1` is instantiated during Hiker initialization and `.bind` is called whenever the controller's corresponding path is requested.  As you can see here, this Model just adds to the `$res.data` hash the key value pair of `who => 'web!'`.  This data will be available in the Controller as well as available in the template files (if the controller decides to use that).

### The Controller

```perl6
use Hiker::Route;

class MyApp::Route1 does Hiker::Route {
  has $.path     = '/';
  has $.template = 'Route1.mustache';
  has $.model    = 'MyApp::Model1';

  method handler($req, $res) {
    $res.headers<Content-Type> = 'text/plain';
  }
}
```

As you can see above, the `Hiker::Route` has a lot of information in a small space and it's a class that does a Hiker role called `Hiker::Route`.  This let's our framework know that we should inspect that class for the `path, template, model` so it can handle those operations for us - `path and template` are the only required attributes.

As discussed above, our Route can return a Promise if there is some asynchronous operation that is to be performed.  In this case all we're going to do is set the header's to indicated the Content Type and then, automagically, render the template file.  Note: if you return a `False`y value from the handler method, then the router will not auto render and it will attempt to find the next route.  This is so that you can cascade paths in the event that you want to chain them together, do some type of decision making real time to determine whether that's the right class for the request, or perform some other unsaid dark magic.  In the controller above we return a `True`thy value and it auto renders.

By specifying the Model in the Route, you're able to re-use the same Model class across multiple routes.

#### The Path

Quick notes about `.path`.  You can pass a (`'/staticpath'`), maybe a path with a placeholder (`'/api/:placeholder'`), or if you're path is a little more complicated then you can pass in a regex (`/ .* /`).  Check out the documentation for `HTTP::Server::Router` ([repo](https://github.com/tony-o/perl6-http-server-router)).

### The Template

The template is specified by the controller's `.template` attribute and Hiker checks for that file in the `./templates` folder.  The default template engine is `Template::Mustache` ([repo](https://github.com/softmoth/p6-Template-Mustache)).  See that module's documentation for more info.

### Running the App

Really pretty straight forward from the boilerplate:

```bash
somedir$ perl6 app.pl6
```

Now you can visit `http://127.0.0.1:8080/` in your favorite Internet Explorer and find a nice 'Hello web!' message waiting to greet you.  If you visit any other URI you'll receive the default 'no route found' message from `HTTP::Server::Router`.

### The Rest

The module is relatively young.  With feedback from the community, practical applications, and some extra feature expansion, Hiker could be pretty great and it's a good start to taking the tediousness out of building a website in P6.  I'm open to feedback and I'd love to hear/see where you think Hiker can be improved, what it's missing to be productive, and possibly anything else [constructive or otherwise] you'd like to see in a practical, rapid development P6 web server.


