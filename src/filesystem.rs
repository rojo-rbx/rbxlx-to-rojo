use crate::structures::*;
use serde::{ser::SerializeMap, Serialize, Serializer};
use std::{
    collections::BTreeMap,
    fs::{self, File},
    io::Write,
    path::PathBuf,
};

const SRC: &str = "src";

fn serialize_project_tree<S: Serializer>(
    tree: &BTreeMap<String, TreePartition>,
    serializer: S,
) -> Result<S::Ok, S::Error> {
    let mut map = serializer.serialize_map(Some(tree.len() + 1))?;
    map.serialize_entry("$className", "DataModel")?;
    for (k, v) in tree {
        map.serialize_entry(k, v)?;
    }
    map.end()
}

#[derive(Clone, Debug, Serialize)]
struct Project {
    name: String,
    #[serde(serialize_with = "serialize_project_tree")]
    tree: BTreeMap<String, TreePartition>,
}

impl Project {
    fn new() -> Self {
        Self {
            name: "project".to_string(),
            tree: BTreeMap::new(),
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
        let source = root.join(SRC);
        let project = Project::new();

        fs::create_dir(&source).ok(); // It'll error later if it matters

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
            Instruction::AddToTree {
                name,
                mut partition,
            } => {
                assert!(
                    self.project.tree.get(&name).is_none(),
                    "Duplicate item added to tree! Instances can't have the same name: {}",
                    name
                );

                if let Some(path) = partition.path {
                    partition.path = Some(PathBuf::from(SRC).join(path));
                }

                for mut child in partition.children.values_mut() {
                    if let Some(path) = &child.path {
                        child.path = Some(PathBuf::from(SRC).join(path));
                    }
                }

                self.project.tree.insert(name, partition);
            }

            Instruction::CreateFile { filename, contents } => {
                let mut file = File::create(self.source.join(&filename)).unwrap_or_else(|error| {
                    panic!("can't create file {:?}: {:?}", filename, error)
                });
                file.write_all(&contents).unwrap_or_else(|error| {
                    panic!("can't write to file {:?} due to {:?}", filename, error)
                });
            }

            Instruction::CreateFolder { folder } => {
                fs::create_dir_all(self.source.join(&folder)).unwrap_or_else(|error| {
                    panic!("can't write to folder {:?}: {:?}", folder, error)
                });
            }
        }
    }

    fn finish_instructions(&mut self) {
        let mut file = File::create(self.root.join("default.project.json"))
            .expect("can't create default.project.json");
        file.write_all(
            &serde_json::to_string_pretty(&self.project)
                .expect("couldn't serialize project")
                .as_bytes(),
        )
        .expect("can't write project");
    }
}
