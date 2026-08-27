{
  writeShellApplication,
  openssh,
  stdenv,
  ...
}:
let
  # `ssh-keygen -Y sign` (what git shells out to for ssh-format commit
  # signing) ignores ssh_config's `IdentityAgent` entirely -- it only reads
  # `SSH_AUTH_SOCK`. This wraps it to point at the Secretive
  # (macOS Secure Enclave) agent socket without setting SSH_AUTH_SOCK
  # globally, which would also affect regular ssh/agent usage.
  #
  # On the Mac that's the real Secretive socket; on dev-vm it's the copy of
  # that socket forwarded over from the Mac via `RemoteForward`.
  secretiveSocket = "$HOME/Library/Containers/com.maxgoedjen.Secretive.SecretAgent/Data/socket.ssh";
  secretiveForwardedSocket = "/run/user/1000/secretive.ssh";
  socket = if stdenv.hostPlatform.isDarwin then secretiveSocket else secretiveForwardedSocket;
in
writeShellApplication {
  name = "git-ssh-keygen-secretive";
  runtimeInputs = [ openssh ];
  text = ''
    export SSH_AUTH_SOCK="${socket}"
    exec ssh-keygen "$@"
  '';

  passthru = { inherit secretiveForwardedSocket; };

  meta = {
    description = "ssh-keygen wrapper pointed at the Secretive agent socket, for git ssh-format commit signing";
    mainProgram = "git-ssh-keygen-secretive";
  };
}
