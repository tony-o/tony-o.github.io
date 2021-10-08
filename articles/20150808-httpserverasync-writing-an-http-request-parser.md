HTTP::Server::Async: Writing an HTTP Request Parser
httpserverasync-writing-an-http-request-parser
rakudo

This is part 2 of a 2 part series.  You may want to check out the [first part](http://deathbyperl6.com/refactoring-httpserverasync/) if you haven't already.

You're still following along.  You're a sadist, we get it.  We're going to jump right into it.

We're on step 4 of our 5 part plan, remember:

1. ~~A connection is requested~~
2. ~~Connection is accepted~~
3. ~~Client sends an HTTP request~~
4. __Server processes the requests__
  1. Parse cookies (this is middleware, we're not going to do this in the server right now)
  2. Response handler needs to handle chunked and binary encoding, etc (we'll implement this)
  3. Certain headers expect the connection to behave differently, IE upgrade to HTTP/2.0, websocket, etc (we're going to create the mechanism to allow this to happen)
  4. Pipelining requests will be supported
5. Server sends response to client

Our first order of business is reading data from the connection and detecting the end of headers.  If you recall from the last article, we need to process headers and run middleware if the headers are complete.  We've detected the end of a chunk of headers in the last article, time to parse.

The first part of parsing is implementing `HTTP::Request` so we have something to fill up with URI, method, etc data.

Here's our starter template for HTTP::Request:

```perl6
use HTTP::Request;

class HTTP::Server::Async::Request does HTTP::Request {
  has Bool $.complete is rw = False;
  has $.connection is rw;
}
```

`connection` and `complete` aren't required by HTTP::Request, we're using this internally.

Now we'll implement the `self!parse` method we used in the last article.  Now we're actually parsing an HTTP request and parsing headers, getting the URI, the method, etc.

```perl6
  method !parse($data is rw, $index is rw, $req is rw, $connection) {
    $req = Nil if $req !~~ Nil && $req.^can('complete') && $req.complete;
    if $req ~~ Nil || !( $req.^can('headers') && $req.headers.keys.elems ) {
      my @lines       = Buf.new($data[0..$index]).decode.lines;
      my ($m, $u, $v) = @lines.shift.match(/^(.+?)\s(.+)\s(HTTP\/.+)$/).list.map({ .Str });
      my %h           = @lines.map({ .split(':', 2).map({.trim}) });

      $req    = HTTP::Server::Async::Request.new(
                  :method($m), 
                  :uri($u), 
                  :version($v), 
                  :headers(%h), 
                  :connection($connection),
                  :response(HTTP::Server::Async::Response.new(:$connection)));
      $req.data .=new;
      $index += 4;
      $data   = Buf.new($data[$index+1..$data.elems]);
      $index  = 0;
      for @.middlewares -> $m {
        try {
          CATCH {
            default {
              .say;
            }
          }
          my $r = $m.($req, $req.response);
          return if self!rc($r);
        };
      }
    }
```

In the beginnings of the parse method, we're checking to see if the $req is already created and we're continuing the previous request or if we need a new req/res pair.  

After that, if we need a new req/res pair then we create one.  It's important that the response be a part of the request because we want to support pipelining.  Pipelining can be read about [here](https://en.wikipedia.org/wiki/HTTP_pipelining).

After that, if the headers are complete then we run through our middleware with the request and allow them to hijack the request if they want.  This is useful for things like `websocket`s and other types of custom applications.

```perl6
    if $req !~~ Nil && $req.header('Transfer-Encoding').lc.index('chunked') !~~ Nil {
      my ($i, $bytes) = 0,;
      my Buf $rn .=new("\r\n".encode);
      while $i < $data.elems {
        $i++ while $data[$i]   != $rn[0] &&
                   $data[$i+1] != $rn[1] &&
                   $i + 1 < $data.elems;
        last if $i + 1 >= $data.elems;

        $bytes = :16($data.subbuf(0,$i).decode);
        last if $data.elems < $i + $bytes;
        { $req.complete = True; last; } if $bytes == 0;
        $i+=2;
        $req.data ~= $data.subbuf($i, $i+$bytes-3);
        try $data .=subbuf($i+$bytes+2);
        $i = 0;
      }
    } else {
      my $req-len = $req.header('Content-Length')[0] // ($data.elems - $index);
      if $data.elems - $req-len >= 0 {
        $req.data     = Buf.new($data[0..$req-len]); 
        $req.complete = True;
        $data = Buf.new($data[$req-len..$data.elems]);
      }
    }
    $.requests.send($req) if $req.^can('complete') && $req.complete;
  }
```

Next up we just handle processing chunked encoding or detecting the end of the request and filling in the request body (if needed).  

If the request is complete then we send it off to be handled by the request handlers.

You may notice that the last line (`$.requests`) isn't discussed anywhere else in the blog.  This application is using a `Channel` to detect the end of requests.  Here is the relevant code

######Setting up the channel as an attribute of our server
```perl6
class HTTP::Server::Async does HTTP::Server {
  has Int     $.port          = 1666;
  has Str     $.ip            = '0.0.0.0';
  has Channel $.requests     .= new; #added for this blog
```
######Setting up the handler to work asynchronously of the parser and listener
```perl6
  method !responder {
    start {
      loop {
        CATCH { default { .say; } }
        my $req = $.requests.receive;
        my $res = $req.response;
        for @.handlers -> $h {
          try {
            CATCH {
              default {
                .say;
              }
            }
            my $r = $h.($req, $res);
            last if self!rc($r);
          };
        }

        for @.afters -> $a {
          try {
            CATCH {
              default {
                .say;
              }
            }
            $a.($req, $res);
          }
        }
      };
    };
  }
```

Yes, I'm aware that the variable names aren't awesome.  Nothing compares the awesomenity of this module.  Check out the final code on [github.com](https://github.com/tony-o/perl6-http-server-async/).  I crave your stars.
