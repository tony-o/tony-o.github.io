Oslo PTS 2018; Chains, tools, and reindeer
oslo-pts-2018-chains-tools-and-reindeer
programming

This year at PTS we picked up where we left off last year, talking about the build system, dependency chains, and walking to the next food spot.  Last year we had developed perl6 Warthog.  Warthog is a hash "collapser" that works on OS \[distro|kernel\] and environment variables.  This allows you to do things like determine native dependencies (like libcrypt in linux vs libgcrypt on osx) in your META6.json.  An example of that [here](https://github.com/tony-o/p6-warthog).  So, that was last year.

This year I worked mainly on integrating that into zef.  Nine worked on [Distribution::Builder::MakeFromJSON](https://github.com/niner/Distribution-Builder-MakeFromJSON) and integrated support for that into zef.  Ugexe also worked on that integration and improved the S22 support for `depends` allowing `:from<native|bin>` signalling native lib or bin requirements in the meta (and coralling/giving direction to nine and me)

The other thing I worked on is ancillary to zef and something we hope to integrate in the future to increase the speed of determining and building dependencies. I'll call it [`zefpan`](https://github.com/tony-o/cro-koos) for this post though it's not meant to be comparable to `cpan`.  Zefpan is essentially a webservice that provides a dependency chain for `YourModule:ver<>:api<>:auth<>`, this allows zef to bypass parsing the entirety of the ecosystem JSON to determine what's needed for installing/building a module and just make an http query to get the dependency chain.  It also allows us to do things like generate a "cool" dependency [graph](https://github.com/tony-o/p6-Uxmal).  Check this graph out for Cro:

![LDNJaxV](/i/LDNJaxV.png)

I'm keeping this short because I'm relatively sick but there will be more in the next couple of weeks discussing Warthog, the dependency graphing, and possibly `zefpan` as we hash things out.
