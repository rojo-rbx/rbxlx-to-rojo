# rbxlx-to-rojo (now supports .rbxl!)
Tool to convert existing Roblox games into Rojo projects by reading their `rbxl` or `rbxlx` place files.

# Using rbxlx-to-rojo
## Setup
Before you can use rbxlx-to-rojo, you need the following:

- At least Rojo 0.5.0 Alpha 12 or higher to use the tool.
- A rbxlx place file that at least has scripts

If there aren't any scripts in the rbxlx file, rbxlx-to-rojo will return an error.

Download the latest release of rbxlx-to-rojo here: https://github.com/rojo-rbx/rbxlx-to-rojo/releases
## Porting the game
Although not required, check to see whether or not any instance names contain any of the following characters: `\/:*?"<>|`. This will result in generation halt on Windows because of file naming requirements. For any other OS, just be sure to check those specific file naming requirements before atempting to port your game.

Before you can port your game into Rojo projects, you need a place/model file. If you have an existing game that isn't exported:

- Go to studio, click on any place, and then click on File -> Save to file as.

- Create a folder and name it whatever you want.
### Steps to port the game:
1. Double-click on rbxlx-to-rojo on wherever you installed it.
2. Select the .rbxl file you saved earlier.
3. Now, select the folder that you just created.

If you followed the steps correctly, you should see something that looks like this:
![](assets/folders.png)

Congratulations, you successfully ported an existing game using rbxlx-to-rojo!

## License
rbxlx-to-rojo is available under The Mozilla Public License, Version 2. Details are available in [LICENSE.md](LICENSE.md).
