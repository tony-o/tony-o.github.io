Adding on to Channels and Supplies in Perl6
adding-on-to-channels-and-supplies-in-perl6
programming, rakudo

Channels and supplies are perl6's way of implementing the Oberserver pattern.  There's some significant differences behind the scenes of the two but both can be used to implement a `jQuery.on("event"` like experience for the user.  Not a jQuery fan?  Don't you worry your pretty little head because this is perl6 and it's much more fun than whatever you thought.

## Why?

Uhh, why do we want this?

This adds some sugar to the basic reactive constructs and it makes the passing of messages a lot more friendly, readable, and manageable.

## What in Heck Does that Look Like?

Let's have an example and then we'll dissect it.

### A Basic Example

```perl
use Event::Emitter;
my Event::Emitter $e .= new;

$e.on(/^^ .+ $$/, -> $data {
  # you can operate on $data here
  '  regex matches'.say;
});

$e.on({ True; }, -> $data {
  '  block matches'.say;
});

$e.on('event', -> $data {
  '  string matches'.say;
});

'event'.say;
$e.emit("event", { });

'empty event'.say;
$e.emit("", { });

'abc'.say;
$e.emit("abc", { });
```

__Output__ _* this is the output for an emitter using `Supply`, more on this later_

```
event
  regex matches
  block matches
  string matches
empty event
  block matches
abc
  regex matches
  block matches
```

Okay, that looks like a lot.  It is, and it's much nicer to use than a large `given`/`when` combination.  It also reduces indenting, so you have that going for you, which is nice.

Let's start with the simple `.on` blocks we have.
```perl
  $e.on(/^^ .+ $$/, -> $data { ...
```
This is telling the emitter handler that whenever an event is received, run that regular expression against it and if it matches, execute the block (passed in as the second argument).  As a note, and illustrated in the example above, the handler can match against a `Callable`, `Str`, or `Regex`.  The `Callable` must return `True` or `False` to let the handler know whether or not to execute the block.

If that seems pretty basic, it is.  But little things like this add up over time and help keep things manageable.  Prepare yourself for more convenience.

### The Sugar

_Do you want ants?  This is how you get ants._

So, now we're looking for more value in something like this.  Here it is: you can inherit from the `Event::Emitter::Role::Template` (or roll your own) and then your classes will automatically inherit these `on` events.

##### Example

```perl
use Event::Emitter::Role::Template;

class ZefClass does Event::Emitter::Role::Template {
  submethod TWEAK {
    $!event-emitter.on("fresh", -> $data {
      'Aint that the freshness'.say;
    });
  }
}
```

Then, further along in your application, whenever an object wants `ZefClass` to react to the `'fresh'` event, all it needs to do is:
> `$zef-class-instance.emit('fresh');`

Pretty damn cool.

Development time is reduced significantly for a few reasons right off the bat:

1. Implementing `Supplier` (or `Channel`) methods, setup, and event handling becomes unnecessary
2. Event naming or matching is handled so it's easy to debug
3. Handling or adding new event handling functions during runtime (imagine a plugin that may want to add more events to handle - like an IRC client that implements a handler for channel parting messages)
4. Messages can be multiplexed through one Channel or Supply rather easily
4. Creates more readable code

That last reason is a big one.  Imagine going back into one of your modules 2 years from now and debugging an issue where a `Supplier` is given an event and some data and digging through that 600 lines of `given`/`when`.

Worse, imagine debugging someone else's.

## A Quick Note on `Channel` vs `Supply`

The `Channel` and `Supply` thing can take some getting used to for newcomers.  The quick and dirty is that a `Channel` will distribute the event to only __one__ listener (chosen by the scheduler) and order isn't guaranteed while a `Supply` will distribute to all listeners and the order of the messages are distributed in the order received.  Because the `Event::Emitter` `Channel` based handler executes the methods registered with it directly, when it receives a message _all_ of your methods are called with the data.

So, you've seen the example above as a `Supply` based event handler, check it out as a `Channel` based and note the difference in `.say` and the instantiation of the event handler.

```perl
use Event::Emitter;
my Event::Emitter $e .= new(:threaded); # !important - this signifies a Channel based E:E

$e.on(/^^ .+ $$/, -> $data {
  # you can operate on $data here
  "  regex matches: $data".say;
});

$e.on({ True; }, -> $data {
  "  block matches: $data".say;
});

$e.on('event', -> $data {
  "  string matches: $data".say;
});

'event'.say;
$e.emit("event", "event");

'empty event'.say;
$e.emit("", "empty event");

'abc'.say;
$e.emit("abc", "abc");
```

__Output__

```
event
empty event
abc
  regex matches: event
  block matches: event
  string matches: event
  block matches: empty event
  regex matches: abc
  block matches: abc
```

