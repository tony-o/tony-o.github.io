Six Minute AB Testing
six-minute-ab-testing
programming, golang

So, you want to roll features out slowly or maybe you just want to dip your toes in the water to try out that shiny new button.  Great! AB testing has multitudes of methodologies, articles, and optometrists working on the problem.  Let's roll our own and then explore the edge cases, problems, and considerations involved with AB testing.

## AB Testing

There's all kinds of ways to do AB testing, some using DB functions, others using hashing methods, and some are as simple as just `mod`ing an id. Each have their benefits and draw backs but we'll aim for speed and even distribution even with small sample sizes.  Even distribution with a small sample size is doable but complex with just a plain old `mod` so we'll use hashing for the initial setup.

Initial considerations:

1. Determinism. A user should *always* be shown the same bucket they initially saw
2. Even bucket distribution
3. Bucketing should never use or require more than one query
4. Tests can contain more than two buckets and each bucket can be weighted
5. Tests can be updated and buckets may disappear, handle gracefully

Point one is fairly self explanatory. It'd be a pretty poor customer experience if every time you visited your favorite search engine (probably alta vista) the search bar was moved around.

To discuss `mod` a little further, the basic idea is that you take the remainder of the id divided by how many buckets the test contains, with consideration their weights, and then choose the bucket corresponding with the remainder.  You can do funny stuff to make this distribute more evenly distributed without hashing but this isn't a math lesson, we're talking about AB testing and we just wanna hash, man.

If the bucketing only matters over the lifetime of the app then no queries should ever be necessary. If you have a distributed system or many things bucketing entities then you may end up storing bucket details in a database of some sort and memoizing locally.

Let's define some types:

```go
// This is a bare AB Test
type Test struct {
  Buckets     []string
  Weights     []int
  totalWeight uint32
}

// This is our directory of AB Tests
type ABTests map[string][]Test
```

First thing to notice, type `Test` contains no stateful information.  It doesn't keep track of ids bucketed or what type of overall AB test it belongs to.

We're off to a blazing start and have satisfied no criterion we've designated for success.

Let's add the bucketing receiver so we can add `Test`s to `ABTests`:

```go
func (a ABTest) AddTest(testName string, t Test) bool {
	if _, ok := a[testName]; !ok {
		a[testName] = []Test{}
	}
	for idx := range t.Weights {
		t.totalWeight += uint32(t.Weights[idx])
	}
	a[testName] = append(a[testName], t)
	return true
}
```
One thing to note here is that `AddTest` is calculating the `totalWeight` for the test here rather than during bucketing so we don't have to recalculate each time we want to know something about the test.

Cool, now we can do something like this in `main.go`:

```go
func main() {
	tests := ABTest{}
	tests.AddTest("test1", Test{
		Buckets: []string{"control", "a", "b"},
		Weights: []int{2, 1, 1}, // 50% 25% 25%
	})

  //...
}
```

Aaaand, we still have none of the success criteria being met. Let's at least do some bucketing so we can make progress towards our goals.

```go
func (t Test) getBucket(initialWeight int64) (string, bool) {
	for idx, ui := range t.Weights {
		initialWeight -= int64(ui)
		if initialWeight < 0 {
			return t.Buckets[idx], idx == 0
		}
	}
	return t.Buckets[0], true
}

func (a ABTest) GetBucket(testName, id string) (string, error) {
	var t Test
	if ts, ok := a[testName]; !ok || len(ts) == 0 {
		return "", errors.New(fmt.Sprintf("cannot find test name %s", testName))
	} else {
		t = ts[len(ts)-1]
	}

  key := id + ":" + testName
	bucket, _ := t.getBucket(int64(hash(key) % t.totalWeight))
	return bucket, nil
}
```

The keen observer will notice that this could be just one function.  It could be but having it as two methods allows us to do other little tricks later on and makes it a little clearer whose responsibility it is for what part of the action.

Our `GetBucket` function takes a test name and entity id, looks for a test by that name, verifies it has more than zero tests to its name, hashes the id with the test name, retrieves the bucket from the test and returns this.

