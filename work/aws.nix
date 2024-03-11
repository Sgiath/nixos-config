{ config, pkgs, ... }:

{
  home.packages = with pkgs; [
    (writeShellScriptBin "aws-secrets" ''
      token=$(pass otp 2fa/amazon/code)
      aws sts get-session-token --profile crazyegg --serial-number "arn:aws:iam::173509387151:mfa/filip" --token-code $token | jq -r '.Credentials' | jq '. += {"Version": 1}'
    '')
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
      "default"."credential_process" = "aws-secrets";
      "crazyegg"."credential_process" = "${pkgs.pass}/bin/pass show aws/crazyegg";
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
