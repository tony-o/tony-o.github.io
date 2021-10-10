zef ++ ecosystem
zef--ecosystem
programming, rakudo



TLDR; making the entire git ecosystem available to zef is in testing and should be available soon.  Module author tools are in early alpha phase and, if you'd like to contribute, please contact @tony-o on freenode.

The current state of the raku ecosystem is not great.  It can be better.

Currently, most of the modules are hosted on CPAN or in a git repo with a centralized list of those modules in yet another repo.  CPAN has shortcomings with raku because it was designed for perl and the module specs between the two languages, though related, are dissimilar.  The github solution is a bit of hack.  It works but it's tedious and requires a lot of trust to allow module authors just add things to the ecosystem via a repo that can affect so many others.

Enter: zeco.

For authors; module authors should be able to upload their modules without interfering with others' modules and they should be able to do it without remember what repo they need to go update or going to a website and uploading a tar file.  Let's make this easy.  With the zeco system there are two ways to publish your modules.  You can upload a tar file using a zef plugin (think: `zef publish` or similar, this is preferred) and the other method is to publish your module using a git repo link - this will not be mirrored by zeco (at least not immediately).

For general consumption; zeco provides endpoints for searching and downloading different modules which will help zef be efficient with your time.

Current status of zeco:

The server is up and currently makes several endpoints available to both authors and consumers of modules.  Transferring the git repo META list is in testing and, once testing is complete, will provide a full ecosystem list to zef with info on how to obtain the module.

There exists a zef plugin to register/upload modules.  If you're interested in helping or testing this tool so we can make it ready for production then please contact `tony-o` in any of the `#raku` channels.
