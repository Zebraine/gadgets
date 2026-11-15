//! A character trie (prefix tree).
//!
//! Nodes branch on `char`, so the trie works with arbitrary Unicode text.

use std::collections::HashMap;

#[derive(Debug, Default)]
pub struct TrieNode {
    pub children: HashMap<char, Box<TrieNode>>,
    pub is_end_of_word: bool,
}

#[derive(Debug, Default)]
pub struct Trie {
    root: TrieNode,
}

impl Trie {
    pub fn new() -> Self {
        Self::default()
    }

    /// Inserts `word` into the trie. Inserting an existing word is a no-op.
    pub fn insert(&mut self, word: &str) {
        let mut current = &mut self.root;
        for ch in word.chars() {
            current = current.children.entry(ch).or_default();
        }
        current.is_end_of_word = true;
    }

    /// Returns `true` if `word` was previously inserted.
    pub fn search(&self, word: &str) -> bool {
        self.find_node(word).is_some_and(|node| node.is_end_of_word)
    }

    /// Returns `true` if at least one inserted word starts with `prefix`.
    pub fn starts_with(&self, prefix: &str) -> bool {
        self.find_node(prefix).is_some()
    }

    /// Removes `word` from the trie.
    ///
    /// Returns `true` if the word was present. Nodes that become unreachable
    /// are pruned as the recursion unwinds.
    pub fn delete(&mut self, word: &str) -> bool {
        let chars: Vec<char> = word.chars().collect();
        Self::delete_from(&mut self.root, &chars)
    }

    fn find_node(&self, prefix: &str) -> Option<&TrieNode> {
        let mut current = &self.root;
        for ch in prefix.chars() {
            current = current.children.get(&ch)?;
        }
        Some(current)
    }

    fn delete_from(node: &mut TrieNode, chars: &[char]) -> bool {
        let Some((&ch, rest)) = chars.split_first() else {
            if !node.is_end_of_word {
                return false;
            }
            node.is_end_of_word = false;
            return true;
        };

        let Some(child) = node.children.get_mut(&ch) else {
            return false;
        };

        if !Self::delete_from(child, rest) {
            return false;
        }

        if child.children.is_empty() && !child.is_end_of_word {
            node.children.remove(&ch);
        }

        true
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn sample_trie() -> Trie {
        let mut trie = Trie::new();
        for word in ["apple", "app", "apricot", "banana"] {
            trie.insert(word);
        }
        trie
    }

    #[test]
    fn inserts_and_searches_words() {
        let trie = sample_trie();

        for word in ["apple", "app", "apricot", "banana"] {
            assert!(trie.search(word), "{word:?} should be present");
        }
        for word in ["appl", "apples", "apricots", "ban", "bananas", "cherry"] {
            assert!(!trie.search(word), "{word:?} should be absent");
        }
    }

    #[test]
    fn queries_prefixes() {
        let trie = sample_trie();

        for prefix in ["", "a", "app", "appl", "apple", "apricot", "b", "ban"] {
            assert!(trie.starts_with(prefix), "{prefix:?} should be a prefix");
        }
        for prefix in ["apx", "apples", "bananas", "c"] {
            assert!(
                !trie.starts_with(prefix),
                "{prefix:?} should not be a prefix"
            );
        }
    }

    #[test]
    fn deletes_words_without_affecting_others() {
        let mut trie = sample_trie();

        assert!(trie.delete("app"));
        assert!(!trie.search("app"));
        assert!(trie.search("apple"));
        assert!(trie.search("apricot"));

        assert!(trie.delete("apple"));
        assert!(!trie.search("apple"));
        assert!(!trie.starts_with("app"));
        assert!(trie.search("apricot"));

        assert!(trie.delete("banana"));
        assert!(!trie.starts_with("b"));

        assert!(trie.delete("apricot"));
        assert!(!trie.starts_with("a"));
        // The empty prefix is always a prefix, even of an empty trie.
        assert!(trie.starts_with(""));
    }

    #[test]
    fn deleting_a_missing_word_is_a_no_op() {
        let mut trie = sample_trie();

        assert!(!trie.delete("appl"));
        assert!(!trie.delete("bananas"));
        assert!(!trie.delete("cherry"));
        assert!(!trie.delete(""));
        assert!(trie.search("app"));
        assert!(trie.search("apple"));
        assert!(trie.search("banana"));
    }

    #[test]
    fn supports_unicode_words() {
        let mut trie = Trie::new();
        trie.insert("咖啡");
        trie.insert("咖啡馆");
        trie.insert("café");

        assert!(trie.search("咖啡"));
        assert!(trie.search("咖啡馆"));
        assert!(trie.search("café"));
        assert!(trie.starts_with("咖"));
        assert!(!trie.search("咖"));

        assert!(trie.delete("咖啡"));
        assert!(!trie.search("咖啡"));
        assert!(trie.search("咖啡馆"));
        assert!(trie.starts_with("咖"));
    }

    #[test]
    fn handles_the_empty_word() {
        let mut trie = Trie::new();
        trie.insert("");

        assert!(trie.search(""));
        assert!(trie.starts_with(""));
        assert!(!trie.search("a"));

        assert!(trie.delete(""));
        assert!(!trie.search(""));
        assert!(trie.starts_with(""));
    }
}
