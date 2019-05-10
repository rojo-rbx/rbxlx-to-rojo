use rbx_dom_weak::{RbxInstance, RbxTree, RbxValue};
use std::{
    borrow::Cow,
    path::{Path, PathBuf},
};
use structures::*;

mod structures;

#[cfg(test)]
mod tests;

struct TreeIterator<'a, I: InstructionReader + ?Sized> {
    instruction_reader: &'a mut I,
    path: &'a Path,
    tree: &'a RbxTree,
}

fn repr_instance<'a>(
    base: &'a Path,
    child: &'a RbxInstance,
) -> (Vec<Instruction<'a>>, Cow<'a, Path>) {
    match child.class_name.as_str() {
        "Folder" => {
            let folder_path = base.join(&child.name);
            let owned: Cow<'a, Path> = Cow::Owned(folder_path);
            let clone = owned.clone();
            (vec![Instruction::CreateFolder { folder: clone }], owned)
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
                (
                    vec![Instruction::CreateFile {
                        filename: Cow::Owned(base.join(format!("{}{}.lua", child.name, extension))),
                        contents: source,
                    }],
                    Cow::Borrowed(base),
                )
            } else {
                let folder_path: Cow<'a, Path> = Cow::Owned(base.join(&child.name));
                (
                    vec![
                        Instruction::CreateFolder {
                            folder: folder_path.clone(),
                        },
                        Instruction::CreateFile {
                            filename: Cow::Owned(base.join(format!("init{}.lua", extension))),
                            contents: source,
                        },
                    ],
                    folder_path,
                )
            }
        }

        _ => unimplemented!("non-folders/scripts are not supported"),
    }
}

impl<'a, I: InstructionReader + ?Sized> TreeIterator<'a, I> {
    fn visit_instructions(&mut self, instance: &RbxInstance) {
        for child_id in instance.get_children_ids() {
            let child = self
                .tree
                .get_instance(*child_id)
                .expect("got fake child id?");
            let (instructions_to_create_base, path) = repr_instance(&self.path, child);
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

pub fn process_instructions(tree: RbxTree, instruction_reader: &mut InstructionReader) {
    let root = tree.get_root_id();
    let root_instance = tree.get_instance(root).expect("fake root id?");
    let path = PathBuf::new();

    TreeIterator {
        instruction_reader,
        path: &path,
        tree: &tree,
    }
    .visit_instructions(&root_instance);
}

fn main() {
    println!("rbxlx-to-rojo {}", env!("CARGO_PKG_VERSION"));
}
