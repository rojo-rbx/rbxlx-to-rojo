use crate::{filesystem::FileSystem, process_instructions, structures::*};
use pretty_assertions::assert_eq;
use rbx_dom_weak::RbxInstanceProperties;
use serde::{Deserialize, Serialize};
use std::{collections::HashMap, fs, io::ErrorKind};

// #[derive(Deserialize, Serialize, Debug, PartialEq)]
// struct VirtualInstance(RbxInstance);

// impl PartialEq<VirtualInstance> for VirtualInstance {
// 	fn eq(&self, other: &VirtualInstance) -> bool {
// 		self.properties == other.properties
// 	}
// }

#[derive(Deserialize, Serialize, Debug, PartialEq)]
#[serde(untagged)]
enum VirtualFileContents {
    Bytes(String),
    Instance(RbxInstanceProperties),
    Vfs(VirtualFileSystem),
}

#[derive(Deserialize, Serialize, Debug, PartialEq)]
struct VirtualFile {
    contents: VirtualFileContents,
}

#[derive(Deserialize, Serialize, Debug, PartialEq, Default)]
struct VirtualFileSystem {
    files: HashMap<String, VirtualFile>,
}

impl InstructionReader for VirtualFileSystem {
    fn read_instruction<'a>(&mut self, instruction: Instruction<'a>) {
        match instruction {
            Instruction::CreateFile { filename, contents } => {
                let parent = filename
                    .parent()
                    .expect("no parent?")
                    .to_string_lossy()
                    .into_owned();
                let filename = filename
                    .file_name()
                    .expect("no filename?")
                    .to_string_lossy()
                    .into_owned();

                let system = if parent == "" {
                    self
                } else {
                    match self
                        .files
                        .get_mut(&parent)
                        .unwrap_or_else(|| panic!("no folder for {:?}", parent))
                        .contents
                    {
                        VirtualFileContents::Vfs(ref mut system) => system,
                        _ => unreachable!("attempt to parent to a file"),
                    }
                };

                let contents_string = String::from_utf8_lossy(&contents).into_owned();
                let rbxmx = filename.ends_with(".rbxmx");
                system.files.insert(
                    filename,
                    VirtualFile {
                        contents: if rbxmx {
                            let tree = rbx_xml::from_str_default(&contents_string)
                                .expect("couldn't decode encoded xml");
                            let child_id = tree
                                .get_instance(tree.get_root_id())
                                .unwrap()
                                .get_children_ids()[0];
                            let child_instance =
                                tree.get_instance(child_id).unwrap().clone();
                            VirtualFileContents::Instance((*child_instance).clone())
                        } else {
                            VirtualFileContents::Bytes(contents_string)
                        },
                    },
                );
            }

            Instruction::CreateFolder { folder } => {
                let name = folder.to_string_lossy().into_owned();
                self.files.insert(
                    name,
                    VirtualFile {
                        contents: VirtualFileContents::Vfs(VirtualFileSystem {
                            files: HashMap::new(),
                        }),
                    },
                );
            }
        }
    }
}

#[test]
fn run_tests() {
    for entry in fs::read_dir("./test-files").expect("couldn't read test-files") {
        let entry = entry.unwrap();
        let path = entry.path();

        let mut source_path = path.clone();
        source_path.push("source.rbxmx");
        let source = fs::read_to_string(&source_path).expect("couldn't read source.rbxmx");

        let tree = rbx_xml::from_str_default(&source).expect("couldn't deserialize source.rbxmx");

        let mut vfs = VirtualFileSystem::default();
        process_instructions(&tree, &mut vfs);

        let mut expected_path = path.clone();
        expected_path.push("output.json");

        if let Ok(expected) = fs::read_to_string(&expected_path) {
            assert_eq!(
                serde_json::from_str::<VirtualFileSystem>(&expected).unwrap(),
                vfs,
            );
        } else {
            let output = serde_json::to_string_pretty(&vfs).unwrap();
            fs::write(&expected_path, output).expect("couldn't write to output.json");
        }

        let filesystem_path = path.join("filesystem");
        if let Err(error) = fs::remove_dir_all(&filesystem_path) {
            match error.kind() {
                ErrorKind::NotFound => {}
                other => panic!("couldn't remove filesystem dir: {:?}", other),
            }
        }
        let mut filesystem = FileSystem::from_root(filesystem_path);
        process_instructions(&tree, &mut filesystem);
    }
}
