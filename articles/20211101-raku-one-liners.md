Raku One Liners
raku-one-liners
rakudo

This page will get updated once in a while

### Array elements in another array

```raku
say [&&] ([||] $_ ∈ (1,2,3) for (1, 2));
```

