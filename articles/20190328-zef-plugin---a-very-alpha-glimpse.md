zef plugin - a very alpha glimpse
zef-plugin---a-very-alpha-glimpse
programming, rakudo

**Disclaimer:** This design could change before zef plugins is thrown into the world but this is the initial look at the plugin paradigm and something you can follow along and actually use today.

Let's take a look at implementing a plugin to let us edit/view config from the CLI without firing up a text editor and editing zef's config manually.

## set up

Right now the plugin code is all residing in a branch other than zef master so we need to set up an alternate version of zef for us to use for the tutorial.  This tutorial will use the alias `zef-p` to denote the version of zef capable of plugins.  Doing a basic install using `zef-p install` will install modules the same as your system/local zef.

```
$ git clone https://github.com/ugexe/zef.git zef-p
# clones zef into directory zef-p
$ cd zef-p

zef-p$ git fetch origin allow-runtime-interface-plugins
# fetch the WIP plugins branch
zef-p$ git checkout allow-runtime-interface-plugins
# check out the plugins branch
zef-p$ alias zef-p="perl6 -I$(pwd)/lib $(pwd)/bin/zef"
# make an alias to make using our plugin capable zef easy to use
zef-p$ cd ..

$ # now we have zef-p available and the rest of the tutorial
```

## writing a plugin

The example we're going to use is a basic view, add, remove for `zef-p test` configuration.  We're going to add the commands `zef-p config` and `zef-p config.test` to zef in the rest of this tutorial.

### the skeleton

Creating your command is as easy as writing a script and putting it in the `bin/` directory of your module.  We'll go through the creation of `zef-p config` and `zef-p config.test`.

#### zef-p config

Create a file in your `bin/` directory called `zef-config`.

#### zef-p config.test

Create a file in your `bin/` directory called `zef-config.test`.

#### all done!

Not really. Let's add some functionality to `zef-config`!

### implementing zef-p config

Open your `bin/zef-config` file and add the following

```perl
multi MAIN('config') {
  note qq:to/END_USAGE/
    zef config - a plugin for zef config management

    zef config.test

      ls
        List all of the plugins zef has available for testing

      push --module (--comment?) (--short-name?)
        Appends the specified module to the test plugins

      remove index(Int)
        Removes the module from the config with index of Int

      prepend --module (--comment?) (--short-name?)
        Prepends the specified module to the test plugins
  END_USAGE
}
```

The part above to be most interested in is the use of `multi MAIN('config')`.  _This_ is the function that brings the functionality to `zef-p config` and it behaves as you'd expect of MAIN. The key part is the keyed in `'config'`. When an unknown $command is supplied to zef, say `zef-p config` out of the box, zef will search for any modules providing `bin/zef-$command` and will load them so if your module provides three different $command then you will need three bin scripts (or one depending on how symlink handy you are and expect your users to be).

A second note, these plugins are _not_ installed to your perl6 compunit repository.  This is to save zef from combing your normal CURs every time a command it doesn't recognize is received.

This will just print out our usage for `zef-p config.test`.  Just like that, when we `zef-p install --plugin .` (this plugin installation interface will likely change) we can then run `zef-p config` and it will show our usage.  The `--plugin` option is what tells zef-p to install in its private plugin CUR.

### implementing zef-p config.test

To keep the tutorial informative and less about how to write perl, we'll implement the `ls` feature and add the stubs for `push|remove|prepend` as described in our usage above.

In your `bin/zef-config.test`

