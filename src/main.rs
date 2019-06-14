use log::{debug, info, warn};
use rbx_dom_weak::{RbxId, RbxInstance, RbxTree, RbxValue, RbxValueConversion, RbxValueType};
use std::{
    borrow::Cow,
    collections::{BTreeMap, HashMap, HashSet},
    fs,
    path::{Path, PathBuf},
};

use filesystem::FileSystem;
use structures::*;

mod filesystem;
mod structures;

#[cfg(test)]
mod tests;

lazy_static::lazy_static! {
    static ref RESPECTED_SERVICES: HashSet<&'static str> = include_str!("./respected-services.txt").lines().collect();
}

#[derive(Debug)]
enum Error {
    ShouldntBeRepresented, // Empty services, services not officially respected
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
    has_scripts: &'a HashMap<RbxId, bool>,
) -> Result<(Vec<Instruction<'a>>, Cow<'a, Path>), Error> {
    match child.class_name.as_str() {
        "Folder" => {
            let folder_path = base.join(&child.name);
            let owned: Cow<'a, Path> = Cow::Owned(folder_path);
            let clone = owned.clone();
            Ok((
                vec![
                    Instruction::CreateFolder { folder: clone },
                    Instruction::CreateFile {
                        filename: Cow::Owned(owned.join("init.meta.json")),
                        contents: Cow::Owned(
                            serde_json::to_string_pretty(&MetaFile {
                                class_name: None,
                                properties: BTreeMap::new(),
                                ignore_unknown_instances: true,
                            })
                            .unwrap()
                            .as_bytes()
                            .into(),
                        ),
                    },
                ],
                owned,
            ))
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
            // When all else fails, we can make a meta folder if there's scripts in it
            match has_scripts.get(&child.get_id()) {
                Some(true) => {}
                _ => return Err(Error::ShouldntBeRepresented),
            }

            // let mut tree = RbxTree::new(RbxInstanceProperties {
            //     name: "VirtualInstance".to_string(),
            //     class_name: "DataModel".to_string(),
            //     properties: HashMap::new(),
            // });

            let properties = match rbx_reflection::get_class_descriptor(other_class) {
                Some(reflected) => {
                    let treat_as_service = RESPECTED_SERVICES.contains(other_class);
                    // Don't represent services not in respected-services
                    if reflected.is_service() && !treat_as_service {
                        return Err(Error::ShouldntBeRepresented);
                    }

                    let mut patch = child.clone();
                    patch.properties.retain(|key, value| {
                        if is_default_property(key, value) {
                            return false;
                        }

                        if value.get_type() == RbxValueType::Ref {
                            warn!("rbxlx-to-rojo does not currently support Refs");
                            return false;
                        }

                        if let Some(default) = reflected.get_default_value(key.as_str()) {
                            match default.try_convert_ref(value.get_type()) {
                                RbxValueConversion::Converted(converted) => &converted != value,
                                RbxValueConversion::Unnecessary => default != value,
                                RbxValueConversion::Failed => {
                                    debug!("property type in reflection doesnt match given? {} expects {:?}, given {:?}", key, default.get_type(), value.get_type());
                                    true
                                },
                            }
                        } else {
                            debug!("property not in reflection? {}.{}", other_class, key);
                            true
                        }
                    });

                    if treat_as_service {
                        // Don't represent empty services with no property changes
                        if patch.properties.is_empty() && child.get_children_ids().is_empty() {
                            return Err(Error::ShouldntBeRepresented);
                        }

                        let new_base: Cow<'a, Path> = Cow::Owned(base.join(&child.name));
                        let mut instructions = vec![Instruction::add_to_tree(patch, new_base.to_path_buf())];
                        if !child.get_children_ids().is_empty() {
                            instructions.push(Instruction::CreateFolder {
                                folder: new_base.clone(),
                            });
                        }

                        return Ok((instructions, new_base));
                    }

                    Cow::Owned(patch.properties.drain().collect())
                }

                None => {
                    debug!("class is not in reflection? {}", other_class);
                    Cow::Borrowed(&child.properties)
                }
            }
            .into_owned();

            // If there are scripts, we'll need to make a .meta.json folder
            let folder_path: Cow<'a, Path> = Cow::Owned(base.join(&child.name));
            let meta = MetaFile {
                class_name: Some(child.class_name.clone()),
                properties: properties.into_iter().collect(),
                ignore_unknown_instances: true,
            };

            Ok((
                vec![
                    Instruction::CreateFolder {
                        folder: folder_path.clone(),
                    },
                    Instruction::CreateFile {
                        filename: Cow::Owned(folder_path.join("init.meta.json")),
                        contents: Cow::Owned(
                            serde_json::to_string_pretty(&meta)
                                .expect("couldn't serialize meta")
                                .as_bytes()
                                .into(),
                        ),
                    },
                ],
                folder_path,
            ))

            // let properties = RbxInstanceProperties {
            //     name: child.name.clone(),
            //     class_name: other_class.to_string(),
            //     properties,
            // };

            // let root_id = tree.get_root_id();
            // let id = tree.insert_instance(properties, root_id);

            // let mut buffer = Vec::new();
            // rbx_xml::to_writer_default(&mut buffer, &tree, &[id]).map_err(Error::XmlEncodeError)?;
            // Ok((
            //     vec![Instruction::CreateFile {
            //         filename: Cow::Owned(base.join(&format!("{}.rbxmx", child.name))),
            //         contents: Cow::Owned(buffer),
            //     }],
            //     Cow::Borrowed(base),
            // ))
        }
    }
}

