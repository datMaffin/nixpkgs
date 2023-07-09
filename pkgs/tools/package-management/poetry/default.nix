{ lib
, python3
, fetchFromGitHub
}:

let
  python = python3.override {
    packageOverrides = self: super: {
      poetry = self.callPackage ./unwrapped.nix { };

      # version overrides required by poetry and its plugins
      cachecontrol = super.cachecontrol.overridePythonAttrs (old: rec {
        version = "0.12.14";
        format = "setuptools";
        src = fetchFromGitHub {
          owner = "ionrock";
          repo = "cachecontrol";
          rev = "v${version}";
          hash = "sha256-BuBaKP7OAYoT+SPVhtE6l9U/KmN21OKTL6poV5a6+0c=";
        };
        nativeCheckInputs = old.nativeCheckInputs ++ [
          self.lockfile
        ];
      });
      platformdirs = super.platformdirs.overridePythonAttrs (old: rec {
        version = "2.6.2";
        src = fetchFromGitHub {
          owner = "platformdirs";
          repo = "platformdirs";
          rev = "refs/tags/${version}";
          hash = "sha256-yGpDAwn8Kt6vF2K2zbAs8+fowhYQmvsm/87WJofuhME=";
        };
        SETUPTOOLS_SCM_PRETEND_VERSION = version;
      });
      poetry-core = super.poetry-core.overridePythonAttrs (old: rec {
        version = "1.5.2";
        src = fetchFromGitHub {
          owner = "python-poetry";
          repo = "poetry-core";
          rev = version;
          hash = "sha256-GpZ0vMByHTu5kl7KrrFFK2aZMmkNO7xOEc8NI2H9k34=";
        };
      });
    } // (plugins self);
  };

  plugins = ps: with ps; {
    poetry-audit-plugin = callPackage ./plugins/poetry-audit-plugin.nix { };
    poetry-plugin-export = callPackage ./plugins/poetry-plugin-export.nix { };
    poetry-plugin-up = callPackage ./plugins/poetry-plugin-up.nix { };
  };

  # selector is a function mapping pythonPackages to a list of plugins
  # e.g. poetry.withPlugins (ps: with ps; [ poetry-plugin-up ])
  withPlugins = selector: let
    selected = selector (plugins python.pkgs);
  in python.pkgs.toPythonApplication (python.pkgs.poetry.overridePythonAttrs (old: {
    propagatedBuildInputs = old.propagatedBuildInputs ++ selected;

    # save some build time when adding plugins by disabling tests
    doCheck = selected == [ ];

    # Propagating dependencies leaks them through $PYTHONPATH which causes issues
    # when used in nix-shell.
    postFixup = ''
      rm $out/nix-support/propagated-build-inputs
    '';

    passthru = {
      plugins = plugins python.pkgs;
      inherit withPlugins python;
    };
  }));
in withPlugins (ps: [ ])
