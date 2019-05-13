use crate::structures::*;
use std::{
    fs::{self, File},
    io::Write,
    path::PathBuf,
};

#[derive(Clone, Debug)]
pub struct FileSystem {
    root: PathBuf,
    source: PathBuf,
}

impl FileSystem {
    pub fn from_root(root: PathBuf) -> Self {
        let source = root.join("src");

        Self { root, source }
    }
}

impl InstructionReader for FileSystem {
    fn read_instruction<'a>(&mut self, instruction: Instruction<'a>) {
        match instruction {
            Instruction::CreateFile { filename, contents } => {
                let mut file = File::create(self.source.join(filename)).expect("can't create file");
                file.write_all(&contents).expect("can't write file");
            }

            Instruction::CreateFolder { folder } => {
                fs::create_dir_all(self.source.join(folder)).expect("can't write folder");
            }
        }
    }
}
