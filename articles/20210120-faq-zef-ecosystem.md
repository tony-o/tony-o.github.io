faq: zef ecosystem
faq-zef-ecosystem
programming, rakudo

## What's fez and what's the zef eco?

Fez is the tool used for uploading your dists to the zef ecosystem.  Subquestion: why the name fez?  Surely it does the opposite of zef and should be named as such.

## What's being uploaded?

If you're in a git repo then fez is creating the archives using

```
git archive --format tar ...
gzip ...
```

If you're not in a git repo then it's using tar

```
tar -czf .
```

If you'd like to upload a hand rolled archive (tar.gz) then you can use

```
fez upload --file <path to your artisinal tar.gz>
```

## Why YAE (yet another ecosystem)?

we have p6c. (yup.)
we have cpan. (ok.)

what's wrong with these?

*Reason 1:* neither of those repositories are more than repositories.  There is no quality control or even minor checks.  If you have a PAUSE id, you can upload anything to cpan.  If you have a github login, you can submit a MR to get your module included in p6c.  The basic/big dist checks in raku come with looking at versions and looking at names.  Let's look at the name problem for both ecosystems.

cpan: the naming problem is that there is an index that only exists on name.  If you and your arch rival both upload a dist with the name Basketball that differ only by auth, then only one of yours is showing up in the main listing.

p6c: the naming problem here is a little more abhorrent.  if you and your nemesis both upload competing `Emulator::DOS` dists but in your haste you both do the minimum effort to make your module available then it's a crap shoot as to who can rule the ecosystem (hint: it's neither of you because my version is `*` which is another discussion).

*Reason 2:* `*` version wholly wrecks the current ecosystem.  Uploading a module with an asterisk version matches every module version with that name.  Interested in downloading the very nice `DB::Pg`? Too bad for you unless you want to type `zef install DB::Pg:auth<github:CurtTilmes>`. very. Time. Why? Because I just uploaded a dist with all of the same files/supplies with the word die; in them but the META version is `*`. `Version.new('*')` matches every version, so no matter which one you request, you can always get mine.

*Reason 3:* you can be reasonably sure who you're getting the actual tarball from on cpan.  You can, too, with git.  It's in the url.  You can't be reasonably sure where you got the file from post install because anything goes in the metas for both cpan and p6c.  This isn't the strongest of reasons but it's certainly important if you're going to allow multiple dists to share one name and you really need to figure out why `use XML;` seems to be flapping.

Are these reasons really that big that it necessitates an entirely new infrastructure and ecosystem?

Yes. When you hack together tools not built for the purpose then you'll always be hammering with the end of the screwdriver.  Your effort is spent making a system usable rather than starting from usable and making it awesome.  Submitting patches to cpan is great but it seems more than obnoxious to introduce side effects into a system that's serving perl so well.

### Other reasons in no particular order:

cpan: is very tedious to use and register with.

p6c: versions are volatile if specific commits aren't used in the source and getting bug fixes is irritating if the author forgets to update the meta (you can get around it with `zef install --force.`

## Where can I browse the zef ecosystem packages?

Currently only [rakuland](https://raku.land) is indexing the ecosystem in the browser.  If you'd like to just peek at everything available you can see the JSON index at [360.zef.pm](https://360.zef.pm).

## So what does zef eco do, then?

The zef eco has quality control around the version and auth of the dists being uploaded.

Does this dist already exist?  If yes, it won't be indexed.

An absent or `*` version is uploaded? Won't be indexed.

Does the META auth match the uploader?  If not, then it won't be indexed.

## Where's the server code, dude?

Short answer: there isn't any.

Longer answer: the ecosystem is running on AWS lambda, S3, and cloudfront.  All of the login/upload logic exists inside of a function in lambdas.  There are back ups but the code itself isn't organized in any way that it can be exposed.

## Indexing:

#### What happens if my module index fails?

You'll get an email.

#### How frequently does zef eco index?

As soon as you upload.  The TTL on caching (at this very moment) is set to two minutes, so you'll have to wait at least that long.
