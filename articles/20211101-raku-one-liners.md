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
my @files = -> IO() $a { my &s = &?BLOCK; |($_.d ?? |($_,s($_)) !! $_ for $a.dir) }('/tmp');
```

#### Just files

```raku
my @files = -> IO() $a { my &s = &?BLOCK; |($_.d ?? |s($_) !! $_ for $a.dir) }('/tmp');
```

