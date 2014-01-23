# CBJSON
or
## "Parse JSON 5x Faster With This One Weird Trick!"

Jens Alfke (jens@couchbase.com)

This is an Objective-C library for Mac OS X and iOS. It provides an alternate API for working with JSON, including a new format I call "Indexed JSON" that's a lot faster to work with -- in small benchmarks, it's about 5x as fast as NSJSONSerialization for parsing a document and extracting one key.

Indexed JSON works by prepending a small binary index before the start of the JSON data. The index points to the byte position where each top-level key begins. It also contains a hash code for each key. This makes it very fast to look up a key; after that, the associated value can be parsed out of the JSON.

By deferring parsing to the time that a value is needed, Indexed JSON can be a lot faster for the common case where a JSON object is parsed just to look up one or two top-level values, for instance when indexing a map-reduce view.

## How To Do It

No real documentation yet — read the doc-comments in the class headers, and look at the unit tests.