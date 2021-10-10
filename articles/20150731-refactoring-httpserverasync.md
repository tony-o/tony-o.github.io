Refactoring HTTP::Server::Async
refactoring-httpserverasync
programming, rakudo

Even serialized HTTP servers are complicated.  Let's make one that is asynchronous for the three Fs; fun, frustration, fury.

We're going to rewrite HTTP::Server::Async from near scratch because, frankly, it's crap.  I hate that it even has my name on it.  I wrote it for a `rakudo` version that was still less mature than what we have today and because of the dreaded `NYI`, there are a lot of hacks and inefficiencies.

Let's start with the fun.  We're going to use the `HTTP::Server` role that is floating around in the environment.  I created that role with the intention of folks creating their own versions of HTTP servers that are hot swappable under front ends.  Similar to the way Mojolicious will run under their home grown server, or hypnotoad, or coolguyluke420's hacked together monster.

### HTTP::Server::Async
#### The cornerstone of any hipster's repertoire

--

### Itinerary

1. Install `HTTP::Server`
2. Anatomy of an HTTP server
3. Write code

Let's get on with it.

### Install `HTTP::Server`

If you're into `zef` and its awesomeness.  If you're asking what `zef` is then you should definitely go check it out.

```
zef install HTTP::Server
```

If you're not into `zef`'s freshness

```
panda install HTTP::Server
```

### Anatomy of an HTTP Server

HTTP servers are fairly simple.  They run fast and loose, like old gregg.  There are also a lot of caveats to the simple process I'm going to write below.

1. A connection is requested
2. Connection is accepted
3. Client sends an HTTP request
4. Server processes the requests
  1. Parse cookies (this is middleware, we're not going to do this in the server right now)
  2. Response handler needs to handle chunked and binary encoding, etc (we'll implement this)
  3. Certain headers expect the connection to behave differently, IE upgrade to HTTP/2.0, websocket, etc (we're going to create the mechanism to allow this to happen)
  4. Pipelining requests will be supported
5. Server sends response to client

Some of the caveats are listed above, there are whole lot of other things going on that we'll explore as we write some hipster perl6 codes.

### Write Code

I'm going to make some assumptions about you and assume you have a text editor, perl6, and understand at least some perl6 basics.

```perl6
use HTTP::Server;

class HTTP::Server::Async does HTTP::Server {
  has Int    $.port = 1666;
  has Str    $.ip   = '0.0.0.0';

  has IO::Socket::Async $socket;

  has @.handlers;
  has @.afters;
  has @.middlewares;

  method handler(Callable $sub) {

  }

  method after(Callable $sub) {

  }

  method middleware(Callable $sub) {

  }

  method listen {

  }
};
```

Let's chunk this hunk of crap a part and go piece by piece.

#### Customs and declarations

```perl6
use HTTP::Server;

class HTTP::Server::Async does HTTP::Server {
```

Here we're creating the class `HTTP::Server::Async` and letting perl6 know that we're going to implement whatever `HTTP::Server` tells us we should.

#### Method stubbing and parameter defaults

We're setting ourselves up to not have to do a lot of error checking.  We're setting the default port to the mark of the beast plus 1k `1666`.  Our default ip to listen on is `0.0.0.0`, basically accept connections from anywhere.  We have our socket factory all set up - more on `$.socket` later.

```perl6
  has Int    $.port = 1666;
  has Str    $.ip   = '0.0.0.0';

  has Supply $.socket;
```

Our other class attributes are something we'll use during the method calls, right now we're just stubbing it up.

```perl6
  has @.handlers;
  has @.afters;
  has @.middleware;
```

And finally, we'll actually do what we told the compiler we'd do, add some stubs for the `HTTP::Server` role.

```perl6
  method handler(Callable $sub) {

  }

  method after(Callable $sub) {

  }

  method middleware(Callable $sub) {

  }

  method listen(Bool $block? = False) {

  }
```

At this point we're pretty well put together.  We have an Async server that essentially refuses every connection, listens on no sockets, and doesn't take any flack from anybody.  In other words, it does nothing at this point.

Let's start by setting up our listening socket.  We're going to modify the `.listen` method.

```perl6
  method listen(Bool $block? = False) {
    my Promise $prom .=new;

    $.socket = IO::Socket::Async.listen($.ip, $.port) or die "Failed to listen on $.ip:$.port";
    $.socket.tap(-> $conn {

    }, quit => {
      $prom.keep(True);
    });

    await $prom if $block;
    return $prom;
  }
```

Wow this is sooooooo cool.  We have an Async socket that listens, accepts connections and absolutely nothing else.  We're at a decision point now, how do we want to handle request parsing?  The answer in this tutorial is, obviously we're going to use a `Supply` to generate request, response combinations to be handled later.

This is grown tiresome already, let's answer some requests and see where we stand.  Inside of our `$.socket.tap`:

```perl6
      $conn.send(qq{HTTP/1.1 200 OK
Content-Type: text/plain
Content-Length: 9

What's up});

      $conn.close;
      CATCH { default { .say; } }
```

Couple of notes at this point.

1. The `CATCH` is vitally important to troubleshooting; currently errors are lost in the sauce and never bubble up anywhere without that handler
2. We're serving static content and then closing the connection
3. We're up to step 3 of our 5 part program

Because pipelined requests are sent serially, we're going to handle the parsing all in a single thread and then dish those out with a new `HTTP::Response` object.  It's going to be really neat.

At this point your file should be pretty clean.  You can start the server with a little code below and visit the page in your browser.

```perl6
use lib 'lib';
use HTTP::Server::Async;

my HTTP::Server::Async $h .=new;
$h.listen(True);
#or: await $h.listen;
```

Now go to `http://127.0.0.1:1666/`, you should see `What's up`.

Now undo all that `$conn.close` and `$conn.send` crap we've done.  We're done messing around, we're going to parse some requests.

Here's the code for detecting the end of request headers, after this we'll write down some stuff to handle the rest of the request.  This code goes inside of our `$.socket.tap(`

```perl6
      my Buf $data .=new; #buffer across chunks received
      my Int $index = 0;  #index of last checked buffer position
      my Buf $rn   .=new("\r\n\r\n".encode); #our header end detector
      $conn.bytes_supply.tap(-> $bytes {
        $data ~= $bytes;
        while $index++ < $data.elems - 3 {
          last if $data[$index]   == $rn[0] &&
                  $data[$index+1] == $rn[1] &&
                  $data[$index+2] == $rn[2] &&
                  $data[$index+3] == $rn[3];
        }
        self!parse($data, $index) if $index != $data.elems;
```

Now we need to write a crude request parsing method.  In preparation of that we're going to fill out `method middleware`, `method handler`, and `method after`.  Then we're going to call this article a wrap and do the parsing as another article.

The point of the methods above is to allow the user of the server to hook into three parts of the request life.

##### `method middleware`

Middleware is called whenever the headers are complete.  So, possibly before the request is fully received but definitely when the headers are explicitly complete.

##### `method handler`

Handlers are called when the request is complete; that means both the headers and request body are fully parsed.

##### `method after`

After-ware are called when the request is complete.  The `response` object should no longer be used to send data, and modifying the `request` object has no affect downstream.

For right now, all we need to do is add whatever `Sub` is passed into the methods above into their respective arrays.

```perl6
 method handler(Callable $sub) {
    @.handlers.push($sub);
  }

  method after(Callable $sub) {
    @.afters.push($sub);
  }

  method middleware(Callable $sub) {
    @.middleware.push($sub);
  }
```

Next up, request parsing and processing!
