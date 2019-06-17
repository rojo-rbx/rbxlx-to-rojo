use log::{debug, info};
use rbxlx_to_rojo::{filesystem::FileSystem, process_instructions};
use std::{fmt, fs, io, path::PathBuf};

#[derive(Debug)]
enum Problem {
    DecodeError(rbx_xml::DecodeError),
    IoError(&'static str, io::Error),
    NFDCancel,
    NFDError(String),
}

impl fmt::Display for Problem {
    fn fmt(&self, formatter: &mut fmt::Formatter) -> fmt::Result {
        match self {
            Problem::DecodeError(error) => write!(
                formatter,
                "While attempting to decode the place file, at {} rbx_xml didn't know what to do",
                error,
            ),

            Problem::IoError(doing_what, error) => {
                write!(formatter, "While attempting to {}, {}", doing_what, error)
            }

            Problem::NFDCancel => write!(formatter, "Didn't choose a file."),

            Problem::NFDError(error) => write!(
                formatter,
                "Something went wrong when choosing a file: {}",
                error,
            ),
        }
    }
}

fn routine() -> Result<(), Problem> {
    info!("rbxlx-to-rojo {}", env!("CARGO_PKG_VERSION"));

    info!("Select a place file.");
    let rbxlx_path = PathBuf::from(match std::env::args().nth(1) {
        Some(text) => text,
        None => match nfd::open_file_dialog(Some("rbxlx,rbxmx"), None)
            .map_err(|error| Problem::NFDError(error.to_string()))?
        {
            nfd::Response::Okay(path) => path,
            nfd::Response::Cancel => Err(Problem::NFDCancel)?,
            _ => unreachable!(),
        },
    });

    debug!("Opening rbxlx file");
    let rbxlx_source = fs::File::open(&rbxlx_path)
        .map_err(|error| Problem::IoError("read the place file", error))?;
    debug!("Read file, decoding");
    let tree = rbx_xml::from_reader_default(&rbxlx_source).map_err(Problem::DecodeError)?;

    info!("Select the path to put your Rojo project in.");
    let root = PathBuf::from(match std::env::args().nth(2) {
        Some(text) => text,
        None => match nfd::open_pick_folder(Some(&rbxlx_path.parent().unwrap().to_string_lossy()))
            .map_err(|error| Problem::NFDError(error.to_string()))?
        {
            nfd::Response::Okay(path) => path,
            nfd::Response::Cancel => Err(Problem::NFDCancel)?,
            _ => unreachable!(),
        },
    })
    .join(rbxlx_path.file_stem().unwrap());

    let mut filesystem = FileSystem::from_root(root.into());

    info!("Starting processing, please wait a bit...");
    process_instructions(&tree, &mut filesystem);
    info!("Done!");
    Ok(())
}

fn main() {
    env_logger::builder()
        .filter_level(log::LevelFilter::Info)
        .init();

    if let Err(error) = routine() {
        eprintln!("An error occurred while using rbxlx-to-rojo.");
        eprintln!("{}", error);
    }
}
