
from __future__ import print_function

def getPrefix(lo, hi, int_size=32):
    if lo > hi:
        return []
    if lo == hi:
        return [(lo, int_size)]
    prefixes = getPrefix((lo + 1) >> 1, (hi - 1) >> 1, int_size - 1)
    prefixes = [(v << 1, l) for v, l in prefixes]
    if lo & 1 == 1:
        prefixes.append((lo, int_size))
    if hi & 1 == 0:
        prefixes.append((hi, int_size))
    return prefixes

if __name__ == '__main__':
    print(getPrefix(8, 16, 16))
    print(getPrefix(8, 15, 16))
    print(getPrefix(8, 14, 16))
    print(getPrefix(9, 16, 16))
    print(getPrefix(9, 15, 16))
    print()
    print(getPrefix(5, 6, 16))
    print(getPrefix(9, 14, 16))
