{ pkgs, ... }:
let
  pass = pkgs.pass.withExtensions (exts: [ exts.pass-otp ]);

  awsSecrets = pkgs.writeShellScriptBin "aws-secrets" ''
    mfa="arn:aws:iam::173509387151:mfa/filip"
    token=$(${pass}/bin/pass otp 2fa/amazon/code)

    ${pkgs.awscli}/bin/aws sts get-session-token --profile crazyegg --serial-number $mfa --token-code $token | \
      ${pkgs.jq}/bin/jq -r '.Credentials' | \
      ${pkgs.jq}/bin/jq '. += {"Version": 1}'
    '';
in
{
  home.packages = with pkgs; [
    amazon-ecr-credential-helper
    slack
    google-chrome
  ];

  programs.jq.enable = true;
  programs.awscli = {
    enable = true;
    settings."default" = {
      region = "us-east-1";
      output = "json";
    };
    credentials = {
      "default"."credential_process" = "${awsSecrets}/bin/aws-secrets";
      "crazyegg"."credential_process" = "${pass}/bin/pass show aws/crazyegg";
    };
  };
  home.file.".docker/config.json".text = ''
    {
      "credHelpers": {
        "public.ecr.aws": "ecr-login",
        "173509387151.dkr.ecr.us-east-1.amazonaws.com": "ecr-login",
        "173509387151.dkr.ecr.us-west-2.amazonaws.com": "ecr-login"
      }
    }
  '';
}
