#include "radix_tree.cpp"
#include "trie.cpp"

#include <cassert>
#include <cstdio>
#include <stdexcept>
#include <string>

void test_radix_tree() {
    RadixTree tree;
    tree.insert("apple");
    tree.insert("app");
    tree.insert("apricot");
    tree.insert("banana");

    assert(tree.search("apple"));
    assert(tree.search("app"));
    assert(tree.search("apricot"));
    assert(tree.search("banana"));
    assert(!tree.search("appl"));
    assert(!tree.search("apples"));
    assert(!tree.search("ban"));
    assert(!tree.search(""));

    assert(tree.startsWith(""));
    assert(tree.startsWith("a"));
    assert(tree.startsWith("app"));
    assert(tree.startsWith("appl"));
    assert(tree.startsWith("apple"));
    assert(tree.startsWith("apri"));
    assert(tree.startsWith("ban"));
    assert(!tree.startsWith("apx"));
    assert(!tree.startsWith("apples"));
    assert(!tree.startsWith("c"));

    // Deleting a missing word must not change the tree.
    assert(!tree.deleteWord("appl"));
    assert(!tree.deleteWord("apples"));
    assert(!tree.deleteWord("cherry"));
    assert(!tree.deleteWord(""));

    assert(tree.deleteWord("app"));
    assert(!tree.search("app"));
    assert(tree.search("apple"));
    assert(tree.search("apricot"));
    assert(tree.startsWith("app"));
    assert(!tree.deleteWord("app"));

    assert(tree.deleteWord("apple"));
    assert(!tree.search("apple"));
    assert(!tree.startsWith("app"));
    assert(tree.search("apricot"));

    assert(tree.deleteWord("banana"));
    assert(!tree.startsWith("b"));

    assert(tree.deleteWord("apricot"));
    assert(!tree.startsWith("a"));
    assert(tree.startsWith(""));

    // Reinserting and splitting edges again should work.
    tree.insert("abc");
    tree.insert("abd");
    assert(tree.deleteWord("abd"));
    assert(tree.search("abc"));
    assert(!tree.search("abd"));

    tree.insert("abe");
    assert(tree.search("abc"));
    assert(tree.search("abe"));
    assert(!tree.search("abd"));

    // The empty string is a supported word.
    tree.insert("");
    assert(tree.search(""));
    assert(tree.startsWith(""));
    assert(tree.deleteWord(""));
    assert(!tree.search(""));

    assert(tree.deleteWord("abc"));
    assert(tree.search("abe"));
    assert(tree.deleteWord("abe"));
    assert(!tree.startsWith("a"));

    printf("Radix Tree tests passed!\n");
}

void test_trie() {
    Trie trie;
    trie.insert("apple");
    trie.insert("app");
    trie.insert("apricot");
    trie.insert("banana");

    assert(trie.search("apple"));
    assert(trie.search("app"));
    assert(trie.search("apricot"));
    assert(trie.search("banana"));
    assert(!trie.search("appl"));
    assert(!trie.search("apples"));
    assert(!trie.search("ban"));
    assert(!trie.search(""));

    assert(trie.startsWith(""));
    assert(trie.startsWith("a"));
    assert(trie.startsWith("app"));
    assert(trie.startsWith("appl"));
    assert(trie.startsWith("apple"));
    assert(trie.startsWith("apri"));
    assert(trie.startsWith("ban"));
    assert(!trie.startsWith("apx"));
    assert(!trie.startsWith("apples"));
    assert(!trie.startsWith("c"));

    assert(!trie.deleteWord("appl"));
    assert(!trie.deleteWord("apples"));
    assert(!trie.deleteWord("cherry"));
    assert(!trie.deleteWord(""));

    assert(trie.deleteWord("app"));
    assert(!trie.search("app"));
    assert(trie.search("apple"));
    assert(trie.search("apricot"));
    assert(trie.startsWith("app"));
    assert(!trie.deleteWord("app"));

    assert(trie.deleteWord("apple"));
    assert(!trie.search("apple"));
    assert(!trie.startsWith("app"));
    assert(trie.search("apricot"));

    assert(trie.deleteWord("banana"));
    assert(!trie.startsWith("b"));

    assert(trie.deleteWord("apricot"));
    assert(!trie.startsWith("a"));
    assert(trie.startsWith(""));

    // Reinserting after deletion should work.
    trie.insert("abc");
    trie.insert("abd");
    assert(trie.deleteWord("abd"));
    assert(trie.search("abc"));
    assert(!trie.search("abd"));

    trie.insert("abe");
    assert(trie.search("abc"));
    assert(trie.search("abe"));
    assert(!trie.search("abd"));

    // The empty string is a supported word.
    trie.insert("");
    assert(trie.search(""));
    assert(trie.startsWith(""));
    assert(trie.deleteWord(""));
    assert(!trie.search(""));

    assert(trie.deleteWord("abc"));
    assert(trie.search("abe"));
    assert(trie.deleteWord("abe"));
    assert(!trie.startsWith("a"));

    // Only lowercase ASCII is accepted on insertion, and validation happens
    // before the tree is modified.
    Trie restricted;
    restricted.insert("app");

    bool threw = false;
    try {
        restricted.insert("Apple");
    } catch (const std::invalid_argument &) {
        threw = true;
    }
    assert(threw);

    threw = false;
    try {
        restricted.insert("appLe");
    } catch (const std::invalid_argument &) {
        threw = true;
    }
    assert(threw);

    assert(restricted.search("app"));
    assert(!restricted.search("appLe"));
    assert(!restricted.search("Apple"));
    assert(!restricted.startsWith("A"));
    assert(!restricted.deleteWord("App"));

    printf("Trie tests passed!\n");
}

void test() {
    test_radix_tree();
    test_trie();
}
