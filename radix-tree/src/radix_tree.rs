//! A compressed trie (radix tree).
//!
//! Every edge carries a non-empty string label.  Sibling edges always start
//! with distinct characters, so a node has at most one matching child for a
//! given first character.  Nodes that are neither the end of a word nor
//! branching are collapsed during deletion.
//!
//! The labels are split on `char` boundaries, so the tree works with
//! arbitrary Unicode text.

use std::collections::HashMap;

#[derive(Debug, Default, Clone)]
pub struct RadixTreeNode {
    pub children: HashMap<String, Box<RadixTreeNode>>,
    pub is_end_of_word: bool,
}

#[derive(Debug, Default)]
pub struct RadixTree {
    root: RadixTreeNode,
}

impl RadixTree {
    pub fn new() -> Self {
        Self::default()
    }

    /// Inserts `word` into the tree. Inserting an existing word is a no-op.
    pub fn insert(&mut self, word: &str) {
        let mut current = &mut self.root;
        let mut offset = 0;

        loop {
            let remaining = &word[offset..];
            if remaining.is_empty() {
                current.is_end_of_word = true;
                return;
            }

            let first = remaining.chars().next().unwrap();
            let Some(key) = current
                .children
                .keys()
                .find(|key| key.starts_with(first))
                .cloned()
            else {
                current.children.insert(
                    remaining.to_owned(),
                    Box::new(RadixTreeNode {
                        children: HashMap::new(),
                        is_end_of_word: true,
                    }),
                );
                return;
            };

            let common = common_prefix_len(&key, remaining);
            if common == key.chars().count() {
                // The whole edge label matches; descend into the child.
                offset += key.len();
                current = current.children.get_mut(&key).unwrap();
                continue;
            }

            // The paths diverge in the middle of this edge. Split the edge at
            // the longest common prefix and create an intermediate node.
            let child = current.children.remove(&key).unwrap();
            let split = byte_index_of_char(&key, common);
            let (edge, suffix) = key.split_at(split);
            let common_bytes = byte_index_of_char(remaining, common);

            let mut intermediate = RadixTreeNode {
                children: HashMap::new(),
                is_end_of_word: false,
            };
            intermediate.children.insert(suffix.to_owned(), child);
            current
                .children
                .insert(edge.to_owned(), Box::new(intermediate));

            offset += common_bytes;
            current = current.children.get_mut(edge).unwrap();
        }
    }

    /// Returns `true` if `word` was previously inserted.
    pub fn search(&self, word: &str) -> bool {
        let mut current = &self.root;
        let mut remaining = word;

        loop {
            if remaining.is_empty() {
                return current.is_end_of_word;
            }

            let first = remaining.chars().next().unwrap();
            let Some((key, child)) = current
                .children
                .iter()
                .find(|(key, _)| key.starts_with(first))
            else {
                return false;
            };

            let Some(rest) = remaining.strip_prefix(key.as_str()) else {
                return false;
            };
            remaining = rest;
            current = child.as_ref();
        }
    }

    /// Returns `true` if at least one inserted word starts with `prefix`.
    pub fn starts_with(&self, prefix: &str) -> bool {
        let mut current = &self.root;
        let mut remaining = prefix;

        loop {
            if remaining.is_empty() {
                return true;
            }

            let first = remaining.chars().next().unwrap();
            let Some((key, child)) = current
                .children
                .iter()
                .find(|(key, _)| key.starts_with(first))
            else {
                return false;
            };

            if let Some(rest) = remaining.strip_prefix(key.as_str()) {
                remaining = rest;
                current = child.as_ref();
            } else {
                // The prefix ends inside this edge: it is a prefix of every
                // word below the edge, provided the visible part matches.
                return key.starts_with(remaining);
            }
        }
    }

    /// Removes `word` from the tree.
    ///
    /// Returns `true` if the word was present. Redundant nodes left behind by
    /// the removal are pruned or merged with their only child.
    pub fn delete(&mut self, word: &str) -> bool {
        Self::delete_from(&mut self.root, word)
    }

    fn delete_from(node: &mut RadixTreeNode, remaining: &str) -> bool {
        if remaining.is_empty() {
            if !node.is_end_of_word {
                return false;
            }
            node.is_end_of_word = false;
            return true;
        }

        let first = remaining.chars().next().unwrap();
        let Some(key) = node
            .children
            .keys()
            .find(|key| key.starts_with(first))
            .cloned()
        else {
            return false;
        };

        let Some(rest) = remaining.strip_prefix(key.as_str()) else {
            return false;
        };

        if !Self::delete_from(node.children.get_mut(&key).unwrap(), rest) {
            return false;
        }

        let child_is_dead = node
            .children
            .get(&key)
            .is_some_and(|child| child.children.is_empty() && !child.is_end_of_word);
        if child_is_dead {
            node.children.remove(&key);
            return true;
        }

        // A node that is not itself a word and has exactly one child is
        // redundant: merge its edge label with the child's edge label.
        let merge_child_key = node.children.get(&key).and_then(|child| {
            if !child.is_end_of_word && child.children.len() == 1 {
                child.children.keys().next().cloned()
            } else {
                None
            }
        });

        if let Some(grandchild_key) = merge_child_key {
            let merged_key = format!("{key}{grandchild_key}");
            let mut child = node.children.remove(&key).unwrap();
            let grandchild = child.children.remove(&grandchild_key).unwrap();
            let grandchild = *grandchild;

            child.is_end_of_word = grandchild.is_end_of_word;
            child.children = grandchild.children;

            node.children.insert(merged_key, child);
        }

        true
    }
}