You might also notice that we are still using `mod` (or `%` in go).  Hashing is just one method of randomizing the order of the buckets distribution. Don't believe it? Agreed, sounds a little too mathy to let that sleeping dog lie.

Let's test it, in `main.go` add:

```go
const ACCEPTABLE_THRESHOLD = .01 // 1%
const POOL_SIZE            = 100000
```

and in `main.go:main()` add:

```go
func (t Test) SampleSize(bucket string, pool uint64) (float64, error) {
	for idx, bs := range t.Buckets {
		if bs == bucket {
			return float64(pool) * (float64(t.Weights[idx]) / float64(t.totalWeight)), nil
		}
	}
	return 0, errors.New(fmt.Sprintf("bucket %s not found", bucket))
}

func main() {
  // ...

	// test bucketing distribution
	buckets := map[string]uint32{}
	for i := 0; i < POOL_SIZE; i++ {
		b, err := tests.GetBucket("test1", fmt.Sprintf("%d", i))
		if err != nil {
			fmt.Printf("err=%v\n", err)
		}
		buckets[b]++
	}
	for _, bkt := range tests["test1"][0].Buckets {
		ss, err := tests["test1"][0].SampleSize(bkt, POOL_SIZE)
		if err != nil {
			fmt.Printf("err=%v\n")
			return
		}
		min := math.Floor(ss * (1 - ACCEPTABLE_THRESHOLD))
		max := math.Ceil(ss * (1 + ACCEPTABLE_THRESHOLD))
		if a, ok := buckets[bkt]; !ok || float64(a) > max || float64(a) < min {
			fmt.Printf("bucket %s is not within the right range, expected=%0.3f<=x<=%0.3f,got=%0.3f\n", bkt, min, max, float64(a))
		} else {
			fmt.Printf("bucket %s is within the right range, expected=%0.3f<=x<=%0.3f,got=%0.3f\n", bkt, min, max, float64(a))
		}
	}

```

Now, upon running this hog, we should get some cool messages from golang letting us know our distribution is within the city limits.

```
bucket control is within the right range, expected=49500<=x<=50500,got=50000
bucket a is within the right range, expected=24750<=x<=25250,got=25001
bucket b is within the right range, expected=24750<=x<=25250,got=24999
```

Woohoo, point two is done and dusted.  Great distribution.  If you play around and make the pool size only 10, we should still be OK.

```
bucket control is within the right range, expected=4<=x<=6,got=5
bucket a is within the right range, expected=2<=x<=3,got=3
bucket b is within the right range, expected=2<=x<=3,got=2
```

What if it's really biased bucketing? Oh I don't know, 3 tests?

```
bucket control is within the right range, expected=1<=x<=2,got=2
bucket a is within the right range, expected=0<=x<=1,got=1
bucket b is within the right range, expected=0<=x<=1,got=0
```

Bingo! Okay, for the rest of this article we're going to use the OG pool size of `100000` and we'll consider our even distribution problem solved.

Now to test point one, remember point one? Determinism. Let's get after it:

```go
	testBucket, _ := tests.GetBucket("test1", "hello, world!")
	misses := 0
	for i := 0; i < POOL_SIZE; i++ {
		if tb, _ := tests.GetBucket("test1", "hello, world!"); tb != testBucket {
			misses++
		}
	}
	if misses > 0 {
		fmt.Printf("Determinism misses: %d\n", misses)
  }
```

No messages about misses, great.  That half solves point one.  If you later add another `Test` to that test name with a different distribution then you're really asking for trouble.  Users that saw you were giving away $1m to anyone who saw the message and were on the fence about it may no longer see that message and then you'll have some very unhappy users (but only some of them).

Let's add on some memoization, more on this after the next heading. For this article we're going to pretend that the determinism is only required for the duration of this process.  You might consider a database for a more highly distributed system and this is the only acceptable query our process should perform to maintain integrity.  Here we're only going to use a local variable:

In your ABTest package add/alter:

