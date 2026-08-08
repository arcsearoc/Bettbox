import 'package:bett_box/common/yaml_util.dart';
import 'package:bett_box/enum/enum.dart';
import 'package:bett_box/models/clash_config.dart';
import 'package:bett_box/models/config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('nameserverPolicyFromJson accepts list values', () {
    final policy = nameserverPolicyFromJson({
      'geosite:cn': ['223.5.5.5', '119.29.29.29'],
      'geosite:private': 'system',
    });
    expect(policy['geosite:cn'], '223.5.5.5,119.29.29.29');
    expect(policy['geosite:private'], 'system');
  });

  test('defaultDns no longer uses leaky wildcards', () {
    const dns = defaultDns;
    expect(dns.fakeIpFilter.contains('*'), isFalse);
    expect(dns.nameserverPolicy.containsKey('*'), isFalse);
    expect(dns.respectRules, isTrue);
    expect(dns.useSystemHosts, isFalse);
    expect(dns.enhancedMode, DnsMode.fakeIp);
    expect(dns.fakeIpRange, '198.18.0.1/16');
  });

  test('default tun and overrides match anti-leak profile', () {
    const tun = defaultTun;
    expect(tun.autoRoute, isTrue);
    expect(tun.stack, TunStack.mixed);
    expect(tun.dnsHijack, ['any:53', 'tcp://any:53']);
    expect(tun.mtu, 1500);
    expect(tun.strictRoute, isFalse);

    final config = Config(themeProps: defaultThemeProps);
    expect(config.overrideDns, isTrue);
    expect(config.overrideTunnel, isTrue);
  });

  test('parseYamlMap reads dns section', () {
    final root = parseYamlMap('''
dns:
  enable: true
  enhanced-mode: fake-ip
  nameserver:
    - https://1.1.1.1/dns-query
  nameserver-policy:
    "geosite:cn":
      - 223.5.5.5
      - 119.29.29.29
''');
    final dns = Dns.safeDnsFromJson(
      Map<String, dynamic>.from(root['dns'] as Map),
    );
    expect(dns.enable, isTrue);
    expect(dns.nameserver, ['https://1.1.1.1/dns-query']);
    expect(dns.nameserverPolicy['geosite:cn'], '223.5.5.5,119.29.29.29');
  });

  test('encodeYaml round-trips simple map', () {
    final encoded = encodeYaml({
      'dns': {
        'enable': true,
        'nameserver': ['https://1.1.1.1/dns-query'],
      },
    });
    final decoded = parseYamlMap(encoded);
    expect(decoded['dns']['enable'], isTrue);
    expect(decoded['dns']['nameserver'], ['https://1.1.1.1/dns-query']);
  });
}