```perl
use Zef;

sub pad (Int $w, Str $val) {
  sprintf(" %-{$w - 1}s", $val);
}

multi MAIN('config.test', 'ls') {
  my $idx = 0;
  my @widths  =
    max(7, $*zef.config.hash<Test>.elems.Str.chars), #indexes
    24,
    20,
    28,
  ;
  my @headers = 'index', 'module', 'short-name', 'comment';

  for |$*zef.config.hash<Test> -> $info {
    @widths[1] = max(@widths[1], ($info<module>//'').chars + 2);
    @widths[2] = max(@widths[2], ($info<short-name>//'').chars + 2);
    @widths[3] = max(@widths[3], ($info<comment>//'').chars + 2);
  }

  say '-' x 2 + ([+] @widths);
  say (0..^@headers.elems).map({ pad(@widths[$_], @headers[$_]) }).join('|');
  say '-' x 2 + ([+] @widths);

  for |$*zef.config.hash<Test> -> $info {
    say (
      pad(@widths[0], $idx++.Str),
      |(1..^@headers.elems).map({ pad(@widths[$_], $info{@headers[$_]}//'') })
    ).join('|');
  }

  say '-' x 2 + ([+] @widths);
}

multi MAIN('config.test', 'remove', Int $index) { ... }

multi MAIN('config.test', 'prepend', Str:D $module, Str :$short-name?, Str :$comment?) { ... }

multi MAIN('config.test', 'push', Str:D $module, Str :$short-name?, Str :$comment?) { ... }
```

Looking deeper into our `ls` command, you may notice `$*zef`.  That variable gives access to the config and setup that happens in `Zef::CLI`.  In the `ls` command we're using it to look at the config that was loaded from zef's configuration file, getting the width of columns to print out, and finally printing out all of the data we find in zef's config regarding `Test` plugins.  The output of that command is displayed later in this post.

### make our plugin installable

To make this plugin installable, we need a META6.json file.  Here is a barebones template (please, if you're releasing real modules into the ecosystem then put some effort and time into your META6.json files so others can read/understand them).

```json
{
  "perl": "6.d+",
  "name": "Zef::Plugin::PluginManager",
  "auth": "deathbyperl6:the-viewer",
  "description": "a zef plugin that supplies a partial cli to managing zef's config",
  "provides": { }
}
```

## install the plugin

So, we've created our `bin/` scripts to provide `zef-p config|config.test`.  Now it's time to install and test it out.

```
zef-p install --plugin .
```

As stated previously, `--plugin` will go away but at this time it's letting `zef-p` know that it should install our scripts to zef's private plugin CUR.  The other thing of note, shown below, is that a plugin's USAGE will override zef's _if_ the plugin successfully loads.

At this point you should be able to run the following commands:

```
λ ~/projects/zef-plugin-tutorial$ zef-p config
  zef config - a plugin for zef config management

  zef config.test

    ls
      List all of the plugins zef has available for testing

    push --module (--comment?) (--short-name?)
      Appends the specified module to the test plugins

    remove index(Int)
      Removes the module from the config with index of Int

    prepend --module (--comment?) (--short-name?)
      Prepends the specified module to the test plugins

λ ~/projects/zef-plugin-tutorial$ zef-p config.test ls
-------------------------------------------------------------------------------------
 index | module                     | short-name         | comment
-------------------------------------------------------------------------------------
 0     | Zef::Service::TAP          | tap-harness        | Perl6 TAP::Harness adapter
 1     | Zef::Service::Shell::prove | prove              |
 2     | Zef::Service::Shell::Test  | perl6-test         |
-------------------------------------------------------------------------------------

λ ~/projects/zef-plugin-tutorial$ zef-p config.test
Usage:
  /Users/tonyo/projects/zef-plugin-tutorial/zef/bin/zef config.test ls
  /Users/tonyo/projects/zef-plugin-tutorial/zef/bin/zef config.test remove <index>
  /Users/tonyo/projects/zef-plugin-tutorial/zef/bin/zef [--short-name=<Str>] [--comment=<Str>] config.test prepend <module>
  /Users/tonyo/projects/zef-plugin-tutorial/zef/bin/zef [--short-name=<Str>] [--comment=<Str>] config.test push <module>
```

## clean up

If you have installed any modules not using `--plugin` then they likely went into one of your \[pre]configured repositories and you can remove them with `zef uninstall` if you need to.  From here, to get rid of `zef-p` or start anew, just remove the `zef-p` directory we created when cloning `zef` in the **setup** phase of this post.

## conclusion

The code in this repo can be found [here](https://github.com/tony-o/perl6-zef-plugin-tutorial)

This is a barebones primer to extending the functionality of zef. If you have questions, thoughts, concerns please reach out to me @tony-o in #perl6 on freenode.  A `.tell` in that channel is helpful because I'm not always able to monitor.
