{ config, lib, ... }:
{
  options.services.pi-hole.enable = lib.mkEnableOption "pi-hole";

  config = lib.mkIf (config.sgiath.roles.server.enable && config.services.pi-hole.enable) {
    sops.secrets.pihole-password.restartUnits = [
      "${config.virtualisation.oci-containers.backend}-pihole.service"
    ];

    networking.networkmanager.dns = lib.mkForce "none";

    services.nginx = {
      virtualHosts."dns.sgiath" = {
        rejectSSL = true;
        locations = {
          "= /".return = "301 /admin/";
          "/" = {
            proxyPass = "http://127.0.0.1:8053";
            extraConfig = ''
              allow 127.0.0.1;
              allow ::1;
              deny 192.168.1.1;
              allow 192.168.1.0/24;
              deny all;
            '';
          };
        };
      };
    };

    networking.firewall = {
      allowedTCPPorts = [ 53 ];
      allowedUDPPorts = [ 53 ];
    };

    virtualisation.oci-containers.containers.pihole = {
      image = "pihole/pihole:2026.02.0";
      ports = [
        "53:53/tcp"
        "53:53/udp"
        "127.0.0.1:8053:8053/tcp"
      ];
      volumes = [
        "/var/lib/pihole:/etc/pihole"
        "${config.sops.secrets.pihole-password.path}:/run/secrets/pihole-password:ro"
      ];
      extraOptions = [
        "--network=host"
      ]
      ++ lib.optional config.services.searx.enable "--add-host=search.sgiath.dev:192.168.1.2";
      environment = {
        TZ = "UTC";
        FTLCONF_webserver_port = "8053";
        WEBPASSWORD_FILE = "pihole-password";
      }
      // lib.optionalAttrs config.services.searx.enable {
        # Keep public AAAA and HTTPS records from routing LAN clients through Cloudflare.
        FTLCONF_misc_dnsmasq_lines = "local=/search.sgiath.dev/";
      };
    };
  };
}
