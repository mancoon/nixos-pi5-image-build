# Edit this configuration file to define what should be installed on
# your system. Help is always available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual ('nixos-help').

  { config, lib, pkgs, ... }:

  {
    imports =
      [  # include the results of the hardware scan.
         ./hardware-configuration.nix
      ];

    # Use the system-boot EFI boot loader.
    boot.loader.systemd-boot.enable = true;
    boot.loader.efi.canTouchEfiVariables = false;
    boot.kernelPackages = pkgs.linuxPackages_rpi4;

    # Install vim for real, along with git
    environment.systemPackages = with pkgs; [
      git
      vim
    ];

     networking.hostName = "nixos"; # Define your hostname.
    # Pick only one of the below networking options.
    # networking.wireless.enable = true; #Enables wireless support via wpa_supplicant.
      networking.networkmanager.enable = true; # Easiest to use and most distros use this by default.

    # Set your time zone.
    # time.timeZone = "Europe/Amsterdam";

    # Configure network proxy if necessary
    # network.proxy.default = "https://user:password@proxy:port/"
    # network.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

    # Select internationalisation properties.
    # i18n.defaultLocal = "en_US.UTF-8";
    # console = {
    #   font = "Lat2-Terminus16";
    #   keyMap = "us";
    #   useXkbConfig = true; # use xkb.options in tyy.

    # Enable the X11 windowing system.
    services.xserver.enable = true;

    # Enable flakes and the nix cli
    nix.settings.experimental-features = [ "nix-command" "flakes" ];

    # Enable the GNOME Desktop Enviroment.
    services.xserver.displayManager.gdm.enable = true;
    services.xserver.desktopManager.gnome.enable = true;
    # services.xserver.xkb.layout = "us";
    # services.xserver.xkb.options = "eurosign:e,caps:escape";

    # Enable CUPS to print documents.
    # services.printing.enable = true;

    # Enable sound.
    # services.pulseaudio.enable = true;
    # OR
    # services.pipewire = {
    #   enable = true;
    #   pulse.enable = true;
    # };

    # Enable touchpad support (enable default in most desktopManger).
    # services.libinput.enable = true;

    # Define a user account. Don't forget to set a password with 'passwd'.
    # users.users.alice = {
    #   isNormaluser = true;
    #   extraGroups = [ "wheel" ]; # Enable 'sudo' for the user.
    #   packages = with pkgs; [
    #     tree
    #   ];
    # };

     programs.firefox.enable = true;

    # List for services that you might want to enable:

    # Enable OpenSHH daemon.
    services.openssh = {
      enable = true;
      permitRootLogin = "yes";
      passwordAuthentication = true;
    };

    # Open ports in the firewall.
    # networking.firewall.allowedTCPPorts = [ ... ];
    # networking.firewall.allowedUDPPorts = [ ... ];
    # Or disable the firewall altogether.
    networking.firewall.enable = false;

    # Copy the NixOS configuration file and link it from the resulting system
    # (/run/current-system/configuration.nix). This is useful in case you 
    # accidentially delete the configuration.nix.
    system.copySystemConfiguration = true;

    # This option defines the first version of NixOS you have installed on this particular machine,
    # and is used to maintain compatibility with applications data (e.g databases) created on older Nixos versions.
    #
    # Most users should NEVER change this value after initial install, for any reason,
    # even if you've upgraded your system to a new NixOS release.
    #
    # This value does NOT affect the Nixpkgs version your packages and OS are pulled from,
    # so changing it will NOT upgrade your system - see https://nixos.org/manual/mixos/stable/#sec-upgrading for how 
    # to actually do that.
    #
    # This value being lower than the current NixOS does NOT mean your system is
    # out of date, out of support, or vulnerable.
    #
    # Do NOT change this value unless you have manually inspected all the changes it would make yo your configuration,
    # and migrated your data accordingly.
    # 
    # For more information, see 'man configuration.nix' or https://nixos.org/manual/nixos/stable/option#opt-system.stateVerions .
    system.stateVersion = "25.05"; # Did you read the comment?
}
