use crate::structures::*;
use serde::Serialize;
use std::{
    collections::HashMap,
    fs::{self, File},
    io::Write,
    path::PathBuf,
};

#[derive(Clone, Debug, Serialize)]
pub struct Project {
    name: String,
    tree: HashMap<String, TreePartition>,
}

impl Project {
    fn new() -> Self {
        Self {
            name: "project".to_string(),
            tree: HashMap::new(),
        }
    }
}

#[derive(Clone, Debug)]
pub struct FileSystem {
    project: Project,
    root: PathBuf,
    source: PathBuf,
}

impl FileSystem {
    pub fn from_root(root: PathBuf) -> Self {
        let source = root.join("src");
        let project = Project::new();

        Self {
            project,
            root,
            source,
        }
    }
}

impl InstructionReader for FileSystem {
    fn read_instruction<'a>(&mut self, instruction: Instruction<'a>) {
        match instruction {
            Instruction::AddToTree { name, partition } => {
                assert!(
                    self.project.tree.get(&name).is_none(),
                    "Duplicate item added to tree! Instances can't have the same name: {}",
                    name
                );
                self.project.tree.insert(name, partition);
            }

            Instruction::CreateFile { filename, contents } => {
                let mut file = File::create(self.source.join(filename)).expect("can't create file");
                file.write_all(&contents).expect("can't write file");
            }

            Instruction::CreateFolder { folder } => {
                fs::create_dir_all(self.source.join(folder)).expect("can't write folder");
            }
        }
    }

    fn finish_instructions(&mut self) {
        let mut file = File::create(self.source.join("default.project.json"))
            .expect("can't create default.project.json");
        file.write_all(
            &serde_json::to_string_pretty(&self.project)
                .expect("couldn't serialize project")
                .as_bytes(),
        )
        .expect("can't write project");
    }
}
