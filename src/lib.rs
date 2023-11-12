use log::debug;
use rbx_dom_weak::{
    types::{Ref, Variant},
    Instance, WeakDom,
};
use std::{
    borrow::Cow,
    collections::{HashMap, HashSet},
    path::{Path, PathBuf},
};

use structures::*;

pub mod filesystem;
pub mod structures;

#[cfg(test)]
mod tests;

lazy_static::lazy_static! {
    static ref NON_TREE_SERVICES: HashSet<&'static str> = include_str!("./non-tree-services.txt").lines().collect();
    static ref RESPECTED_SERVICES: HashSet<&'static str> = include_str!("./respected-services.txt").lines().collect();
}

struct TreeIterator<'a, I: InstructionReader + ?Sized> {
    instruction_reader: &'a mut I,
    path: &'a Path,
    tree: &'a WeakDom,
}

fn check_if_local(child: &Instance) -> &'static str
{
	println!("{:?}", child.properties.get("RunContext"));
	
	// This is very bad, can someone refactor it
	match child.properties.get("RunContext").expect("Non-scripts do not have the RunContext property!") {
		Variant::Enum(value) => {
			match value.to_u32() {
				2 => {return ".client";}
				_ => {return ".server";}
			}
		},
		
		_ => unreachable!(),
	}
}

