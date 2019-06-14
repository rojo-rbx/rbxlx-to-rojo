use rbx_dom_weak::{RbxInstance, RbxValue};
use serde::{Deserialize, Serialize};
use std::{
    borrow::Cow,
    collections::BTreeMap,
    path::Path,
};

#[derive(Clone, Debug, Deserialize, Serialize, PartialEq)]
pub struct TreePartition {
    #[serde(rename = "$className")]
    class_name: String,
    #[serde(rename = "$path")]
    path: String,
    #[serde(rename = "$properties")]
    properties: BTreeMap<String, RbxValue>,
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
    pub fn add_to_tree(instance: RbxInstance, path: String) -> Self {
        Instruction::AddToTree {
            name: instance.name.clone(),
            partition: TreePartition {
                class_name: instance.class_name.clone(),
                path,
                properties: instance.properties.clone().into_iter().collect(),
            },
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
