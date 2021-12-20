Fez Orgs: A Winter Solstice Miracle
fez-orgs-a-winter-solstice-miracle
programming, rakudo

Fez now has orgs, it happened over the weekend. Let's take a look at how to get started with them:

## Creating an Org

Take it easy: `fez org create <org-name>`.  If a user or org with that name already exists then this will fail but the skies the limit here.  When you create the org you're automatically assigned the role of `admin`, more on this in the next section.

## Managing Your Org

Great, you're an admin. Now what? Do you have release managers or people you want to allow to upload modules on behalf of `org`?  Fez has two roles:

* Admin - can upload modules, can invite, and manage roles of other users
* Member - can upload modules

Assign your members accordingly:

### Inviting Users to Your Org

`fez org invite <org-name> <role> <username>`.  So if I were inviting `ugexe` to my `Zef` org then I'd run `fez org invite Zef admin ugexe` and he'd get an email letting him know about how awesome his life is about to be.

### Listing and Accepting Your Open Invites

```
$ fez org pending
>>= R Org
>>= a Zen
>>= m zef
```

I've been invited to `zef` as a `member` and to `Zen` as an `admin`.  I accept (and the command is the same for both):

```
$ fez org accept Zen
>>= You're now a very nice member of Zen
```

### Modify a User's Role

Ugexe has done a stellar job in `zef`, let's promote him to admin:

```
$ fez org mod zef admin ugexe
>>= User's role was modified
```

WHAT??? I just won the lotto! Now I want to leave my orgs because I don't have time :(

## Leaving an Org

```
$ fez org leave Zen
>>= You're no longer in Zen
```

This action will fail if you're the last remaining admin in the org.  Why? Leaving the org as the last admin will essentially abandon it so this is designed in a way that you must be very intentional in this action so you must first run `fez org mod <org> member <your username>` and then `leave`.

Now you can manage your entire group!

## Bonus Round

A couple of other actions you may or may not find useful:

### List Org Members

```
$ fez org members zef
>>= R Org Name
>>= a tony-o
>>= a ugexe
```

### List Orgs You Belong To

```
$ fez org list
>>= R Org Name
>>= a zef
```

## Finale

That's basically all and if you need a reminder then of course `fez org -h` will give you the command `USAGE`.  Have fun!
