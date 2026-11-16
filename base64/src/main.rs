use base64::{decode, encode};

fn main() {
    let args = std::env::args().collect::<Vec<String>>();
    if args.len() < 4 {
        eprintln!("Usage: {} <encode|decode> -s/-f <string/file_path> (-o <output_file>)", args[0]);
        std::process::exit(1);
    }

    let operation = &args[1];
    let source_type = &args[2];
    let source_value = &args[3];

    let output_file = args.get(5);

    let mut output: Option<String> = None;
    match (operation.as_str(), source_type.as_str()) {
        ("encode", "-s") => {
            let encoded = encode(source_value);
            output = Some(encoded);
        }
        ("decode", "-s") => {
            match decode(source_value) {
                Some(decoded) => output = Some(decoded),
                None => eprintln!("Decoding failed"),
            }
        }
        ("encode", "-f") => {
            let content = std::fs::read_to_string(source_value)
                .expect("Failed to read the file");
            let encoded = encode(&content);
            output = Some(encoded);
        }
        ("decode", "-f") => {
            let content = std::fs::read_to_string(source_value)
                .expect("Failed to read the file");
            match decode(&content) {
                Some(decoded) => output = Some(decoded),
                None => eprintln!("Decoding failed"),
            }
        }
        _ => {
            eprintln!("Invalid operation or source type");
            std::process::exit(1);
        }
    }

    if let Some(output) = output {
        if let Some(file) = output_file {
            std::fs::write(file, &output).expect("Failed to write to the file");
        } else {
            println!("{}", output);
        }
    }
}
