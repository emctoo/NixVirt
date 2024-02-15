{
  description = "LibVirt domain management";

  inputs =
    {
      nixpkgs =
        {
          type = "github";
          owner = "shlevy";
          repo = "nixpkgs";
          ref = "ovmf-ms";
        };
    };

  outputs = { self, nixpkgs }:
    let
      pkgs = import nixpkgs { system = "x86_64-linux"; };

      nixvirtPythonModulePackage = pkgs.runCommand "nixvirtPythonModulePackage" { }
        ''
          mkdir  -p $out/lib/python3.11/site-packages/
          ln -s ${tool/nixvirt.py} $out/lib/python3.11/site-packages/nixvirt.py
        '' // { pythonModule = pkgs.python311; };

      pythonInterpreterPackage = pkgs.python311.withPackages (ps:
        [
          ps.libvirt
          ps.lxml
          nixvirtPythonModulePackage
        ]);

      setShebang = name: path: pkgs.runCommand name { }
        ''
          sed -e "1s|.*|\#\!${pythonInterpreterPackage}/bin/python3|" ${path} > $out
          chmod 755 $out
        '';

      virtdeclareFile = setShebang "virtdeclare" tool/virtdeclare;
      virtpurgeFile = setShebang "virtpurge" tool/virtpurge;

      mklib = import ./lib.nix;

      modules = (import ./modules.nix) { inherit virtdeclareFile virtpurgeFile; };
    in
    {
      lib = mklib pkgs;

      apps.x86_64-linux.virtdeclare =
        {
          type = "app";
          program = "${virtdeclareFile}";
        };

      apps.x86_64-linux.virtpurge =
        {
          type = "app";
          program = "${virtpurgeFile}";
        };

      formatter.x86_64-linux = pkgs.nixpkgs-fmt;

      packages.x86_64-linux.default = pkgs.runCommand "NixVirt" { }
        ''
          mkdir -p $out/bin
          ln -s ${virtdeclareFile} $out/bin/virtdeclare
          ln -s ${virtpurgeFile} $out/bin/virtpurge
        '';

      homeModules.default = modules.homeModule;

      nixosModules.default = modules.nixosModule;

      checks.x86_64-linux = (import checks/checks.nix) pkgs mklib;
    };
}
