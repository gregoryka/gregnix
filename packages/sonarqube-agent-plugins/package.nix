{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
  jq,
  ...
}:
let
  version = "2.7.0";

  # The rest need SCA (`sonar-*dependency-risks`) or would run
  # `sonar integrate` and unpinned installers over the Nix-managed setup
  # (`sonar-integrate`). Hardcoded, so consumers don't need
  # import-from-derivation to list them.
  skillNames = [
    "sonar-analyze"
    "sonar-coverage"
    "sonar-duplication"
    "sonar-fix-issue"
    "sonar-list-issues"
    "sonar-list-projects"
    "sonar-quality-gate"
  ];

  agentNames = [ "sonarqube-reviewer" ];

  # Devin subagents get no `skill` tool (even with no `tools:` restriction)
  # and drop the Claude tool names it can't map (`Bash(...)`, `Skill`), so
  # Devin's copy follows the skill files itself.
  devinReviewerNote = ''
    # SonarQube Reviewer

    > **Running in Devin:** subagents can't invoke skills here. Wherever this
    > prompt says to invoke a `sonar-*` skill, read
    > `@out@/share/sonarqube-agent-plugins/skills/<skill>/SKILL.md` and follow
    > it yourself, running its `sonar` and `git` commands with `exec`. Report a
    > skill whose file doesn't exist there as unavailable.
  '';
in
stdenvNoCC.mkDerivation {
  pname = "sonarqube-agent-plugins";
  inherit version;

  # Tags aren't signed by SonarSource, so pin the tag's commit.
  src = fetchFromGitHub {
    owner = "SonarSource";
    repo = "sonarqube-agent-plugins";
    rev = "90e404c12e636c6fb7d1843fd24f70cee5db4795";
    hash = "sha256-xSDi+PFMLROZk0B5bha6nRTX0LuTU24kmS0Qh9XGO4I=";
  };

  nativeBuildInputs = [ jq ];

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    manifestVersion="$(jq -r .version plugin.json)"
    if [ "$manifestVersion" != "$version" ]; then
      echo "sonarqube-agent-plugins: src is $manifestVersion, expected $version" >&2
      exit 1
    fi

    for skill in ${lib.escapeShellArgs skillNames}; do
      install -Dm644 "skills/$skill/SKILL.md" "$out/share/sonarqube-agent-plugins/skills/$skill/SKILL.md"
    done
    for agent in ${lib.escapeShellArgs agentNames}; do
      install -Dm644 "agents/$agent.agent.md" "$out/share/sonarqube-agent-plugins/agents/$agent.md"
    done

    devinReviewer="$out/share/sonarqube-agent-plugins/devin/agents/sonarqube-reviewer.md"
    install -Dm644 agents/sonarqube-reviewer.agent.md "$devinReviewer"
    substituteInPlace "$devinReviewer" \
      --replace-fail \
        'tools: Read, Grep, Glob, Bash(git diff:*), Bash(git status:*), Bash(git branch:*), Bash(git symbolic-ref:*), Bash(sonar:*), mcp__sonarqube__*, Skill' \
        'tools: read, grep, glob, exec' \
      --replace-fail '# SonarQube Reviewer
    ' ${lib.escapeShellArg devinReviewerNote} \
      --subst-var out

    runHook postInstall
  '';

  passthru = { inherit skillNames agentNames; };

  meta = {
    description = "Selected skills and the reviewer subagent from SonarSource's SonarQube agent plugins";
    homepage = "https://github.com/SonarSource/sonarqube-agent-plugins";
    # SONAR Source-Available License v1.0.
    license = lib.licenses.unfree;
    platforms = lib.platforms.all;
  };
}
