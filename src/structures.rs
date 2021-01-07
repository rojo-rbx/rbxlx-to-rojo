use rbx_dom_weak::Instance;
use serde::{Deserialize, Serialize, Serializer};
use std::{
    borrow::Cow,
    collections::BTreeMap,
    path::{Path, PathBuf},
};

// Windows issues!
fn replace_backslashes<S: Serializer>(
    path: &Option<PathBuf>,
    serializer: S,
) -> Result<S::Ok, S::Error> {
    match path {
        Some(value) => value
            .to_string_lossy()
            .replace("\\", "/")
            .serialize(serializer),

        None => serializer.serialize_none(),
    }
}

#[derive(Clone, Debug, Deserialize, Serialize, PartialEq)]
pub struct TreePartition {
    #[serde(rename = "$className")]
    pub class_name: String,

    #[serde(flatten)]
    #[serde(skip_serializing_if = "BTreeMap::is_empty")]
    pub children: BTreeMap<String, TreePartition>,

    #[serde(rename = "$ignoreUnknownInstances")]
    pub ignore_unknown_instances: bool,

    #[serde(rename = "$path")]
    #[serde(skip_serializing_if = "Option::is_none")]
    #[serde(serialize_with = "replace_backslashes")]
    pub path: Option<PathBuf>,
    // #[serde(rename = "$properties")]
    // #[serde(skip_serializing_if = "BTreeMap::is_empty")]
    // pub properties: BTreeMap<String, RbxValue>,
}

#[derive(Clone, Debug, Deserialize, Serialize, PartialEq)]
pub(crate) struct MetaFile {
    #[serde(rename = "className")]
    #[serde(skip_serializing_if = "Option::is_none")]
    pub class_name: Option<String>,

    // #[serde(rename = "properties")]
    // #[serde(skip_serializing_if = "BTreeMap::is_empty")]
    // pub properties: BTreeMap<String, RbxValue>,
    #[serde(rename = "ignoreUnknownInstances")]
    pub ignore_unknown_instances: bool,
}

#[derive(Clone, Debug)]
pub enum Instruction<'a> {
    AddToTree {
        name: String,
        partition: TreePartition,
    },

    CreateFile {
        filename: Cow<'a, Path>,
        contents: Cow<'a, [u8]>,
    },

    CreateFolder {
        folder: Cow<'a, Path>,
    },
}

impl<'a> Instruction<'a> {
    pub fn add_to_tree(instance: &Instance, path: PathBuf) -> Self {
        Instruction::AddToTree {
            name: instance.name.clone(),
            partition: Instruction::partition(&instance, path),
        }
    }

    pub fn partition(instance: &Instance, path: PathBuf) -> TreePartition {
        TreePartition {
            class_name: instance.class.clone(),
            children: BTreeMap::new(),
            ignore_unknown_instances: true,
            path: Some(path),
        }
    }
}

pub trait InstructionReader {
    fn finish_instructions(&mut self) {}
    fn read_instruction<'a>(&mut self, instruction: Instruction<'a>);

    fn read_instructions<'a>(&mut self, instructions: Vec<Instruction<'a>>) {
        for instruction in instructions {
            self.read_instruction(instruction);
        }
    }
}
