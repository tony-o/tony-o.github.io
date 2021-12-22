The Life of Raku Module Authoring
the-life-of-raku-module-authoring
rakudo, programming

Hello, world! This article is a lot about `fez` and how you can get started writing your first module and making it available to other users. Presuming you have `rakudo` and `zef` installed, install `fez`!

```
$ zef install fez
===> Searching for: fez
===> Updating fez mirror: https://360.zef.pm/
===> Updated fez mirror: https://360.zef.pm/
===> Testing: fez:ver<32>:auth<zef:tony-o>:api<0>
[fez]   Fez - Raku / Perl6 package utility
[fez]   USAGE
[fez]     fez command [args]
[fez]   COMMANDS
[fez]     register              registers you up for a new account
[fez]     login                 logs you in and saves your key info
[fez]     upload                creates a distribution tarball and uploads
[fez]     meta                  update your public meta info (website, email, name)
[fez]     reset-password        initiates a password reset using the email
[fez]                           that you registered with
[fez]     list                  lists the dists for the currently logged in user
[fez]     remove                removes a dist from the ecosystem (requires fully
[fez]                           qualified dist name, copy from `list` if in doubt)
[fez]     org                   org actions, use `fez org help` for more info
[fez]   ENV OPTIONS
[fez]     FEZ_CONFIG            if you need to modify your config, set this env var
[fez]   CONFIGURATION (using: /home/tonyo/.fez-config.json)
[fez]     Copy this to a cool location and write your own requestors/bundlers or
[fez]     ignore it and use the default curl/wget/git tools for great success.
===> Testing [OK] for fez:ver<32>:auth<zef:tony-o>:api<0>
===> Installing: fez:ver<32>:auth<zef:tony-o>:api<0>

1 bin/ script [fez] installed to:
/home/tonyo/.local/share/perl6/site/bin
```

Make sure that the last line is in your `$PATH` so the next set of commands all run smoothly. Now we can start writing the actual module, let's write ROT13 since it's a fairly easy problem to solve and this article really is less about module content than how to get working with `fez`.

## Writing the Module

Our module directory structure:

```
.
├── lib
│   └── ROT13.rakumod
├── t
│   ├── 00-use.rakutest
│   └── 01-tests.rakutest
└── META6.json
```

`lib` is the main content of your module, it's where all of your module's utilities, helpers, and organization happens.  Each file corresponds to one or more modules or classes, more on this in the META topic.

`t` contains all of your module's tests.  If you have author only tests then you'd also have a directory `xt` and that directory works roughly the same. For your users' sanity WRITE TESTS!

`META6.json` is how zef knows what the module is, it's how fez knows what it's uploading, and it's how rakudo knows how to load what and from where. Let's take a look at the structure of META6.json:

```json
{
  "name": "ROT13",
  "auth": "zef:tony-o",
  "version": "0.0.1",
  "api": 0,

  "provides": {
    "ROT13": "lib/ROT13.rakumod"
  },

  "depends":       [],
  "build-depends": [],
  "test-depends":  [],

  "tags":        [ "ROT13", "crypto" ],
  "description": "ROT13 everything!"
}
```

A quick discussion about `dist`s.  A `dist` is the fully qualified name of your module and it contains the `name, auth, and version`.  It's how `zef` can differentiate your ROT13 module from mine. It works in conjunction with `use` eg `use ROT13:auth<zef:tony-o>` and in `zef` eg `zef install ROT13:auth<tony-o>:ver<0.0.1>`.  The dist string is always qualified with both the `:auth` and the `:ver` internally to raku and the ecosystem, but the end user isn't required to type the fully qualified `dist` if they're less picky about what version/author of the module they'd like. In `use` statements you can combine `auth` and `ver` to get the author or version you're expecting or you can omit one or both.

It's better practice to fully qualify your `use` statements; as more modules hit the ecosystem with the same `name`, this practice will help keep your modules running smoothly.

* `name`: this is the name of the module and becomes part of your `dist`, it's what is referenced when your consumers type `zef install ROT13`.
* `auth`: this is how the ecosystem knows who the author is.  On fez this is strict, no other rakudo ecosystem guarantee this matches the uploader's username.
* `version`: version must be unique to the `auth` and `name`.  Eg you can't upload two `dists` with the value of `ROT13:auth<zef:tony-o>:ver<0.0.1>`.
* `provides`: in provides is the key/value pairs of module and class names to which file they belong to.  If you have two modules in one file then you should have the same file listed twice with the key for each being each class/module name. All `.rakumod` files in `lib` should be in the META6.json file.  The keys here are how rakudo knows which file to look for your class/module in.
* `depends`: a list of your runtime depencies

Let's whip up a quick ROT13 module, in `lib/ROT13.rakumod` dump the following

```raku
unit module ROT13;

sub rot13(Str() $_) is export { .trans('a..zA..Z'=>'n..za..mN..ZA..Z') }
```

Great, you can test it now (from the root of your module directory) with `raku -I. -e 'use ROT13; say rot13("hello, WoRlD!");`. You should get output of `uryyb, JbEyQ!`.

Now fill in your test files and run the tests with `zef test .`

## Publishing Your Module

### Register

If you're not registered with fez, now's the time!

```
$ fez register
>>= Email: omitted@somewhere.com
>>= Username: tony-o
>>= Password:
>>= Registration successful, requesting auth key
>>= Username: tony-o
>>= Password:
>>= Login successful, you can now upload dists
```

### Check Yourself

```
$ fez checkbuild
>>= Inspecting ./META6.json
>>= meta<provides> looks OK
>>= meta<resources> looks OK
>>= ROT13:ver<0.0.1>:auth<zef:tony-o> looks OK
```

Oh snap, we're lookin' good!

### Publish

```
$ fez upload
>>= Hey! You did it! Your dist will be indexed shortly.
```

Only thing to note here is that if there's a problem indexing your module then you'll receive an email with the gripe.

## Further Reading

You can read more about `fez` here:

* [(FEZ|ZEF) - A Raku Ecosystem and Auth](https://deathbykeystroke.com/articles/20210116-fezzef---a-raku-ecosystem-and-auth.html)
* [faq: zef ecosystem](https://deathbykeystroke.com/articles/20210120-faq-zef-ecosystem.html)
* [Fez Orgs: A Winter Solstice Miracle](https://deathbykeystroke.com/articles/20211220-fez-orgs-a-winter-solstice-miracle.html)

Perhaps you'd prefer listening:

* [Fez/Zef, an Ecosystem and the Architecture](https://conf.raku.org/talk/143)

That's it! If there's other things you'd like to know about fez, zef, or ecosystems then send `tony-o` some chat in IRC or an email!
