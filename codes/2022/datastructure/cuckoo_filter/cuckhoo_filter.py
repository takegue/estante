#!/usr/bin/env python

import random

def finger_print(obj):
    return hash(obj)

def hash_w_salt(obj, salt):
    return hash(hash(obj) + hash(salt))


class CuckooFilter:

    def __init__(self, n_hash=2, n_bucketsize=113):
        self.salt = 2000
        self.bucket = [None] * n_bucketsize
        self.max_num_kicks = 10


    def _check_empty(self, i, f):
        return self.bucket[i] is None

    def insert(self, obj):
        f = finger_print(obj)
        i1 = hash_w_salt(obj, self.salt) % len(self.bucket)
        i2 = i1 ^ hash_w_salt(f, self.salt) % len(self.bucket)

        if self._check_empty(i1, f):
            self.bucket[i1] = f
            return True
        elif self._check_empty(i2, f):
            self.bucket[i2] = f
            return True

        # TODO: random pickup
        i = i1
        for n in range(0, self.max_num_kicks):
            e = self.bucket[i]
            self.bucket[i] = f
            i = i ^ hash(f)
            if self._check_empty(i, f):
                self.bucket[i] = f
                return True

        return False

    def delete(self, obj):
        f = finger_print(obj)
        i1 = hash_w_salt(obj, self.salt) % len(self.bucket)
        i2 = i1 ^ hash_w_salt(f, self.salt) % len(self.bucket)

        if f == self.bucket[i1]:
            self.bucket[i1] = None
            return True
        elif f == self.bucket[i2]:
            self.bucket[i2] = None
            return True

        return False

    def lookup(self, obj):
        f = finger_print(obj)
        i1 = hash_w_salt(obj, self.salt) % len(self.bucket)
        i2 = i1 ^ hash_w_salt(f, self.salt) % len(self.bucket)

        return f == self.bucket[i1] or f == self.bucket[i2]


if __name__ == '__main__':
    inst = CuckooFilter(n_hash=2, n_bucketsize=100)
    for n in range(30):
        print(inst.insert(n))

    assert inst.lookup(3) == True
    assert inst.lookup(10) == True
    assert inst.lookup(11) == False

