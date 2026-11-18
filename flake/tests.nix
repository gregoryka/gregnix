{ self, ... }:
{
  flake.tests = import ../lib/tests { inherit self; };
}
