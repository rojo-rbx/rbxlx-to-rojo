use std::{borrow::Cow, path::Path};

#[derive(Clone, Debug)]
pub enum Instruction<'a> {
    CreateFile {
        filename: Cow<'a, Path>,
        contents: Cow<'a, [u8]>,
    },

    CreateFolder {
        folder: Cow<'a, Path>,
    },
}

pub trait InstructionReader {
    fn read_instruction<'a>(&mut self, instruction: Instruction<'a>);
    fn read_instructions<'a>(&mut self, instructions: Vec<Instruction<'a>>) {
        for instruction in instructions {
            self.read_instruction(instruction);
        }
    }
}
