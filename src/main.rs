use lazy_static::lazy_static;
use rbx_dom_weak::{RbxInstance, RbxInstanceProperties, RbxTree, RbxValue, RbxValueConversion};
use rbx_reflection::RbxInstanceClass;
use std::{
    borrow::Cow,
    collections::HashMap,
    path::{Path, PathBuf},
};
use structures::*;

mod filesystem;
mod structures;

#[cfg(test)]
mod tests;

lazy_static! {
    static ref CLASSES: &'static HashMap<&'static str, RbxInstanceClass> =
        rbx_reflection::get_classes();
}

#[derive(Debug)]
enum Error {
    XmlEncodeError(rbx_xml::EncodeError),
}

struct TreeIterator<'a, I: InstructionReader + ?Sized> {
    instruction_reader: &'a mut I,
    path: &'a Path,
    tree: &'a RbxTree,
}

fn is_default_property(key: &str, value: &RbxValue) -> bool {
    match key {
        "Tags" => match value {
            RbxValue::BinaryString { value } => value.is_empty(),
            _ => false,
        },

        _ => false,
    }
}

fn repr_instance<'a>(
    base: &'a Path,
    child: &'a RbxInstance,
) -> Result<(Vec<Instruction<'a>>, Cow<'a, Path>), Error> {
    match child.class_name.as_str() {
        "Folder" => {
            let folder_path = base.join(&child.name);
            let owned: Cow<'a, Path> = Cow::Owned(folder_path);
            let clone = owned.clone();
            Ok((vec![Instruction::CreateFolder { folder: clone }], owned))
        }

        "Script" | "LocalScript" | "ModuleScript" => {
            let extension = match child.class_name.as_str() {
                "Script" => ".server",
                "LocalScript" => ".client",
                "ModuleScript" => "",
                _ => unreachable!(),
            };

            let source = match child.properties.get("Source").expect("no Source") {
                RbxValue::String { value } => value,
                _ => unreachable!(),
            }
            .as_bytes();

            if child.get_children_ids().is_empty() {
                Ok((
                    vec![Instruction::CreateFile {
                        filename: Cow::Owned(base.join(format!("{}{}.lua", child.name, extension))),
                        contents: Cow::Borrowed(source),
                    }],
                    Cow::Borrowed(base),
                ))
            } else {
                let folder_path: Cow<'a, Path> = Cow::Owned(base.join(&child.name));
                Ok((
                    vec![
                        Instruction::CreateFolder {
                            folder: folder_path.clone(),
                        },
                        Instruction::CreateFile {
                            filename: Cow::Owned(
                                folder_path.join(format!("init{}.lua", extension)),
                            ),
                            contents: Cow::Borrowed(source),
                        },
                    ],
                    folder_path,
                ))
            }
        }

        other_class => {
            // When all else fails, we can *probably* make an rbxmx out of it
            let mut tree = RbxTree::new(RbxInstanceProperties {
                name: "VirtualInstance".to_string(),
                class_name: "DataModel".to_string(),
                properties: HashMap::new(),
            });

            let properties = match CLASSES.get(other_class) {
                Some(reflected) => {
                    let mut patch = child.clone();
                    patch.properties.retain(|key, value| {
                        if is_default_property(key, value) {
                            return false;
                        }

                        if let Some(default) = reflected.default_properties.get(key.as_str()) {
                            match default.try_convert_ref(value.get_type()) {
                                RbxValueConversion::Converted(converted) => &converted != value,
                                RbxValueConversion::Unnecessary => default != value,
                                RbxValueConversion::Failed => {
                                    println!("property type in reflection doesnt match given? {} expects {:?}, given {:?}", key, default.get_type(), value.get_type());
                                    true
                                },
                            }
                        } else {
                            println!("property not in reflection? {}.{}", other_class, key);
                            true
                        }
                    });
                    Cow::Owned(patch.properties.drain().collect())
                }

                None => {
                    println!("class is not in reflection? {}", other_class);
                    Cow::Borrowed(&child.properties)
                }
            }
            .into_owned();

            let properties = RbxInstanceProperties {
                name: child.name.clone(),
                class_name: other_class.to_string(),
                properties,
            };

            let root_id = tree.get_root_id();
            let id = tree.insert_instance(properties, root_id);

            let mut buffer = Vec::new();
            rbx_xml::encode(&tree, &[id], &mut buffer).map_err(Error::XmlEncodeError)?;
            Ok((
                vec![Instruction::CreateFile {
                    filename: Cow::Owned(base.join(&format!("{}.rbxmx", child.name))),
                    contents: Cow::Owned(buffer),
                }],
                Cow::Borrowed(base),
            ))
        }
    }
}

impl<'a, I: InstructionReader + ?Sized> TreeIterator<'a, I> {
    fn visit_instructions(&mut self, instance: &RbxInstance) {
        for child_id in instance.get_children_ids() {
            let child = self
                .tree
                .get_instance(*child_id)
                .expect("got fake child id?");
            let (instructions_to_create_base, path) = repr_instance(&self.path, child)
                .expect("an error occurred when trying to represent an instance");
            self.instruction_reader
                .read_instructions(instructions_to_create_base);
            TreeIterator {
                instruction_reader: self.instruction_reader,
                path: &path,
                tree: self.tree,
            }
            .visit_instructions(child);
        }
    }
}

pub fn process_instructions(tree: &RbxTree, instruction_reader: &mut InstructionReader) {
    let root = tree.get_root_id();
    let root_instance = tree.get_instance(root).expect("fake root id?");
    let path = PathBuf::new();

    TreeIterator {
        instruction_reader,
        path: &path,
        tree,
    }
    .visit_instructions(&root_instance);
}

fn main() {
    println!("rbxlx-to-rojo {}", env!("CARGO_PKG_VERSION"));
}
