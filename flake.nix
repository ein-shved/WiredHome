{
  description = "The template project for stm32 with logging to uart";
  inputs = {
    stm32.url = github:ein-shved/nix-stm32;
  };
  outputs = { self, stm32, ... } :
  stm32.mkFirmware {
    mcu = stm32.mcus.stm32f103;
    name = "stm32-uart-log";
    src = ./.;
  };
}
