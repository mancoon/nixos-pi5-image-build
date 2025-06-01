{ config, pkgs, lib, ... }:

{
  # Don’t import any hardware‐configuration.nix; let the installer generate it
  imports = [ ];

  # Enable flakes (if you want; not strictly needed for manual build)
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # System packages (include cloud-utils so we can auto-grow the root partition)
  environment.systemPackages = with pkgs; [
    vim
    git
    cloud-utils
  ];

  # Desktop configuration (enable GNOME)
  services.xserver.enable                    = true;
  services.xserver.displayManager.gdm.enable = true;
  services.xserver.desktopManager.gnome.enable = true;

  # Automatically expand root partition on first boot
  systemd.services.expand-root-once = {
    description = "Grow rootfs to fill entire SD-card on first boot";
    after    = [ "local-fs.target" "systemd-fsck@dev-mmcblk0p2.service" ];
    wants    = [ "systemd-fsck@dev-mmcblk0p2.service" ];
    # Top-level wantedBy, not under install
    wantedBy = [ "multi-user.target" ];

    serviceConfig.Type  = "oneshot";
    serviceConfig.ExecStart = ''
      #!/bin/sh
      if [ "$(lsblk -nblo SIZE /dev/mmcblk0p2)" -lt "$(lsblk -nblo SIZE /dev/mmcblk0)" ]; then
        /usr/bin/growpart /dev/mmcblk0 2
        /usr/bin/resize2fs /dev/mmcblk0p2
      fi
    '';
    serviceConfig.RemainAfterExit   = true;
    serviceConfig.ExecStartPost = "/usr/bin/systemctl disable expand-root-once";
  };

  # Match your installed release
  system.stateVersion = "25.05";
}