```go
var memoization = map[string]map[string]string{}  //<=====

func (a ABTest) GetBucket(testName, id string) (string, error) {
	var t Test
	if ts, ok := a[testName]; !ok || len(ts) == 0 {
		return "", errors.New(fmt.Sprintf("cannot find test name %s", testName))
	} else {
		t = ts[len(ts)-1]
		if memoize[testName] == nil {                 //<=====
			memoize[testName] = map[string]string{}     //<=====
		}                                             //<=====
	}
	key := id + ":" + testName
	if bkt, ok := memoize[testName][key]; ok {      //<=====
		return bkt, nil                               //<=====
	}                                               //<=====

	bucket, _ := t.getBucket(int64(hash(key) % t.totalWeight))
	memoize[testName][key] = bucket
	return bucket, nil
}
```

Testing our assumptions again we'd expect nothing to have changed and nothing does.  All clear.

## Updating Tests

If you want to be able to update tests then storing bucketed user's bucket is probably fine enough. If you're pure of heart and declare tests with different buckets or distributions to be similar but not the same then the `ABTests` object could be simplified above. For this article we make no such proclamations and no guarantees. We want to show a user the same bucket they saw before so long as that bucket still exists.

Next step is to add another `Test` to our `"test1"` bucket and make sure we get original distributions with already bucketed ids and new distributions with new ids:

```go
func main() {
	//...

	// test regressions
	tests.AddTest("test1", Test{
		Buckets: []string{"control", "a", "b"},
		Weights: []int{1, 1, 98}, // 1% 1% 98%
	})

	buckets = map[string]uint32{}
	for i := 0; i < POOL_SIZE; i++ {
		b, err := tests.GetBucket("test1", fmt.Sprintf("%d", i))
		if err != nil {
			fmt.Printf("err=%v\n", err)
		}
		buckets[b]++
	}

	// all of these ids were wentered into a 50/25/25 test
	for _, bkt := range tests["test1"][0].Buckets {
		ss, err := tests["test1"][0].SampleSize(bkt, POOL_SIZE)
		if err != nil {
			fmt.Printf("err=%v\n")
			return
		}
		min := math.Floor(ss * (1 - ACCEPTABLE_THRESHOLD))
		max := math.Ceil(ss * (1 + ACCEPTABLE_THRESHOLD))
		if a, ok := buckets[bkt]; !ok || float64(a) > max || float64(a) < min {
			fmt.Printf("bucket %s is not within the right range, expected=%d<=x<=%d,got=%d\n", bkt, uint(min), uint(max), a)
		} else {
			fmt.Printf("bucket %s is within the right range, expected=%d<=x<=%d,got=%d\n", bkt, uint(min), uint(max), a)
		}
	}
	/*
```

Three more positive affirmations for our day:

```
bucket control is within the right range, expected=49500<=x<=50500,got=50000
bucket a is within the right range, expected=24750<=x<=25250,got=25001
bucket b is within the right range, expected=24750<=x<=25250,got=24999
```

Now let's make sure that new users are bucketed in our zany `control:1 / a:1 / b:98` bucketing scheme.

```go
func main() {
	//...

	buckets = map[string]uint32{}
	for i := POOL_SIZE * 2; i < POOL_SIZE*3; i++ {
		b, err := tests.GetBucket("test1", fmt.Sprintf("%d", i))
		if err != nil {
			fmt.Printf("err=%v\n", err)
		}
		buckets[b]++
	}

	// none of these ids were wentered into a 50/25/25 test
	// and should conform to the updated test buckets 1/1/98
	for _, bkt := range tests["test1"][1].Buckets {
		ss, err := tests["test1"][1].SampleSize(bkt, POOL_SIZE)
		if err != nil {
			fmt.Printf("err=%v\n")
			continue
		}
		min := math.Floor(ss * (1 - ACCEPTABLE_THRESHOLD))
		max := math.Ceil(ss * (1 + ACCEPTABLE_THRESHOLD))
		if a, ok := buckets[bkt]; !ok || float64(a) > max || float64(a) < min {
			fmt.Printf("bucket %s is not within the right range, expected=%d<=x<=%d,got=%d\n", bkt, uint(min), uint(max), a)
		} else {
			fmt.Printf("bucket %s is within the right range, expected=%d<=x<=%d,got=%d\n", bkt, uint(min), uint(max), a)
		}
	}
}
```
UH OH:

