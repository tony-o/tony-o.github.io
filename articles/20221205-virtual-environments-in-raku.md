Virtual Environments in Raku
virtual-environments-in-raku
rakudo,programming

# Virtual Environments in Raku

Envious?  If not, run `zef install Envy` and let's start exploring virtual comp unit repositories.

Hold the phone!  What are we doing?  We're going to explore using a module allowing us to have virtual module environments in our very favorite raku.

Why do we want this?  Many reasons but a few would include:

- development & testing environments
- isolating module repositories by project/environment/something else
- using multiple versions of raku more safely

Sold? Continue on!

## Getting Started

Installing the environment manager is easy enough with `zef install Envy`.  Now for this tutorial we're going to build an interprocess worker pool that doesn't do anything but instead of installing everything globally, we'll get it done with a custom module repository.

In `parent.raku` dump the following:

```raku
use Event::Emitter::Inter-Process;

my $event = Event::Emitter::Inter-Process.new;

my Proc::Async $child .=new(:w, 'raku', '-Ilib', 'child.raku');

$event.hook($child);

$event.on('echo', -> $data {
  # got $data from child;
  say $data.decode;
});

$child.start;
sleep 1;


$event.emit('echo'.encode, 'hello'.encode);
$event.emit('echo'.encode, 'world'.encode);

sleep 5;
```

And then in `child.raku`:

```raku
use Event::Emitter::Inter-Process;

my $event = Event::Emitter::Inter-Process.new(:sub-process);

$event.on('echo', -> $data {
  "child echo: {$data.decode}".say;
  $event.emit('echo'.encode, $data);
});

sleep 3;
```

Okay, it's just the sample code but the program is not the focus.  On to installing `Event::Emitter::Inter-Process` to a virtual repo.

We need to create an environment and enable it before we can install our dependencies to it:

```
$ envy init tutorial
==> created tutorial
    to install to this repo with zef use:
      zef install --to='Envy#tutorial' <your modules>
$ envy enable tutorial
==> Enabled repositories: tutorial
$ zef install --to='Envy#tutorial' 'Event::Emitter::Inter-Process'
===> Searching for: Event::Emitter::Inter-Process
===> Searching for missing dependencies: Event::Emitter
===> Testing: Event::Emitter:ver<1.0.3>:auth<zef:tony-o>
===> Testing [OK] for Event::Emitter:ver<1.0.3>:auth<zef:tony-o>
===> Testing: Event::Emitter::Inter-Process:ver<1.0.1>:auth<zef:tony-o>
===> Testing [OK] for Event::Emitter::Inter-Process:ver<1.0.1>:auth<zef:tony-o>
===> Installing: Event::Emitter:ver<1.0.3>:auth<zef:tony-o>
===> Installing: Event::Emitter::Inter-Process:ver<1.0.1>:auth<zef:tony-o>
```

Now you should be able to just run your app:

```
$ raku parent.raku
child echo: hello
child echo: world
hello
world
```

And then if you disable the environment:

```
$ envy disable tutorial
==> Disabled repositories: tutorial
$ raku parent.raku
===SORRY!=== Error while compiling /private/tmp/parent.raku
Could not find Event::Emitter::Inter-Process in:
    Envy<3697577031872>
    ...
at /private/tmp/parent.raku:1
```

## Other Notes About Envy

Envy is in beta, there's likely some things that don't work quite right.  PRs are most welcome and bugs are appropriately welcome.  Both can be submitted [here](https://github.com/tony-o/envy/).
