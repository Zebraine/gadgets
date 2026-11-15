#pragma once

#include <array>
#include <cstddef>
#include <memory>
#include <stdexcept>
#include <string>

/// A node of the trie.
///
/// The trie is restricted to the lowercase ASCII alphabet ('a'-'z'); every
/// other character throws std::invalid_argument on insertion.
struct TrieNode {
    static constexpr std::size_t kAlphabetSize = 26;

    std::array<std::unique_ptr<TrieNode>, kAlphabetSize> children{};
    bool isEndOfWord{false};
};

class Trie {
    std::unique_ptr<TrieNode> root{std::make_unique<TrieNode>()};

    static int indexOf(char c) {
        if (c < 'a' || c > 'z') {
            return -1;
        }
        return c - 'a';
    }

    static bool hasChildren(const TrieNode &node) {
        for (const auto &child : node.children) {
            if (child) {
                return true;
            }
        }
        return false;
    }

    static bool deleteFrom(TrieNode *node, const std::string &word,
                           std::size_t depth) {
        if (depth == word.size()) {
            if (!node->isEndOfWord) {
                return false;
            }
            node->isEndOfWord = false;
            return true;
        }

        const int index = indexOf(word[depth]);
        if (index < 0) {
            return false;
        }

        auto &child = node->children[static_cast<std::size_t>(index)];
        if (!child) {
            return false;
        }

        if (!deleteFrom(child.get(), word, depth + 1)) {
            return false;
        }

        // Prune nodes that no longer lead to any stored word.
        if (!child->isEndOfWord && !hasChildren(*child)) {
            child.reset();
        }

        return true;
    }

    const TrieNode *find(const std::string &prefix) const {
        const TrieNode *current = root.get();
        for (char c : prefix) {
            const int index = indexOf(c);
            if (index < 0) {
                return nullptr;
            }
            const auto &child =
                current->children[static_cast<std::size_t>(index)];
            if (!child) {
                return nullptr;
            }
            current = child.get();
        }
        return current;
    }

public:
    Trie() = default;

    Trie(const Trie &) = delete;
    Trie &operator=(const Trie &) = delete;
    Trie(Trie &&) noexcept = default;
    Trie &operator=(Trie &&) noexcept = default;

    void insert(const std::string &word) {
        // Validate before mutating so a rejected word leaves the trie intact.
        for (char c : word) {
            if (indexOf(c) < 0) {
                throw std::invalid_argument(
                    "Trie only supports lowercase ASCII letters ('a'-'z')");
            }
        }

        TrieNode *current = root.get();
        for (char c : word) {
            const auto index = static_cast<std::size_t>(indexOf(c));
            if (!current->children[index]) {
                current->children[index] = std::make_unique<TrieNode>();
            }
            current = current->children[index].get();
        }
        current->isEndOfWord = true;
    }

    bool search(const std::string &word) const {
        const TrieNode *node = find(word);
        return node != nullptr && node->isEndOfWord;
    }

    bool startsWith(const std::string &prefix) const {
        return find(prefix) != nullptr;
    }

    /// Deletes `word` and returns whether it was present.
    ///
    /// Named `deleteWord` because `delete` is a C++ keyword.
    bool deleteWord(const std::string &word) {
        return deleteFrom(root.get(), word, 0);
    }
};