```
bucket control is within the right range, expected=990<=x<=1010,got=1009
bucket a is not within the right range, expected=990<=x<=1010,got=1042
bucket b is within the right range, expected=97020<=x<=98980,got=97949
```

What's our major malfunction?  Looks like we didn't test our distribution enough.  Let's try some stuff. We tried `fnv`, let's give `adler32` a shot.  Modifying our `func hash(string)`:

```go
func hash(s string) uint32 {
	h := adler32.New()
	h.Write([]byte(s))
	return h.Sum32()
}
```

Aaaand, short test again:

```
bucket control is within the right range, expected=4950<=x<=5050,got=5034
bucket a is within the right range, expected=4950<=x<=5050,got=4975
bucket b is within the right range, expected=89100<=x<=90900,got=89991
```

WHEW! Back in business.

Okay, let's recap what our goals were and what we've done:

1. ✓ Determinism. A user should *always* be shown the same bucket they initially saw
2. ✓ Even bucket distribution
3. ✓ Bucketing should never use or require more than one query
4. ✓ Tests can contain more than two buckets and each bucket can be weighted
5. 𐄂 Tests can be updated and buckets may disappear, handle gracefully

## How to Handle Failing Buckets

Your users don't want green text on the yellow background, apparently.  Let's see what happens when we update that test to remove bucket `a`.

```go
func main() {
	//...

	tests.AddTest("test1", Test{
		Buckets: []string{"control", "b"},   //<== Notice that bucket 'a' is missing
		Weights: []int{5, 95}, // 5% 90%
	})

	buckets = map[string]uint32{}
	for i := 0; i < POOL_SIZE; i++ {
		b, err := tests.GetBucket("test1", fmt.Sprintf("%d", i))
		if err != nil {
			fmt.Printf("err=%v\n", err)
		}
		buckets[b]++
	}

}
```

Another undesirable outcome. We're really disappointing our parents today. `buckets` contains the original distribution of `control:50% / a:25% / b:25%` and we've ripped feature `a` out of the product entirely. Here we have some decisions to make, we could make feature `a` users now see `control`, they could be rebucketed into the largest bucket, or they could just be reseeded using the latest `Test`.  Grab your toolbox and let's reseed the users:

```go
func (a ABTest) GetBucket(testName, id string) (string, error) {
	var t Test
	if ts, ok := a[testName]; !ok || len(ts) == 0 {
		return "", errors.New(fmt.Sprintf("cannot find test name %s", testName))
	} else {
		t = ts[len(ts)-1]
		if memoize[testName] == nil {
			memoize[testName] = map[string]string{}
		}
	}
	key := id + ":" + testName
	if bkt, ok := memoize[testName][key]; ok {
		for _, tx := range t.Buckets {              //<== make sure the bucket exists
			if tx == bkt {
				return bkt, nil
			}
	}

	bucket, _ := t.getBucket(int64(hash(key) % t.totalWeight))
	memoize[testName][key] = bucket
	return bucket, nil
}
```

