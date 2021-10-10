Speed Quest 1.0, or 0.1, or something
speed-quest-10-or-01-or-something
programming, rakudo

## JSON Headaches

In writing `zef`, a major bottleneck in the quest for speed was the `to-json` method provided by ecosystem modules and the built-in method.  I wasn't prepared to wait 90 seconds (that's almost a minute and a half!) for the `CompUnitRepo::Local::Installation` (CURLI henceforth) to be rewritten to include newly installed modules/files.

I'm an impatient man.  I want JSON but I don't want to wait for it because waiting stinks.

So, we'll begin our quest for speed on generating some JSON from a perl6 `Hash` or `Array`.

For this article I'm going to be using `built-in`s, `JSON::Tiny` (`JSON::Fast` is a copy from `Tiny`), and `Bench`.

## How much do you bench, bro?

I'll run 30 iterations of each, 3 in instances where I don't want to wait 4 hours for this to happen.

### Built-in `to-json`

#### Benchmark code

```perl6
use Bench;

my $json = from-json('projects.json'.IO.slurp);

Bench.new.timethis(3, sub { to-json($json); });
```

#### Results

```
  built-in: 297.9738 wallclock secs @ 0.0101/s (n=3)
                		(warning: too few iterations for a reliable count)
```

That's painfully slow.  I couldn't wait longer than `n=3` before I lost interest.

### JSON::Fast

#### Benchmark code

```perl6
use Bench;
use JSON::Fast;

my $json = from-json('projects.json'.IO.slurp);

Bench.new.timethis(3, sub { to-json($json); });
```

#### Results

```
 json-fast: 295.2473 wallclock secs @ 0.0102/s (n=3)
                		(warning: too few iterations for a reliable count)
```

### Conclusion
Same.  Too slow and I don't want to sit around waiting for this one to complete.  296 seconds is too long to wait.

I must do something about this.

## What I wrote

I ended up writing a very simplistic recursive method as a comparative speed test.  It turned out to be super fast on the first try (at least compared to `built-in` and `J:F`).

Here is the code from the initial commit

```perl6
sub to-json($obj, Bool :$pretty? = True, Int :$level? = 0, Int :$spacing? = 2) is export {
  CATCH { default { .say; } }
  return "{$obj}"     if $obj ~~ Int || $obj ~~ Rat;
  return "\"{$obj.subst(/'"'/, '\\"', :g)}\"" if $obj ~~ Str;

  my Str  $out = '';
  my Int  $lvl = $level;
  my Bool $arr = $obj ~~ Array;
  my $spacer   = sub {
    $out ~= "\n" ~ (' ' x $lvl*$spacing) if $pretty;
  };

  $out ~= $arr ?? '[' !! '{';
  $lvl++;
  $spacer();
  if $arr {
    for @($obj) -> $i {
      $out ~= to-json($i, :level($level+1), :$spacing, :$pretty) ~ ',';
      $spacer();
    }
  } else {
    for $obj.keys -> $key {
      $out ~= "\"{$key.subst(/'"'/, '\\"', :g)}\": " ~ to-json($obj{$key}, :level($level+1), :$spacing, :$pretty) ~ ',';
      $spacer();
    }
  }
  $out .=subst(/',' \s* $/, '');
  $lvl--;
  $spacer();
  $out ~= $arr ?? ']' !! '}';
  return $out;
}
```

Yea, there are a few bugs that were discovered since and have been fixed.  But the benchmark results of that were:

```
json-faster: 5.9204 wallclock secs @ 0.5067/s (n=3)
               		(warning: too few iterations for a reliable count)
```

Not great, but that's 292 seconds you won't be sitting around cleaning your nose.

Awesome.

PS A PR has been submitted to `JSON::Fast` to include the faster `to-json` method and includes the bug fixes.  If you'd like to check that out, check [here](https://github.com/timo/json_fast/pull/2)
