Fez Goes Full Dist
fez-goes-full-dist
rakudo,programming

# Fez Goes Full Dist

SWEET! What does that mean?

- initialize dist skeletons with `init`
- manage depends, build-depends, and resources
- add and run commands to the repo with `command`
- better dist review with `review`
- gitignore globbing
- better usage statements and command guessing for when you're stuck
- short commands and flags!
- fez goes full debug

There exists a few dist management tools already so, where's the motivation to move this project into the dist management space?  Well, `fez` is mostly a one-person show and features are added as time allows.  Time has finally allowed and the main reason for not contributing to other modules is as one of the authors of zef and both of these tools aim for zero dependencies, sometimes with great effort. The effort always pays off for our users who don't have to watch their terminal history balloon as the dependency chain is calculated.  It just downloads and installs. It's in mind that a zero dependency option *should* be available and it wasn't.

Enough philosophy already let's get to the FEATURES!

## `fez init [<module>]`

Running `fez init` will prompt you for a module name unless your provided one as an argument.  This is asking for the initial module you'd like to create and generates a dist name for it:

```
$ fez init MyShiny::Module
```

```
$ tree MyShiny--Module/
MyShiny--Module/
├── lib
│   └── MyShiny
│       └── Module.rakumod
├── META6.json
└── t
    └── 00-use.rakutest

3 directories, 3 files
```

```
$ cat MyShiny--Module/META6.json
{
  "auth": "zef:tony-o",
  "build-depends": [
  ],
  "depends": [
  ],
  "description": "A brand new and very nice module",
  "name": "MyShiny--Module",
  "provides": {
    "MyShiny::Module": "lib/MyShiny/Module.rakumod"
  },
  "resources": [
  ],
  "version": "0.0.1"
}
```

The rest of the examples are going to use this repo and update that meta.

## Manage Depends, Build-Depends, and Resource

Let's say we're developing and BOOM, suddenly we need FNV hashing.  We can add that dependency to the META with the command:

```
$ fez depends Digest::FNV
>>= Digest::FNV was not found in depends so it was added

```

```
$ cat META6.json
{
  "auth": "zef:tony-o",
  "build-depends": [
  ],
  "depends": [
    "Digest::FNV"
  ],
  "description": "A brand new and very nice module",
  "name": "MyShiny--Module",
  "provides": {
    "MyShiny::Module": "lib/MyShiny/Module.rakumod"
  },
  "resources": [
  ],
  "version": "0.0.1"
}
```

That's it.  That's all there is to it.

### Build Depends

To add a build depends you'd just pass the flag `-b` or `--build`:

```
$ fez depends -b Test
>>= Test was not found in build-depends so it was added
```

```
$ cat META6.json
{
  "auth": "zef:tony-o",
  "build-depends": [
    "Test"
  ],
  "depends": [
    "Digest::FNV"
  ],
  "description": "A brand new and very nice module",
  "name": "MyShiny--Module",
  "provides": {
    "MyShiny::Module": "lib/MyShiny/Module.rakumod"
  },
  "resources": [
  ],
  "version": "0.0.1"
}
```

### Resources

And, for resources, it's as simple as:

```
$ fez resource templates/abc
>>= Resource is not in META, adding it
$ fez resource templates/123
>>= Resource is not in META, adding it
```

```
$ cat META6.json
{
  "auth": "zef:tony-o",
  "build-depends": [
    "Test"
  ],
  "depends": [
    "Digest::FNV"
  ],
  "description": "A brand new and very nice module",
  "name": "MyShiny--Module",
  "provides": {
    "MyShiny::Module": "lib/MyShiny/Module.rakumod"
  },
  "resources": [
    "templates/abc",
    "templates/123"
  ],
  "version": "0.0.1"
}
```

```
$ tree resources/
resources/
└── templates
    ├── abc
    └── 123

1 directory, 2 files
```

Note that we didn't have to specify `resources` as a directory in the resource we needed and we also didn't have to manually create any directories.


## Commands

To view available commands and what they do:

```
$ fez command
>>= test: zef test .
```

Note: this will create a `.zef` file in the repo that will also be mentioned later. You can use this file to add other commands.

This shows that running `fez run test` will shell out `zef test .`:

```
$ fez run test
>>= INFO: ===> Testing: MyShiny--Module:ver<0.0.1>:auth<zef:tony-o>
>>= INFO: ===> Testing [OK] for MyShiny--Module:ver<0.0.1>:auth<zef:tony-o>
```

## Review

`fez review` can be used to inspect the current repo.  This command no longer looks at dist files, it inspects what's on disk and what fez would bundle.  If we run it right now then we'll see it does in fact catch a weird case, we've added `Digest::FNV` to our depends but don't actually use it in the code:

```
$ fez review
>>= Bundle manifest:
      .zef
      lib/MyShiny/Module.rakumod
      META6.json
      resources/templates/template1
      resources/templates/template2
      t/00-use.rakutest
>>= Build depends ok
>>= Depends not ok
>>=   in meta but unexpected:
        Digest::FNV
>>= Provides ok
>>= Resources ok
```

Cool. But what if i want it to be a depends anyway and not have fez complain about it?  You can now control what fez gripes about with the `.zef` config file. We'll need an entry in that file:

```json
{
  ...,
  "ignore-depends": ["Digest::FNV"]
}
```

Now, fez does what we want:

```
$ fez review
>>= Bundle manifest:
      .zef
      lib/MyShiny/Module.rakumod
      META6.json
      resources/templates/template1
      resources/templates/template2
      t/00-use.rakutest
>>= Build depends ok
>>= Depends ok
>>= Provides ok
>>= Resources ok
```

The key in that .zef file is `ignore-<META6 key>` so all of the following work: `ignore-depends`, `ignore-resources`, `ignore-provides`, and `ignore-build-depends`.  The odd one out is `ignore-provides` as that is the only hash, this one works on the key of that hash.


Why not fix `checkbuild`?

`fez checkbuild` has been buggy for a while.  It was designed to work with varying methods of compression including `git archive`, `tar | gzip`, and manual methods. There is a lot of code around extracting (in memory) and inspecting and a lot of confusion about the different methods used in packaging the dist. What you saw wasn't always what you got.  `checkbuild` did its best to navigate that chaos but as `fez` simplified its bundling strategies the `checkbuild` command was solving an increasingly different problem.  Better to tear it out and give it a better name and focus.

## GitIgnore Globbing

The globber that shipped around v38 was a strict type globber.  After some fiddling it's much closer to what you'd get from a .gitignore file and can be used either way. This shipped in v45 so please update if you've been manually bundling and give the new globber a go.

## Usage Statements and Short Commands/Flags

`fez` used to just spit out generic USAGE.  NOT ANYMORE, PEOPLE. Some examples:

### Command Guessing

```
$ fez org
Fez - Raku dist manager

Did you mean any of the following?
  fez org
  fez org accept
  fez org create
  fez org invite
  fez org leave
  fez org list
  fez org members
  fez org meta
  fez org modify
  fez org pending
```

```
$ fez me
Fez - Raku dist manager

Did you mean any of the following?
  fez meta
  fez org members
  fez org meta
```

### Better Help for Specific Commands

Each command also gets short flags/commands. They can be seen in the usage statements for those commands:

```
$ fez run -h
Fez - Raku dist manager

USAGE

  fez r <command> [-t]

  fez run <command> [--timeout=300]

FLAGS

  OPTIONAL

  -t|--timeout            number of seconds the command will be allowed to run
                          for prior to fez attempting to kill the process.

Runs a command with timeout. Available commands can be shown with `fez command`
```

Enjoy.

## Full Debug

Another added a feature that should help both with bug reports and your understanding of `fez` is the magical `-v` flag.  This flag is universal and will produce a large output in most cases but you'll see exactly what's happening and when:

```
$ fez -v upload
>>= INFO: setting log level: DEBUG
>>= DEBUG: found META6.json in .
>>= DEBUG: scanning files in lib
>>= DEBUG: manifest:
             lib/MyShiny/Module.rakumod
>>= DEBUG: looking for modules/classes in those files
>>= DEBUG: [lib/MyShiny/Module.rakumod]: provides: MyShiny::Module
>>= DEBUG: depends:
>>= DEBUG: lib-files:
             lib/MyShiny/Module.rakumod => [1]
>>= DEBUG: provides:
             MyShiny::Module => [lib/MyShiny/Module.rakumod]
>>= DEBUG: use:
>>= DEBUG: {
             "auth": "zef:tony-o",
             "build-depends": [
               "Test"
             ],
             "depends": [
             ],
             "description": "A brand new and very nice module",
             "name": "MyShiny--Module",
             "provides": {
               "MyShiny::Module": "lib/MyShiny/Module.rakumod"
             },
             "resources": [
               "templates/template1",
               "templates/template2"
             ],
             "version": "0.0.1"
           }
>>= Bundle manifest:
      .zef
      lib/MyShiny/Module.rakumod
      META6.json
      resources/templates/template1
      resources/templates/template2
      t/00-use.rakutest
>>= Build depends ok
>>= Depends ok
>>= Provides ok
>>= Resources ok
>>= DEBUG: Tarring manifest:
             .zef
             sdist
             META6.json
             resources/templates/template2
             resources/templates/template1
             t/00-use.rakutest
             lib/MyShiny/Module.rakumod
>>= DEBUG: tarred data 6656 bytes
>>= DEBUG: zlib: opening /tmp/MyShiny--Module/sdist/WMwlHtCq.tar.gz for writing
>>= DEBUG: [WGET:starting]
>>= DEBUG: [WGET:out] {"success": true, "key": "https://zef360<snip>"}
>>= DEBUG: [WGET:exit 0]
>>= DEBUG: [WGET:starting]
>>= DEBUG: [WGET:err] --2023-03-29 08:52:46--  https://zef360<snip>
           Resolving zef360<snip> (zef360<snip>)... 3.5.87.140, 52.92.165.130, 52.92.165.162, ...
           Connecting to zef360<snip> (zef360<snip>)|3.5.87.140|:443... connected.
           HTTP request sent, awaiting response... 200 OK
           Length: 0
           Saving to: ‘STDOUT’

                0K                                                        0.00 =0s

           2023-03-29 08:52:47 (0.00 B/s) - written to stdout [0/0]
>>= DEBUG: [WGET:exit 0]
>>= Hey! You did it! Your dist will be indexed shortly.
```

Here we can inspect what's happening in `fez`.  It's using zlib to package the modules, wget to distribute, etc etc.

PLEASE include this output in bug reports moving forward.