Now when we rerun our tests we end up with a nicer distribution of closer to 50/50 (it's somewhere closer to 51.25/48.75) which is what we'd expect given that we re-bucketed 25% of the users to `b` 95% of the time and the `control` 50% can only grow given our constraint that users should have the same experience each time.  The math for bucket `b` is `0.25 (original b) + (.25 (original a) * .95 (b's current distribution))`

This gives us goal five, great work everyone!

## Bonus: Testing

Note that about half way through this exercise we had to modify our hashing function.  FNV wasn't performing poorly but it wasn't meeting our distribution constraint. One of the more fun aspects of being a programmer is that you can theorize about things then you can benchmark them, and then you get to argue about your findings with people who want nothing more than to gain your power or prove you wrong. Let's write a better test for something real world.

In the real world, our users aren't sequential numbers and sometimes they're not numbers at all. Users don't also sequentially visit features on your site.  Let's find the best distributed algorithm for UUIDs among different sample sizes:

```go
func adlerHash(s string) uint64 {
	h := adler32.New()
	h.Write([]byte(s))
	return uint64(h.Sum32())
}

func crc32HashIEEE(s string) uint64 {
	h := crc32.New(crc32.MakeTable(crc32.IEEE))
	h.Write([]byte(s))
	return uint64(h.Sum32())
}

func crc32HashCastagnoli(s string) uint64 {
	h := crc32.New(crc32.MakeTable(crc32.Castagnoli))
	h.Write([]byte(s))
	return uint64(h.Sum32())
}

func crc32HashKoopman(s string) uint64 {
	h := crc32.New(crc32.MakeTable(crc32.Koopman))
	h.Write([]byte(s))
	return uint64(h.Sum32())
}

func crc64HashECMA(s string) uint64 {
	h := crc64.New(crc64.MakeTable(crc64.ECMA))
	h.Write([]byte(s))
	return h.Sum64()
}

func crc64HashISO(s string) uint64 {
	h := crc64.New(crc64.MakeTable(crc64.ISO))
	h.Write([]byte(s))
	return h.Sum64()
}

func fnvHash32(s string) uint64 {
	h := fnv.New32()
	h.Write([]byte(s))
	return uint64(h.Sum32())
}

func fnvHash64(s string) uint64 {
	h := fnv.New64()
	h.Write([]byte(s))
	return h.Sum64()
}

func main() {
	sampleSizes := []int{30, 100, 100000}
	buckets := []Test{
		{
			Buckets:     []string{"a", "b"},
			Weights:     []int{1, 1},
			totalWeight: 2,
		},
		{
			Buckets:     []string{"a", "b", "c", "d"},
			Weights:     []int{1, 1, 1, 1},
			totalWeight: 4,
		},
		{
			Buckets:     []string{"a", "b", "c", "d", "e", "f", "g", "h"},
			Weights:     []int{1, 1, 1, 1, 1, 1, 1, 1},
			totalWeight: 8,
		},
		{
			Buckets:     []string{"a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m", "n", "o", "p"},
			Weights:     []int{1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1},
			totalWeight: 16,
		},
	}
	ids := []string{}
	hashes := map[string](func(string) uint64){
		"adler":            adlerHash,
		"crc32 IEEE":       crc32HashIEEE,
		"crc32 Castagnoli": crc32HashCastagnoli,
		"crc32 Koopman":    crc32HashKoopman,
		"crc64 ECMA":       crc64HashECMA,
		"crc64 ISO":        crc64HashISO,
		"fnv32":            fnvHash32,
		"fnv64":            fnvHash64,
	}
	order := []string{"adler", "crc32 IEEE", "crc32 Castagnoli", "crc32 Koopman", "crc64 ECMA", "crc64 ISO", "fnv32", "fnv64"}

	for i := 0; i < 100000; i++ {
		ids = append(ids, uuid.New().String())
	}

	/* Run our tests, this could take a while depending on your parameters */
	for _, sample := range sampleSizes {
		fmt.Printf("sample size %d:\n", sample)

		for _, t := range buckets {
			fmt.Printf("  #%d buckets (%0.2f%% dist)\n", t.totalWeight, 100/float64(t.totalWeight))

			dist := map[string]map[string]uint64{}
			for _, n := range order {
				fn := hashes[n]
				dist[n] = map[string]uint64{}
				for idx := 0; idx < sample; idx++ { // only use the first X of sample
					b, _ := t.getBucket(int64(fn(ids[idx]) % uint64(t.totalWeight)))
					dist[n][b]++
				}
			}

			for _, h := range order {
				fmt.Printf("    %-16s: ", h)
				for _, tx := range dist[h] {
					fmt.Printf("%02.2f%% ", float64(tx)*100.0/float64(sample))
				}
				fmt.Printf("\n")
			}
		}
	}
}
```

This will give you a nice little table showing different distribution characteristics given different sample and bucket sizes for each hashing method listed. A fun thing to do before you head out to return your library books is to implement your own bucketing method, try to get a better distribution with low sample sizes!
