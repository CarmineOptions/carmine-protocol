## Tips for tweaking the tests

If you want to do mass adjustments to test syntax, regexes might help. I saved some of them in git commit history.

If you need to adjust values in multiple tests, add targets like testa, testb, testc, testd, for each of the 4 tests you're working on, open 4 terminals on a 4+ core machine and run every one in its own window. productivity 4x :stonks:

find: assert_uint256_eq\(([a-z_]+[0-9]+), Uint256\(low=([0-9]+), high=0\)\);
replace: assert $1.low = $2;