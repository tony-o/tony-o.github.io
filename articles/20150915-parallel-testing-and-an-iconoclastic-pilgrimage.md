Parallel Testing and an Iconoclastic Pilgrimage
parallel-testing-and-an-iconoclastic-pilgrimage
programming, rakudo

# This is an article about `Green`

`Green` is a module I wrote with the intention of replacing the well loved `prove` command in favor of something that can parallel test all files and even perform parallel testing of functions inside of a test file.

Wait, what?

Don't worry, the parallel testing of functions doesn't mean all your code is going to run at once.  It means that you can put multiple test groups into one file and have those groups all tested in parallel while the methods in those groups retain their order and are executed in series.

This is confusing.

Let's take a look at an example, then we'll talk about how the module was put together.  Afterwards, more in depth examples.

```perl
use Green :harness;

set("Group 1", sub {
  test("Group 1, Test 1", sub { ok 1==1; });
  test("Group 1, Test 2", sub {
    sleep 2;
    ok 1==1;
  });
});

set("Group 2", sub {
  test("Group 2, Test 1", sub {
    sleep 1;
    ok 1==1; sleep 1;
  });
  test("Group 2, Test 2", sub {
    sleep 1;
    ok 1==1;
  });
});
```

Output:

```
   [P] Group 1
      [P] Group 1, Test 1
      [P] Group 1, Test 2

   [P] Group 2
      [P] Group 2, Test 1
      [P] Group 2, Test 2

   [P] 4 of 4 passing (2511.628ms)
```

Notice the runtime of 2.5 seconds.  Normally if you combined all four of those `test` groups into a series, you'd have ended up waiting around four seconds (Group 1 has a `sleep 2` and Group 2 has `sleep 1` twice).

*Please note that the startup time for my perl6 is anywhere between `500ms` and `1s`.

## Pitfalls & Considerations

* Output can get jumbled if you have multiple groups testing at the same time, `test()` output should be cached and wait for the `set` to be completed
* Tests should be able to return a promise, that promise will determine the result of the test
* Concision for simple and short test files
* Output of failing tests should be reserved for the end of the `set` to be completed, this provides a nicer output and aids in troubleshooting.  `prove` has always driven me nuts with trying to figure out the trace for the error
* Output from `say` and `warn` should be immediately written and unimpeded

#### Why is it such a big deal to have a `test` give its result as soon as its available?

This causes issues when tests fail.  When a test fails and you need to print the stack trace for the test, you can't guarantee that another test being executed in parallel isn't busy writing to the output.  This can cause jumbled or confusing stuff on the command line.  Imagine that two tests complete at roughly the same time, the first fails and needs to print the failure and then the stack trace.  The second completes with success and brags about its accomplishment to stdout between the time that the first test showed error and generated the stack trace information to be printed.  You'd end up with some output that looks roughly like

```
[F] #1 Failed test 1
[P] Passed test 2

#1 - not ok
  in block  at <path>.pm6:103
  in block  at <path>.pm6:94
```

Yes, that's manageable for two tests.  It's not when you have a test file with several tens or hundreds of tests in it.  It's certainly not manageable when you have several test files running at once, all trying to write at once.

There are other ways to deal with it, I think this solution is the cleanest and that's why Green is built in this way.

#### Other problems with parallelization and testing

There exists another big issue; what about when you want to do some asynchronous IO and don't want to have to handle setting up your own `await` and returning mechanisms to get the result?  `Green` handles this too.  If your test returns a `Promise` then `Green` will automatically await the promise and use its result as the output for the test result.  This is useful when you need to do things like non-blocking database calls or non-blocking file reads, reading data from channels, etc.  This also prevents `Green` from executing the next consecutive test until the `Promise` is `Kept|Broken`, this keeps `test`s executing in serial despite containing potentially a large amount of non-blocking code.

Why not let the user handle that?  The user can handle that, they just shouldn't return a `Promise` from the `test()`'s method.

#### Considerations

The main purpose of a testing suite is to make testing easy, having a stack trace not be a two step process, make the testing output simple to read, and to keep things simple.

##### Making test easy

To run `Green` against the current directory, you have to simply type `green` on the command line.  Done.

`Green` automatically `-Iblib -Ilib` and looks for the following directories in order `t/, test/, tests/`, stops on the first match and continues to test every file in that directory that ends with `.t`

Doesn't get much easier than that.

---

Another feature of `Green` is the quick testing shorthands.

```perl
use Green :harness;

>> { <Callable 1>; };
>> { <Callable 2>; };
```

This will execute both `Callable`s in series.

Too much crap?  Try again.

```perl
use Green :harness;

ok 1==1;
ok 2==1;
```

This is also acceptable shorthand.

---

Have some tests that require some parallel processing and don't want to deal with writing your own promise/result handlers?  Check this out

```perl
use Green :harness;

set('Set 1', sub {
  test('Test 1', -> $done {
    start {
      sleep 20; #let them wait
      $done();  #'Test 2' is now executed
    };
  });
  test('Test 2', {
    sleep 1;
    ok 1==1;
  });
});

```

When there is an extra parameter expected on the `Callable` that `test` is passed, `Green` handles tossing in a sub that the test can execute when it's done processing.  Easy doggone peasy.

