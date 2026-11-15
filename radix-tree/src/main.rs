use radix_tree::radix_tree::RadixTree;
use radix_tree::trie::Trie;

fn main() {
    let mut trie = Trie::new();
    for word in ["apple", "app", "apricot", "banana"] {
        trie.insert(word);
    }

    println!("Trie");
    println!("  search(\"apple\")      = {}", trie.search("apple"));
    println!("  starts_with(\"app\")   = {}", trie.starts_with("app"));
    println!("  delete(\"app\")        = {}", trie.delete("app"));
    println!("  search(\"app\")        = {}", trie.search("app"));
    println!("  search(\"apple\")      = {}", trie.search("apple"));

    let mut radix = RadixTree::new();
    for word in ["apple", "app", "apricot", "banana"] {
        radix.insert(word);
    }

    println!("\nRadix Tree");
    println!("  search(\"apple\")      = {}", radix.search("apple"));
    println!("  starts_with(\"app\")   = {}", radix.starts_with("app"));
    println!("  delete(\"app\")        = {}", radix.delete("app"));
    println!("  search(\"app\")        = {}", radix.search("app"));
    println!("  search(\"apple\")      = {}", radix.search("apple"));
}