impl<'a, I: InstructionReader + ?Sized> TreeIterator<'a, I> {
    fn visit_instructions(&mut self, instance: &RbxInstance, has_scripts: &HashMap<RbxId, bool>) {
        for child_id in instance.get_children_ids() {
            let child = self
                .tree
                .get_instance(*child_id)
                .expect("got fake child id?");
            let (instructions_to_create_base, path) =
                match repr_instance(&self.path, child, has_scripts) {
                    Ok((instructions_to_create_base, path)) => (instructions_to_create_base, path),
                    Err(Error::ShouldntBeRepresented) => continue,
                    // Err(other) => panic!(
                    //     "an error occured when trying to represent an instance - {:?}",
                    //     other
                    // ),
                };
            self.instruction_reader
                .read_instructions(instructions_to_create_base);
            TreeIterator {
                instruction_reader: self.instruction_reader,
                path: &path,
                tree: self.tree,
            }
            .visit_instructions(child, has_scripts);
        }
    }
}

fn check_has_scripts(
    tree: &RbxTree,
    instance: &RbxInstance,
    has_scripts: &mut HashMap<RbxId, bool>,
) -> bool {
    let result = match instance.class_name.as_str() {
        "Script" | "LocalScript" | "ModuleScript" => {
            for descendant in tree.descendants(instance.get_id()) {
                has_scripts.insert(descendant.get_id(), true);
            }

            true
        }

        _ => {
            let mut children_have_scripts = false;

            for child_id in instance.get_children_ids() {
                children_have_scripts = children_have_scripts
                    || check_has_scripts(
                        tree,
                        tree.get_instance(*child_id).expect("fake child id?"),
                        has_scripts,
                    );
            }

            children_have_scripts
        }
    };

    has_scripts.insert(instance.get_id(), result);
    result
}

pub fn process_instructions(tree: &RbxTree, instruction_reader: &mut InstructionReader) {
    let root = tree.get_root_id();
    let root_instance = tree.get_instance(root).expect("fake root id?");
    let path = PathBuf::new();

    let mut has_scripts = HashMap::new();
    check_has_scripts(tree, root_instance, &mut has_scripts);

    TreeIterator {
        instruction_reader,
        path: &path,
        tree,
    }
    .visit_instructions(&root_instance, &has_scripts);

    instruction_reader.finish_instructions();
}

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