#### Visibility on stack traces and easy to read output

My only really major complaint with `prove` is that it's a pain to get a stack trace.  Sure it gives me the first line, that's great.  Rarely is my issue on that first line of a stack trace.  `Green` took cues from other testing suites from other languages that are much easier to read.  Sample failure output from `Green` looks like the following:

```
tonyo@imac ~/projects/perl6-green/examples$ perl6 failure.pl6
   [F] Prefixed Tests
      [F] #1 - Prefixed 1
      [F] #2 - Prefixed 2

      #1 - not ok
         in block  at /Users/tonyo/projects/perl6-green/examples/../lib/Green.pm6:106
         in block  at /Users/tonyo/projects/perl6-green/examples/../lib/Green.pm6:97
      #2 - not ok
         in block  at /Users/tonyo/projects/perl6-green/examples/../lib/Green.pm6:106
         in block  at /Users/tonyo/projects/perl6-green/examples/../lib/Green.pm6:97

   [F] 0 of 2 passing (501.065ms)
```

Again, easy.

The output of this is easy to read.  `set`s are output all at once along with the failures.  Nothing is jumbled, it's just clean.

## Some more examples

###### Concise series

```perl
#!/usr/bin/env perl6

use lib '../lib';
use Green :harness;

#all of these tests should complete in 2 seconds
>> {
  sleep 2;
  ok 1 == 1;
};

>> {
  sleep 2;
  ok 1 == 1;
};
>> {
  sleep 2;
  ok 1 == 1;
};


>> { 1 == 1; }
```

```
   [P] Prefixed Tests
      [P] Prefixed 1
      [P] Prefixed 2
      [P] Prefixed 3
      [P] Prefixed 4

   [P] 4 of 4 passing (6528.732ms)
```

###### Failure

```perl
#!/usr/bin/env perl6

use lib '../lib';
use Green :harness;

ok 1 == 0, 'test';

>> sub {
  ok False;
}, 'not ok';
```

```
   [F] Prefixed Tests
      [F] #1 - Prefixed 1
      [F] #2 - Prefixed 2

      #1 - not ok
         in block  at /Users/tonyo/projects/perl6-green/examples/../lib/Green.pm6:106
         in block  at /Users/tonyo/projects/perl6-green/examples/../lib/Green.pm6:97
      #2 - not ok
         in block  at /Users/tonyo/projects/perl6-green/examples/../lib/Green.pm6:106
         in block  at /Users/tonyo/projects/perl6-green/examples/../lib/Green.pm6:97

   [F] 0 of 2 passing (535.971ms)
```

###### More Concise

```perl
#!/usr/bin/env perl6

use lib '../lib';
use Green :harness;


ok 1 == 1;

ok 0 == 1;

>> {
  ok 0 == 1;
};
```

```
   [F] Prefixed Tests
      [P] Prefixed 1
      [F] #1 - Prefixed 2
      [F] #2 - Prefixed 3

      #1 - not ok
         in block  at /Users/tonyo/projects/perl6-green/examples/../lib/Green.pm6:106
         in block  at /Users/tonyo/projects/perl6-green/examples/../lib/Green.pm6:97
      #2 - not ok
         in block  at /Users/tonyo/projects/perl6-green/examples/../lib/Green.pm6:106
         in block  at /Users/tonyo/projects/perl6-green/examples/../lib/Green.pm6:97

   [F] 1 of 3 passing (602.168ms)
```

###### Parallel Tests

```perl
#!/usr/bin/env perl6

use lib '../lib';
use Green :harness;

#all of these tests should complete in 2 seconds
set("time me 1", sub {
  test("delay 2", sub {
    sleep 2;
    ok 1==1;
  });
});
set("time me 2", sub {
  test("delay 2", sub {
    sleep 2;
    ok 1==1;
  });
});
set("time me 3", sub {
  test("delay 2", sub {
    sleep 2;
    ok 1==1;
  });
});
set("time me 4", sub {
  test("delay 2", sub {
    sleep 2;
    ok 1==1;
  });
});
```

```
   [P] time me 1
      [P] delay 2

   [P] time me 2
      [P] delay 2

   [P] time me 3
      [P] delay 2

   [P] time me 4
      [P] delay 2

   [P] 4 of 4 passing (2629.375ms)
```

###### Series

```perl
#!/usr/bin/env perl6

use lib '../lib';
use Green :harness;


set('Async tests in series', sub {
  test('Sleep 1', -> $done {
    start {
      sleep 1;
      ok 1==1;
      $done();
    };
  });

  test('Sleep 2', -> $done {
    start {
      sleep 2;
      ok 2 == 2;
      $done();
    };
  });
});

set('This happens async with the first set', sub {
  test('Sleep 1', -> $done {
    start {
      sleep 1;
      ok 1==1;
      $done();
    };
  });
});
```

```
   [P] This happens async with the first set
      [P] Sleep 1

   [P] Async tests in series
      [P] Sleep 1
      [P] Sleep 2

   [P] 3 of 3 passing (3572.252ms)
```

# Final thoughts

Comments or PRs are welcome.  You can find the repository for `Green` [here](https://github.com/tony-o/perl6-green).  You can leave your rude dude peanut gallery in #perl6 if you're so inclined.
