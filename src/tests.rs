use crate::{process_instructions, structures::*};
use pretty_assertions::assert_eq;
use rbx_dom_weak::{RbxInstance, RbxInstanceProperties, RbxTree};
use serde::{Deserialize, Serialize};
use std::{collections::HashMap, fs};

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
        use Instruction::*;
        match instruction {
            CreateFile { filename, contents } => {
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
                match self
                    .files
                    .get_mut(&parent)
                    .unwrap_or_else(|| panic!("no folder for {:?}", parent))
                    .contents
                {
                    VirtualFileContents::Vfs(ref mut system) => {
                        let contents_string = String::from_utf8_lossy(&contents).into_owned();
                        let rbxmx = filename.ends_with(".rbxmx");
                        system.files.insert(
                            filename,
                            VirtualFile {
                                contents: if rbxmx {
                                    let mut tree = RbxTree::new(RbxInstanceProperties {
                                        name: "VirtualInstance".to_string(),
                                        class_name: "DataModel".to_string(),
                                        properties: HashMap::new(),
                                    });

                                    let root_id = tree.get_root_id();
                                    rbx_xml::decode_str(&mut tree, root_id, &contents_string)
                                        .expect("couldn't decode encoded xml");
                                    let child_id =
                                        tree.get_instance(root_id).unwrap().get_children_ids()[0];
									let child_instance = tree.get_instance(child_id).unwrap().clone();
                                    VirtualFileContents::Instance((*child_instance).clone())
                                } else {
                                    VirtualFileContents::Bytes(contents_string)
                                },
                            },
                        );
                    }
                    _ => unreachable!("attempt to parent to a file"),
                }
            }

            CreateFolder { folder } => {
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

        let mut tree = RbxTree::new(RbxInstanceProperties {
            name: "DataModel".to_string(),
            class_name: "DataModel".to_string(),
            properties: HashMap::new(),
        });

        let root_id = tree.get_root_id();
        rbx_xml::decode_str(&mut tree, root_id, &source)
            .expect("couldn't deserialize source.rbxmx");

        let mut vfs = VirtualFileSystem::default();
        process_instructions(tree, &mut vfs);

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
    }
}