fn common_prefix_len(a: &str, b: &str) -> usize {
    a.chars()
        .zip(b.chars())
        .take_while(|(left, right)| left == right)
        .count()
}

/// Returns the byte index of the `char_index`-th character, or `s.len()` when
/// `char_index` is equal to the character count.
fn byte_index_of_char(s: &str, char_index: usize) -> usize {
    s.char_indices()
        .nth(char_index)
        .map_or(s.len(), |(byte_index, _)| byte_index)
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::collections::HashSet;

    fn sample_tree() -> RadixTree {
        let mut tree = RadixTree::new();
        for word in ["apple", "app", "apricot", "banana"] {
            tree.insert(word);
        }
        tree
    }

    fn assert_invariants(node: &RadixTreeNode, is_root: bool) {
        if !is_root {
            assert!(
                node.is_end_of_word || !node.children.is_empty(),
                "non-root node must be a word or have children"
            );
            assert!(
                node.is_end_of_word || node.children.len() != 1,
                "non-root node must not have exactly one child unless it ends a word"
            );
        }

        let mut first_chars = HashSet::new();
        for (label, child) in &node.children {
            assert!(!label.is_empty(), "edge labels must not be empty");
            let first = label.chars().next().unwrap();
            assert!(
                first_chars.insert(first),
                "siblings must start with distinct characters, found {first:?}"
            );
            assert_invariants(child, false);
        }
    }

    fn collect_words(node: &RadixTreeNode, prefix: &mut String, words: &mut HashSet<String>) {
        if node.is_end_of_word {
            words.insert(prefix.clone());
        }
        for (label, child) in &node.children {
            let len = prefix.len();
            prefix.push_str(label);
            collect_words(child, prefix, words);
            prefix.truncate(len);
        }
    }

    #[test]
    fn inserts_and_searches_words() {
        let tree = sample_tree();

        for word in ["apple", "app", "apricot", "banana"] {
            assert!(tree.search(word), "{word:?} should be present");
        }
        for word in ["appl", "apples", "apricots", "ban", "bananas", "cherry"] {
            assert!(!tree.search(word), "{word:?} should be absent");
        }
    }

    #[test]
    fn queries_prefixes() {
        let tree = sample_tree();

        for prefix in ["", "a", "ap", "app", "appl", "apple", "apricot", "b", "ban"] {
            assert!(tree.starts_with(prefix), "{prefix:?} should be a prefix");
        }
        for prefix in ["apx", "apples", "bananas", "c"] {
            assert!(
                !tree.starts_with(prefix),
                "{prefix:?} should not be a prefix"
            );
        }
    }

    #[test]
    fn deletes_words_without_affecting_others() {
        let mut tree = sample_tree();

        assert!(tree.delete("app"));
        assert!(!tree.search("app"));
        assert!(tree.search("apple"));
        assert!(tree.search("apricot"));
        assert!(tree.starts_with("app"));

        assert!(tree.delete("apple"));
        assert!(!tree.search("apple"));
        assert!(!tree.starts_with("app"));
        assert!(tree.search("apricot"));

        assert!(tree.delete("banana"));
        assert!(!tree.starts_with("b"));

        assert!(tree.delete("apricot"));
        assert!(!tree.starts_with("a"));
        assert!(tree.starts_with(""));
    }

    #[test]
    fn deleting_a_missing_word_is_a_no_op() {
        let mut tree = sample_tree();

        assert!(!tree.delete("appl"));
        assert!(!tree.delete("apples"));
        assert!(!tree.delete("bananas"));
        assert!(!tree.delete("cherry"));
        assert!(!tree.delete(""));
        assert!(tree.search("app"));
        assert!(tree.search("apple"));
        assert!(tree.search("apricot"));
        assert!(tree.search("banana"));
    }

    #[test]
    fn collapses_edges_after_deletion() {
        let mut tree = RadixTree::new();
        tree.insert("abc");
        tree.insert("abd");

        assert!(tree.delete("abd"));
        assert!(tree.search("abc"));
        assert!(!tree.search("abd"));
        assert!(tree.starts_with("ab"));
        assert!(!tree.starts_with("abd"));

        // The two former branches should have been merged into one "abc" edge.
        tree.insert("abe");
        for word in ["abc", "abe"] {
            assert!(tree.search(word));
        }
        assert!(!tree.search("abd"));
    }

    #[test]
    fn merges_through_multiple_levels() {
        let mut tree = sample_tree();

        assert!(tree.delete("app"));
        assert!(!tree.search("app"));
        assert!(tree.search("apple"));
        assert!(tree.search("apricot"));

        assert!(tree.delete("apricot"));
        assert!(!tree.search("apricot"));
        assert!(tree.search("apple"));
        assert!(!tree.search("app"));
        assert!(tree.delete("apple"));
        assert!(!tree.starts_with("a"));
        assert!(tree.search("banana"));
    }

    #[test]
    fn reinserts_deleted_words() {
        let mut tree = sample_tree();
        assert!(tree.delete("apple"));
        assert!(!tree.search("apple"));

        tree.insert("apple");
        assert!(tree.search("apple"));
        assert!(tree.search("app"));
        assert!(tree.delete("app"));
        assert!(!tree.search("app"));
        assert!(tree.search("apple"));
    }

    #[test]
    fn inserting_a_word_twice_is_idempotent() {
        let mut tree = RadixTree::new();
        tree.insert("hello");
        tree.insert("hello");

        assert!(tree.search("hello"));
        assert!(tree.delete("hello"));
        assert!(!tree.search("hello"));
        assert!(!tree.delete("hello"));
    }

    #[test]
    fn supports_unicode_words() {
        let mut tree = RadixTree::new();
        tree.insert("咖啡");
        tree.insert("咖啡馆");
        tree.insert("café");

        assert!(tree.search("咖啡"));
        assert!(tree.search("咖啡馆"));
        assert!(tree.search("café"));
        assert!(tree.starts_with("咖"));
        assert!(!tree.search("咖"));

        assert!(tree.delete("咖啡"));
        assert!(!tree.search("咖啡"));
        assert!(tree.search("咖啡馆"));
        assert!(tree.starts_with("咖"));

        assert!(tree.delete("café"));
        assert!(!tree.search("café"));
        assert!(tree.search("咖啡馆"));
    }

    #[test]
    fn handles_the_empty_word() {
        let mut tree = RadixTree::new();

        assert!(tree.starts_with(""));
        assert!(!tree.search(""));
        assert!(!tree.starts_with("a"));

        tree.insert("");
        assert!(tree.search(""));
        assert!(tree.starts_with(""));
        assert!(!tree.search("a"));

        tree.insert("a");
        assert!(tree.search(""));
        assert!(tree.search("a"));

        assert!(tree.delete(""));
        assert!(!tree.search(""));
        assert!(tree.search("a"));

        assert!(tree.delete("a"));
        assert!(!tree.search("a"));
        assert!(tree.starts_with(""));
    }

    #[test]
    fn behaves_like_a_set_of_strings() {
        const ALPHABET: [char; 3] = ['a', 'b', 'c'];

        let mut tree = RadixTree::new();
        let mut words = HashSet::new();
        let mut seed = 0x1234_5678_9abc_def0_u64;
        let mut next = || {
            seed = seed
                .wrapping_mul(6_364_136_223_846_793_005)
                .wrapping_add(1_442_695_040_888_963_407);
            seed
        };

        for _ in 0..300 {
            let len = (next() % 6) as usize;
            let mut word = String::with_capacity(len);
            for _ in 0..len {
                word.push(ALPHABET[(next() % ALPHABET.len() as u64) as usize]);
            }

            if next() % 2 == 0 {
                tree.insert(&word);
                words.insert(word);
            } else {
                assert_eq!(
                    tree.delete(&word),
                    words.remove(&word),
                    "delete({word:?}) disagrees with the model"
                );
            }

            assert_invariants(&tree.root, true);
        }

        // Reconstruct the stored words from the tree edges and compare them
        // with the model; this also catches stale word markers.
        let mut actual_words = HashSet::new();
        let mut prefix = String::new();
        collect_words(&tree.root, &mut prefix, &mut actual_words);
        assert_eq!(actual_words, words);

        // Exhaustively verify all strings up to length 5 over the alphabet.
        for len in 0..=5 {
            for code in 0..ALPHABET.len().pow(len as u32) {
                let mut word = String::with_capacity(len);
                let mut digits = code;
                for _ in 0..len {
                    word.push(ALPHABET[digits % ALPHABET.len()]);
                    digits /= ALPHABET.len();
                }

                assert_eq!(
                    tree.search(&word),
                    words.contains(&word),
                    "search({word:?})"
                );
                let expected_prefix =
                    word.is_empty() || words.iter().any(|candidate| candidate.starts_with(&word));
                assert_eq!(
                    tree.starts_with(&word),
                    expected_prefix,
                    "starts_with({word:?})"
                );
            }
        }
    }
}
