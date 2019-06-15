use log::info;
use rbxlx_to_rojo::{filesystem::FileSystem, process_instructions};
use std::fs;

fn main() {
    env_logger::init();

    info!("rbxlx-to-rojo {}", env!("CARGO_PKG_VERSION"));
    let rbxlx_path = std::env::args()
        .nth(1)
        .expect("invalid arguments - ./rbxlx-to-rojo place.rbxlx");
    let rbxlx_source = fs::read_to_string(&rbxlx_path).expect("couldn't read rbxlx file");
    let root = std::env::args().nth(2).unwrap_or_else(|| ".".to_string());
    let mut filesystem = FileSystem::from_root(root.into());
    let tree = rbx_xml::from_str_default(&rbxlx_source).expect("couldn't deserialize rbxlx");

    info!("processing");
    process_instructions(&tree, &mut filesystem);
    info!("done");
}
