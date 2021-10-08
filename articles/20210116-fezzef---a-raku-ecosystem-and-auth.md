fez|zef - a raku ecosystem and auth
fezzef---a-raku-ecosystem-and-auth
rakudo

fez is a utility for interacting with the zef ecosystem.  you can think of it as the opposite of zef. zef downloads distributions and installs them and fez uploads making them available to zef.

## how does this work?

here exists a myriad of ways in which to make an ecosystem for raku.  two current implementations include the current p6c (which is a text file of git repos) and, the other, cpan which works much in the same way as it does with perl (keeps an index based on `name`).  Both of these implementations present their own challenges when working with raku distributions, the challenges are too off topic to really get into in this article and they're left for a follow up article.

so! zef's ecosystem is built on top of s3, lambda, and cloudfront. for all intents and purposes it's a file system exposed over http.  there is a json index which is a master list of all available distributions enriched with the path those distributions can be had from (spoiler alert: it's a hash of the tar.gz file that gets uploaded and placed in a specific directory).  you can find the master list at https://360.zef.pm/index.json.  subsequently, you can information about specific names by using the name.  eg, a distribution named `fez` will have meta info available [here](https://360.zef.pm/F/EZ/FEZ/index.json)(names with `::` are converted `:: => \_` ).

ef's ecosystem also ensures that the auth matches.  one limitation of cpan is that you can upload under your PAUSE ID but the distribution you upload can contain any information in the meta (or no meta), including a meaningless auth value.  zef's ecosystem only indexes distributions whose meta<auth> match that of the uploader.  you can be reasonably assured that when you request `HTTP::Tiny:auth<zef:jjatria>` using the zef ecosystem that you're not getting something by the same dist name from someone who forked and forgot to update the meta information or any other shenanigans.

zef's ecosystem rejects any dist with a version of `*`. why is this?  because `*` supercedes every other possible version.  if zef allowed this then you could own the entire ecosystem by publishing a module with version `*` for every possible name, forcing consumers to specify version.

zef also does some basic sanity checks on the meta data.  if the uploaded module has a bad meta file then it's rejected by the fez indexer.  no more finding modules available that won't install because the meta data is bad.

## cool, what do i need to get started?

all you need is zef: check it out!

```
zef install fez
...
fez register
>>= Email: xyz@abc.com
>>= Username: tony-o
>>= Password:
>>= Registration successful, requesting auth key
>>= Login successful, you can now upload dists
>>= What would you like your display name to show? tony o
>>= What's your website? DEATHBYPERL6.com
>>= Public email address? xyz@abc.com
=<< Your meta info has been updated
```

now you're off and running.  once you have your module sitting pretty and ready for edgar to download it's only the simple command of:

```
my_module_dir$ fez upload
```

## what version of zef do i need?

zef > 0.10.0 should work with zef's ecosystem.

## why now?

ugexe and i spent a ton of time deliberating how this ecosystem should work back in 2013 when we started the zef project. if you're a sleuth you can dig through zef's commits, an ecosystem was up and alpha test worthy back then but the time wasn't right (beware of the easter dragons).  nine was working on precomp, zef was in its infancy, panda had its own (inflexible) way of being modularized, the state of the S# for distributions was in constant flux, there were far too many factors and possibilities to make pursuing the ecosystem sane.  if an ecosystem had been designed then it certainly wouldn't have lived up to the expectations and it would've either painted us into a corner regarding how dists work or choked on its own obsolescence and cruft.

## i want to contribute but don't know how

if you want to support the effort, PRs and feature ideas are always welcome.  you can find me as tony-o in #raku on freenode or, if supporting the cost of running the ecosystem is more your speed then you can donate here.
