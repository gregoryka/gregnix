{
  config,
  lib,
  pkgs,
  hostname,

  ...
}:
let
  inherit (lib) getFile;

  cfg = config.gregnix.archetypes.work;

  awsSecretsFile = getFile "secrets/work/aws.yaml";
  artifactorySecretsFile = getFile "secrets/work/${hostname}/artifactory.yaml";
  artifactorySharedSecretsFile = getFile "secrets/work/artifactory.yaml";
  gitSecretsFile = getFile "secrets/work/git.yaml";
  userSecretsFile = getFile "secrets/work/user.yaml";
  qodoSecretsFile = getFile "secrets/work/qodo.yaml";
  sonarqubeSecretsFile = getFile "secrets/work/sonarqube.yaml";
  jenkinsSecretsFile = getFile "secrets/work/jenkins.yaml";

  githubSigningKey = "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBBdm9VQQSYhCdagTzOpOwtHZXzrz24vhelbi9IUbmJ3qc/OjwdEysOm0+O5xjwPdselTgTb5jAudlyfaay4TIvo=";
  githubEmail = "247164767+gregory-kanter-s1@users.noreply.github.com";

  gheSigningKey = "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBCDj6syYjOR2dZ6kSDr41O2G3+A3cmLFD6bKtw0y5r2bJHtPcle7PodSWI0wYdn0BPHD/7Lrn3qthIhpr6hBCPA=";

  gheHostKeys = [
    "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDC44/umo/e4zVNN6KUME09x5UeIGA8QK9rMHm8Bs131x31Fl4MKoxdPlPM1FullXajFAZ7Lr8uIIOaQzDb50IyCxr0gZk2MKOy8d3+BSH1zblO5yINWhxgf7bwZkQGVG6XYL9FXKqW2AYSmf090bl1eCrnqXAd3hJq8kioajJ0i1w9ZrLjjQH6Xb7uRwVwm35NJlIR6N3u+hkZjUQcNPN5mTTfJmwlJQoUz6DCZMjdb1dMUb7btMZqYaupuQhNKxjaaTYT6ncEYp/MXNy5Oxm4IyFLMAG8R3pSf6FT2cR3MM3akcixmnJt82eMWO67gQt4EDnHYq3gQHPGuMfwK04N"
    "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBAytejJjiD7Th+lOoV6W7NzOBLlL7UKv3qAp06FsEahan5k2+JUi/bxtCdVgww2+fCaPDlnK1XcAOEI0C5/yjpw="
  ];

  githubHostKeys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl"
    "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBEmKSENjQEezOmxkZMy7opKgwFB9nkt5YRrYMjNuG5N87uRgg6CLrbo5wAdT/y6v0mKV0U2w0WZ2YB/++Tpockg="
    "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCj7ndNxQowgcQnjshcLrqPEiiphnt+VTTvDP6mHBL9j1aNUkY4Ue1gvwnGLVlOhGeYrnZaMgRK6+PKCUXaDbC7qtbW8gIkhL7aGCsOr/C56SJMy/BCZfxd1nWzAOxSDPgVsmerOBYfNqltV9/hWCqBywINIR+5dIg6JTJ72pcEpEjcYgXkE2YEFXV1JHnsKgbLWNlhScqb2UmyRkQyytRLtL+38TGxkxCflmO+5Z8CSSNY7GidjMIZ7Q4zMjA2n1nGrlTDkzwDCsw+wqFPGQA179cnfGWOWRVruj16z6XyvxvjJwbz0wQZ75XK5tKSb7FNyeIEs4TT4jk+S4dhPeAUC5y+bDYirYgM4GC7uEnztnZyaVWQ7B381AK4Qdrwt51ZqExKbQpTUNn+EjqoTwvqNj4kqx5QUCI0ThS/YkOxJCXmPUWZbhjpCg56i+2aB6CmK2JGhn57K5mj0MNdBXA4/WnwH6XoPWJzK5Nyu2zB3nAZp+S5hpQs+p1vN1/wsjk="
  ];
in
{
  options.gregnix.archetypes.work = {
    enable = lib.mkEnableOption "the work archetype";
  };

  config = lib.mkIf cfg.enable {
    gregnix.programs.terminal.tools.awscli = {
      enable = true;
      settings = {
        default = {
          region = "us-east-1";
          output = "json";
          sso_session = "S1 dev";
          sso_account_id = config.sops.placeholder.sso_account_id;
          sso_role_name = config.sops.placeholder.sso_role_name;
        };
        "sso-session 'S1 dev'" = {
          sso_region = "us-east-1";
          sso_registration_scopes = "sso:account:access";
          sso_start_url = config.sops.placeholder.sso_start_url;
        };
      };
    };

    gregnix.programs.terminal.tools.git.identities = {
      github = {
        remotes = [ "github.com" ];
        email = githubEmail;
        signingKey = githubSigningKey;
      };
      ghe = {
        remotes = [ config.sops.placeholder.ghe_domain ];
        email = config.sops.placeholder.email;
        signingKey = gheSigningKey;
      };
    };

    gregnix.programs.terminal.tools.ssh.hosts = {
      ghe = {
        hostPattern = config.sops.placeholder.ghe_domain;
        hostKeys = gheHostKeys;
      };
      "github.com".hostKeys = githubHostKeys;
    };

    gregnix.programs.terminal.tools.npm = {
      enable = true;
      hostPath = config.sops.placeholder.artifactory_npm_registry;
    };

    gregnix.programs.terminal.tools.qodo = {
      enable = true;
      sdkUrlSopsFile = qodoSecretsFile;
    };

    gregnix.programs.terminal.tools.sonarqube = {
      enable = true;
      serverUrlSopsFile = sonarqubeSecretsFile;
      gitHookIdentities = [ "ghe" ];
    };

    gregnix.programs.terminal.tools.jk = {
      enable = true;
      activeContext = "work";
      contexts.work = {
        url = config.sops.placeholder.jenkins_url;
        username = "gregory.kanter";
      };
    };

    gregnix.programs.terminal.tools.gh.enable = true;
    gregnix.programs.terminal.tools.claude-code.enable = true;
    gregnix.programs.terminal.tools.devin.enable = true;

    programs.git.settings.gpg.ssh.program =
      "${pkgs.gregnix.git-ssh-keygen-secretive}/bin/git-ssh-keygen-secretive";

    sops.secrets = {
      sso_account_id.sopsFile = awsSecretsFile;
      sso_start_url.sopsFile = awsSecretsFile;
      sso_role_name.sopsFile = awsSecretsFile;
      artifactory_token = {
        sopsFile = artifactorySecretsFile;
        # Pinned to a fixed, known path so devShells can read it directly.
        path = "${config.home.homeDirectory}/.local/state/sops-nix/artifactory_token";
      };
      artifactory_npm_registry.sopsFile = artifactorySharedSecretsFile;
      ghe_domain.sopsFile = gitSecretsFile;
      jenkins_url.sopsFile = jenkinsSecretsFile;
      email.sopsFile = userSecretsFile;
    };
  };
}