fn repr_instance<'a>(
    base: &'a Path,
    child: &'a Instance,
    has_scripts: &'a HashMap<Ref, bool>,
) -> Option<(Vec<Instruction<'a>>, Cow<'a, Path>)> {
    if has_scripts.get(&child.referent()) != Some(&true) {
        return None;
    }

    match child.class.as_str() {
        "Folder" => {
            let folder_path = base.join(&child.name);
            let owned: Cow<'a, Path> = Cow::Owned(folder_path);
            let clone = owned.clone();
            Some((
                vec![
                    Instruction::CreateFolder { folder: clone },
                    Instruction::CreateFile {
                        filename: Cow::Owned(owned.join("init.meta.json")),
                        contents: Cow::Owned(
                            serde_json::to_string_pretty(&MetaFile {
                                class_name: None,
                                // properties: BTreeMap::new(),
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
            let extension = match child.class.as_str() {
                "Script" => check_if_local(child),
                "LocalScript" => ".client",
                "ModuleScript" => "",
                _ => unreachable!(),
            };

            let source = match child.properties.get("Source").expect("no Source") {
                Variant::String(value) => value,
                _ => unreachable!(),
            }
            .as_bytes();

            if child.children().is_empty() {
                Some((
                    vec![Instruction::CreateFile {
                        filename: Cow::Owned(base.join(format!("{}{}.lua", child.name, extension))),
                        contents: Cow::Borrowed(source),
                    }],
                    Cow::Borrowed(base),
                ))
            } else {
                let meta_contents = Cow::Owned(
                    serde_json::to_string_pretty(&MetaFile {
                        class_name: None,
                        // properties: BTreeMap::new(),
                        ignore_unknown_instances: true,
                    })
                    .expect("couldn't serialize meta")
                    .as_bytes()
                    .into(),
                );

                let script_children_count = child
                    .children()
                    .iter()
                    .filter(|id| has_scripts.get(id) == Some(&true))
                    .count();

                let total_children_count = child.children().len();
                let folder_path: Cow<'a, Path> = Cow::Owned(base.join(&child.name));

                // If there's no script children, make a named meta file
                // If there's some script children, make a folder with a meta file
                // If there's only script children, don't bother with a meta file at all
                // TODO: Lot of redundant code here
                match script_children_count {
                    _ if script_children_count == total_children_count => Some((
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
                    )),

                    0 => Some((
                        vec![
                            Instruction::CreateFile {
                                filename: Cow::Owned(
                                    base.join(format!("{}{}.lua", child.name, extension)),
                                ),
                                contents: Cow::Borrowed(source),
                            },
                            Instruction::CreateFile {
                                filename: Cow::Owned(
                                    base.join(format!("{}.meta.json", child.name)),
                                ),
                                contents: meta_contents,
                            },
                        ],
                        Cow::Borrowed(base),
                    )),

                    _ => Some((
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
                            Instruction::CreateFile {
                                filename: Cow::Owned(folder_path.join("init.meta.json")),
                                contents: meta_contents,
                            },
                        ],
                        folder_path,
                    )),
                }
            }
        }

        other_class => {
            // When all else fails, we can make a meta folder if there's scripts in it
            match rbx_reflection::get_class_descriptor(other_class) {
                Some(reflected) => {
                    let treat_as_service = RESPECTED_SERVICES.contains(other_class);
                    // Don't represent services not in respected-services
                    if reflected.is_service() && !treat_as_service {
                        return None;
                    }

                    if treat_as_service {
                        // Don't represent empty services
                        if child.children().is_empty() {
                            return None;
                        }

                        let new_base: Cow<'a, Path> = Cow::Owned(base.join(&child.name));
                        let mut instructions = Vec::new();

                        if !NON_TREE_SERVICES.contains(other_class) {
                            instructions
                                .push(Instruction::add_to_tree(&child, new_base.to_path_buf()));
                        }

                        if !child.children().is_empty() {
                            instructions.push(Instruction::CreateFolder {
                                folder: new_base.clone(),
                            });
                        }

                        return Some((instructions, new_base));
                    }
                }

                None => {
                    debug!("class is not in reflection? {}", other_class);
                }
            }

            // If there are scripts, we'll need to make a .meta.json folder
            let folder_path: Cow<'a, Path> = Cow::Owned(base.join(&child.name));
            let meta = MetaFile {
                class_name: Some(child.class.clone()),
                // properties: properties.into_iter().collect(),
                ignore_unknown_instances: true,
            };

            Some((
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
        }
    }
}

impl<'a, I: InstructionReader + ?Sized> TreeIterator<'a, I> {
    fn visit_instructions(&mut self, instance: &Instance, has_scripts: &HashMap<Ref, bool>) {
        for child_id in instance.children() {
            let child = self.tree.get_by_ref(*child_id).expect("got fake child id?");

            let (instructions_to_create_base, path) = if child.class == "StarterPlayer" {
                // We can't respect StarterPlayer as a service, because then Rojo
                // tries to delete StarterPlayerScripts and whatnot, which is not valid.
                let folder_path: Cow<'a, Path> = Cow::Owned(self.path.join(&child.name));
                let mut instructions = Vec::new();

                if has_scripts.get(child_id) == Some(&true) {
                    instructions.push(Instruction::CreateFolder {
                        folder: folder_path.clone(),
                    });

                    instructions.push(Instruction::AddToTree {
                        name: child.name.clone(),
                        partition: TreePartition {
                            class_name: child.class.clone(),
                            children: child
                                .children()
                                .iter()
                                .filter(|id| has_scripts.get(id) == Some(&true))
                                .map(|child_id| {
                                    let child = self.tree.get_by_ref(*child_id).unwrap();
                                    (
                                        child.name.clone(),
                                        Instruction::partition(
                                            &child,
                                            folder_path.join(&child.name),
                                        ),
                                    )
                                })
                                .collect(),
                            ignore_unknown_instances: true,
                            path: None,
                        },
                    })
                }

                (instructions, folder_path)
            } else {
                match repr_instance(&self.path, child, has_scripts) {
                    Some((instructions_to_create_base, path)) => {
                        (instructions_to_create_base, path)
                    }
                    None => continue,
                }
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
    tree: &WeakDom,
    instance: &Instance,
    has_scripts: &mut HashMap<Ref, bool>,
) -> bool {
    let mut children_have_scripts = false;

    for child_id in instance.children() {
        let result = check_has_scripts(
            tree,
            tree.get_by_ref(*child_id).expect("fake child id?"),
            has_scripts,
        );

        children_have_scripts = children_have_scripts || result;
    }

    let result = match instance.class.as_str() {
        "Script" | "LocalScript" | "ModuleScript" => true,
        _ => children_have_scripts,
    };

    has_scripts.insert(instance.referent(), result);
    result
}

pub fn process_instructions(tree: &WeakDom, instruction_reader: &mut dyn InstructionReader) {
    let root = tree.root_ref();
    let root_instance = tree.get_by_ref(root).expect("fake root id?");
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
