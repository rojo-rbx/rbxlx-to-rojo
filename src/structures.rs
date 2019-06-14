use rbx_dom_weak::{RbxInstance, RbxValue};
use serde::{Deserialize, Serialize};
use std::{
    borrow::Cow,
    collections::BTreeMap,
    path::{Path, PathBuf},
};

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
    pub path: Option<PathBuf>,

    // #[serde(rename = "$properties")]
    // #[serde(skip_serializing_if = "BTreeMap::is_empty")]
    // pub properties: BTreeMap<String, RbxValue>,
}

#[derive(Clone, Debug, Deserialize, Serialize, PartialEq)]
pub struct MetaFile {
    #[serde(rename = "className")]
    #[serde(skip_serializing_if = "Option::is_none")]
    pub class_name: Option<String>,

    #[serde(rename = "properties")]
    #[serde(skip_serializing_if = "BTreeMap::is_empty")]
    pub properties: BTreeMap<String, RbxValue>,

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
    pub fn add_to_tree(instance: RbxInstance, path: PathBuf) -> Self {
        Instruction::AddToTree {
            name: instance.name.clone(),
            partition: Instruction::partition(&instance, path),
        }
    }

    pub fn partition(instance: &RbxInstance, path: PathBuf) -> TreePartition {
        TreePartition {
            class_name: instance.class_name.clone(),
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
