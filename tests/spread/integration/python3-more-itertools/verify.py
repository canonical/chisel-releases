from more_itertools import chunked, distinct_permutations, first, windowed

assert list(chunked(range(5), 2)) == [[0, 1], [2, 3], [4]]
assert list(windowed("abcd", 3)) == [("a", "b", "c"), ("b", "c", "d")]
assert sorted(distinct_permutations("aab")) == [("a", "a", "b"), ("a", "b", "a"), ("b", "a", "a")]
assert first([], default=None) is None
