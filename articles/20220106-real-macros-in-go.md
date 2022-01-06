Real Macros in Go
real-macros-in-go
golang, programming

## So, you want real macros?

Tough luck. -go.

We don't need go for that. -this article

Let's get some *real* macros going in our build process! This is going to take us back to command line tools, the 90s, and a few things that those versed in the C preprocessor may remember.

First: let's make a problem for us to solve.  We're going to revisit functional programming's faves, `MAP, FILTER, and FOLDL`.  We'll pick off the two easy ones, map and filter.  We're going to use the C preprocessor so our macros will look like those of C, of course you're welcome to use M4 or any other more generic preprocessor, maybe you could write your own.

### Setup

The setup for this article is pretty straight forward, start a go project and then write a make file. We're going to start with this directory structure:

```
.
├── app.cgo
├── go.mod
├── macros
│   └── functions.h
└─── makefile
```

#### app.cgo

This file is going to be our unprocessed go code, in it will be all of our go. Let's start with the following:

```go
package main

import (
	"fmt"
	"math/rand"
)

type Demo struct {
	A int
}

func main() {
	as := []Demo{}
	for i := 0; i < 1000; i++ {
		as = append(as, demo.Demo{A: rand.Intn(100)})
	}
}
```

That's it! Normally we'd filter by using the good old fashioned `for i := range ...` loop so let's do that so we can make testing our macros a little nicer:

```go
  bs := []Demo{}
  for i := range as {
    if as[i].A < 50 {
      bs = append(bs, as[i])
    }
  }
  fmt.Printf("bs=%d demos\n", len(bs))
```

