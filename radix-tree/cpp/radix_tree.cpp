#pragma once

#include <algorithm>
#include <cstddef>
#include <memory>
#include <string>
#include <string_view>
#include <unordered_map>

struct RadixTreeNode {
    std::unordered_map<std::string, std::unique_ptr<RadixTreeNode>> children;
    bool isEndOfWord{false};
};

namespace radix_detail {

inline std::size_t commonPrefixLength(std::string_view a, std::string_view b) {
    const std::size_t limit = std::min(a.size(), b.size());
    std::size_t length = 0;
    while (length < limit && a[length] == b[length]) {
        ++length;
    }
    return length;
}

} // namespace radix_detail

/// A compressed trie (radix tree).
///
/// Each edge stores a non-empty label. Sibling edges start with distinct
/// characters, so at most one child can match a given prefix. Deletion
/// removes dead edges and merges nodes that are left with a single child.
class RadixTree {
    std::unique_ptr<RadixTreeNode> root{std::make_unique<RadixTreeNode>()};

    template <typename Children>
    static auto findChild(Children &children, char firstChar) {
        return std::find_if(
            children.begin(), children.end(), [firstChar](const auto &entry) {
                return !entry.first.empty() && entry.first.front() == firstChar;
            });
    }

    static bool deleteFrom(RadixTreeNode *node, const std::string &word,
                           std::size_t offset) {
        if (offset == word.size()) {
            if (!node->isEndOfWord) {
                return false;
            }
            node->isEndOfWord = false;
            return true;
        }

        auto entry = findChild(node->children, word[offset]);
        if (entry == node->children.end()) {
            return false;
        }

        const std::string key = entry->first;
        if (word.size() - offset < key.size() ||
            word.compare(offset, key.size(), key) != 0) {
            return false;
        }

        RadixTreeNode *child = entry->second.get();
        if (!deleteFrom(child, word, offset + key.size())) {
            return false;
        }

        // The child no longer represents a word and has no descendants.
        if (child->children.empty() && !child->isEndOfWord) {
            node->children.erase(key);
            return true;
        }

        // A node that is not a word and has exactly one child is redundant:
        // merge its edge label with the child's edge label.
        if (!child->isEndOfWord && child->children.size() == 1) {
            auto grandEntry = child->children.begin();
            std::string grandKey = grandEntry->first;
            auto grandchild = std::move(grandEntry->second);
            child->children.erase(grandEntry);

            child->isEndOfWord = grandchild->isEndOfWord;
            child->children = std::move(grandchild->children);

            auto childOwner = std::move(entry->second);
            node->children.erase(entry);
            node->children.emplace(key + grandKey, std::move(childOwner));
        }

        return true;
    }

public:
    RadixTree() = default;

    RadixTree(const RadixTree &) = delete;
    RadixTree &operator=(const RadixTree &) = delete;
    RadixTree(RadixTree &&) noexcept = default;
    RadixTree &operator=(RadixTree &&) noexcept = default;

    void insert(const std::string &word) {
        RadixTreeNode *current = root.get();
        std::size_t offset = 0;

        while (true) {
            if (offset == word.size()) {
                current->isEndOfWord = true;
                return;
            }

            const std::string_view remaining(word.data() + offset,
                                             word.size() - offset);
            auto entry = findChild(current->children, remaining.front());
            if (entry == current->children.end()) {
                auto node = std::make_unique<RadixTreeNode>();
                node->isEndOfWord = true;
                current->children.emplace(std::string(remaining),
                                          std::move(node));
                return;
            }

            const std::string key = entry->first;
            const std::size_t common =
                radix_detail::commonPrefixLength(key, remaining);

            if (common == key.size()) {
                offset += key.size();
                current = entry->second.get();
                continue;
            }

            // Split the edge at the longest common prefix.
            auto child = std::move(entry->second);
            current->children.erase(entry);

            auto intermediate = std::make_unique<RadixTreeNode>();
            intermediate->children.emplace(key.substr(common),
                                           std::move(child));
            auto inserted =
                current->children
                    .emplace(key.substr(0, common), std::move(intermediate))
                    .first;

            offset += common;
            current = inserted->second.get();
        }
    }

    bool search(const std::string &word) const {
        const RadixTreeNode *current = root.get();
        std::size_t offset = 0;

        while (offset < word.size()) {
            auto entry = findChild(current->children, word[offset]);
            if (entry == current->children.end()) {
                return false;
            }

            const std::string &key = entry->first;
            if (word.size() - offset < key.size() ||
                word.compare(offset, key.size(), key) != 0) {
                return false;
            }

            offset += key.size();
            current = entry->second.get();
        }
        return current->isEndOfWord;
    }

    bool startsWith(const std::string &prefix) const {
        const RadixTreeNode *current = root.get();
        std::size_t offset = 0;

        while (offset < prefix.size()) {
            auto entry = findChild(current->children, prefix[offset]);
            if (entry == current->children.end()) {
                return false;
            }

            const std::string &key = entry->first;
            const std::size_t remaining = prefix.size() - offset;
            if (remaining < key.size()) {
                // The prefix ends in the middle of this edge.
                return prefix.compare(offset, remaining, key, 0, remaining) ==
                       0;
            }
            if (prefix.compare(offset, key.size(), key) != 0) {
                return false;
            }

            offset += key.size();
            current = entry->second.get();
        }
        return true;
    }

    /// Deletes `word` and returns whether it was present.
    ///
    /// Named `deleteWord` because `delete` is a C++ keyword.
    bool deleteWord(const std::string &word) {
        return deleteFrom(root.get(), word, 0);
    }
};
