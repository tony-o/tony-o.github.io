Raku One Liners
raku-one-liners
rakudo

This page will get updated once in a while

### Array elements in another array

```raku
say [&&] ([||] $_ ∈ (1,2,3) for (1, 2));
```

### All files/folders in directory

```raku
sub ls (IO() $d) {
  |($_.d ?? |ls($_) !! $_ for $a.dir)       # only files
  |($_.d ?? |($_, ls($_)) !! $_ for $a.dir) # with dirs and dirnames
}
```