On the machine this article is written on we get `506` elements in `bs`. Your results may differ but they should be deterministic between runs (rand isn't truly random).

One more thing to do before we start making our lives more meaningful.

#### makefile

Here's where the magic really starts to glitterbomb:

```makefile
all:
	cat app.cgo | perl -np -e 's{^\t*//(\#.+)$$}{$$1}' | gcc -P -traditional -E - 2>/dev/null | cat -s | goimports 1>app.go
```

NOTE: if you're new to makefiles, the space prior to the command for the `all` directive must be a tab and not a series of spaces.

Whoa, what is all this???  The gist is that this will run our app.cgo file through the C preprocessor and put the processed file into `app.go`.

- `perl -np ...` this is going to allow us to run the `gofmt` or `goimports` command against or `cgo` file without complaining that `#include ""` is invalid go syntax (it is). This removes the go comment (`//`) and puts the macro at the start of the line to avoid any preprocessor problems.
- `gcc -P ...` this is running the C preprocessor
- `cat -s` is getting rid of long runs of multiple lines
- `goimports 1>app.go` is finally running goimports before writing to app.go

What is the result? Take a look:

```go
package main

import (
	"fmt"
	"math/rand"
)

type Demo struct {
	A int
}

func main() {
	as := []Demo{}
	for i := 0; i < 1000; i++ {
		as = append(as, Demo{A: rand.Intn(100)})
	}

	bs := []Demo{}
	for i := range as {
		if as[i].A < 50 {
			bs = append(bs, as[i])
		}
	}
	fmt.Printf("bs=%d demos\n", len(bs))
}
```
Kind of what we expected, just plain ol' go. Now we do some MAGIC!

### Macros!

If you notice, we have a folder called `macros` with a file `functions.h`.  Load this file into your editor and let's get to making it happen!

Let's write a FILTER macro, we're going to stick to C conventions and just make the macros entirely upper case:

```c
#define FILTER(arr, condition, type) \
func(arr []type) []type { \
	zs := []type{}; \
	for i := range arr {; \
		if condition { \
			zs = append(zs, arr[i]); \
		} \
	}; \
	return zs; \
}(arr)
```

Two things you'll notice:

1. a lot of semicolons. This is because C macros do not expand to a new line (you can use `\u000A` to get new lines, maybe).
1. we're using a function macro, you can exploit all of the other options but for this article we're sticking to this syntax

Now put the macro to good use:

```go
//#include "macros/functions.h"
func main() {
	as := []Demo{}
	for i := 0; i < 1000; i++ {
		as = append(as, Demo{A: rand.Intn(100)})
	}

	bs := []Demo{}
	for i := range as {
		if as[i].A < 50 {
			bs = append(bs, as[i])
		}
	}
	fmt.Printf("bs=%d demos\n", len(bs))

	cs := FILTER(as, as[i].A < 50, Demo)

	fmt.Printf("cs=%d demos\n", len(cs))
}
```

When you run `make` you should get `app.go` that looks very much like:

```go

func main() {
	as := []Demo{}
	for i := 0; i < 1000; i++ {
		as = append(as, Demo{A: rand.Intn(100)})
	}

	bs := []Demo{}
	for i := range as {
		if as[i].A < 50 {
			bs = append(bs, as[i])
		}
	}
	fmt.Printf("bs=%d demos\n", len(bs))

	cs := func(as []Demo) []Demo {
		zs := []Demo{}
		for i := range as {
			if as[i].A < 50 {
				zs = append(zs, as[i])
			}
		}
		return zs
	}(as)

	fmt.Printf("cs=%d demos\n", len(cs))
}
```

This, of course could be done without the closure but this protects us from mucking with other variables in scope. When you run this app, you should get:

```
bs=506 demos
cs=506 demos
```

Tré cool. But is it correct? It should be, the lengths are the same so iterate through and do your homework before doing anything too serious.

```go
	if len(cs) != len(bs) {
		panic("cs and bs differ")
	} 
	for i := range bs {
		if bs[i] != cs[i] {
			fmt.Printf("index %d differs, b=%d,c=%d\n", i, bs[i], cs[i])
			errors++
		}
	} 
```

This checks out, no errors found. Oh, we're good. Let's do map before our hand gets sore from patting ourselves on the back, in `macros/functions.h`:

```
#define MAP(arr, condition, member, type, returnType) \
func(arr []type) []returnType { \
	zs := []returnType{}; \
	for i := range arr {; \
		if condition { \
			zs = append(zs, member); \
		} \
	}; \
	return zs; \
}(arr)
```

Of note, you'll see more arguments. This is so that our generated code gets the types right. If we add to our app.go:

```go
js := MAP(as, as[i].A < 50, as[i].A, Demo, int)

fmt.Println("js=%d ints\n", len(js))
```

Running make will give you the additional:

```go
	js := func(as []Demo) []int {
		zs := []int{}
		for i := range as {
			if as[i].A < 50 {
				zs = append(zs, as[i].A)
			}
		}
		return zs
	}(as)

	fmt.Printf("js=%d ints\n", len(js))
```

If you check your output again you should see something similar:

```
bs=506 demos
cs=506 demos
js=506 ints
```

You can check each `j` and compare it to `b.A` to verify your results. We're definitely in Willy Wonka's office now, let's seal the deal and be the new chocolate maker with `FOLDL`:

```c
#define FOLDL(test, init, arr, type, returnType) \
func(fn func(a returnType, b type) returnType, acc returnType, arr []type) returnType { \
	res := acc; \
	for i := range arr { \
		res = fn(res, arr[len(arr) - 1 - i]); \
	}; \
	return res; \
}(test, init, arr)
```

And we can call this macro with:

```go
	ks := FOLDL(func(a int, b Demo) int { return a + b.A }, 0, as, Demo, int)

	fmt.Printf("ks %d\n", ks)
```

If you're familiar with FOLDL then you can see we're just summing the list and you can skip the rest of this paragraph.  We've written a C macro that takes a function with argument types `type, returnType` and in our macro call we've provided `func (a int, b Demo) int`. You'll notice that the first argument and the return type are `returnType` and this is necessary for `foldl`, you could design a similar macro that does something else if needed but we're sticking to haskell's `foldl` signature. Next up is the initial value (called the accumulator) and then the slice we want to fold upon.  The func in argument one is what actually reduces the slice.

To test this, we need to sum `as` and we can spot check our assumptions with:

```go
	sum := 0
	for _, a := range as {
		sum += a.A
	}
	fmt.Printf("sum(as)=%d,ks=%d\n", sum, ks)
```

And...

```
...
sum(as)=48533,ks=48533
...
```

It works!

### Other Considerations

#### Makefile Directives

Our makefile is _very_ basic. There's tons of tutorials out there on how to iterate all `*.cgo` files in a repo in your makefile so you don't have to list each cgo file in your makefile and have the headache of keeping that up to date.  Whilst writing this article it was helpful to have these two rules allowing `make run` and `make debug` to build and run the app and to just see the preprocessor output respectively:

```makefile
debug:
	cat app.cgo | perl -np -e 's{^\t*//(\#.+)$$}{$$1}' | gcc -P -CC -traditional -E - 2>/dev/null | cat -s | tee /dev/tty | goimports

run: all
	if [[ -f app.go ]]; then go run app.go; rm app.go; else echo "app.go failed to generate"; fi
```

Again, note if you're new to makefiles, the space prior to the command for that directive must be a tab and not a series of spaces.

#### Error Handling

This could be used all over the place for the tedious `if err != nil { ... }` and just checked with an `ERROR(err)` macro.

#### Code Generation

This is a lot cleaner than using the code generation for these types and it's a lot more readily fixable if a bug is discovered or if something slightly different is needed. A lot less boilerplate.

That's it for today - have fun!
