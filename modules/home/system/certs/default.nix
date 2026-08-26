{
  config,
  lib,

  ...
}:
let
  inherit (lib) mkEnableOption mkIf;
  inherit (lib.gregnix) mkOpt;

  cfg = config.gregnix.system.certs;
in
{
  options.gregnix.system.certs = {
    enable = mkEnableOption "pointing SSL_CERT_FILE/SSL_CERT_DIR/NIX_SSL_CERT_FILE at the OS's trust store";

    caBundlePath = mkOpt lib.types.path "/etc/ssl/certs/ca-certificates.crt" ''
      Path to the OS-provided CA bundle.
    '';
  };

  config = mkIf cfg.enable {
    home.sessionVariables = {
      SSL_CERT_FILE = cfg.caBundlePath;
      NIX_SSL_CERT_FILE = cfg.caBundlePath;
      SSL_CERT_DIR = builtins.dirOf cfg.caBundlePath;
    };
  };
}
