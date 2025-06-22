# Nix Flake for Motor Town Server

This flake is for running a dedicated "Motor Town: Behind the Wheel" dedicated server.

Include `nixosModules.default` as a module in your NixOS configuration.

```nix
{
  ### in configuration.nix
  services.motortown-server = {
    enable = true;
    user = "steam";
    steamuser = "your steam username";
    steampassword = "your steam password";
    dedicatedServerConfig = {
      # see motortown-server.nix for full description
    };
  };
}
```

