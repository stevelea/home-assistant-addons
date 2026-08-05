{
  description = "Home Assistant Add-on Development Environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in
      {
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            # Container tools
            podman
            podman-compose
            
            # Home Assistant development tools
            hadolint  # Dockerfile linter
            curl      # For testing endpoints
            jq        # JSON processing
            
            # Build and validation tools
            git
            bash
            
            # Optional: useful for debugging
            yq-go     # YAML processing
          ];

          shellHook = ''
            echo "🏠 Home Assistant Add-on Development Environment"
            echo "Available commands:"
            echo "  build-codewhale - Build the Codewhale Terminal add-on"
            echo "  run-codewhale   - Run the Codewhale Terminal add-on locally"
            echo "  lint-codewhale-dockerfile - Lint the Dockerfile"
            echo ""
            echo "To get started: build-codewhale"
            
            # Create convenience aliases
            alias build-codewhale='podman build --build-arg BUILD_FROM=ubuntu:24.04 -t local/codewhale-terminal ./codewhale-terminal'
            alias run-codewhale='podman run -p 7681:7681 -v $(pwd)/config:/config local/codewhale-terminal'
            alias lint-codewhale-dockerfile='hadolint ./codewhale-terminal/Dockerfile'
          '';
        };
      });
}