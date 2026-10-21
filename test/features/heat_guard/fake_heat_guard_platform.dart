import 'package:cool_lodz/features/heat_guard/data/heat_guard_platform.dart';

/// Records calls; status and permissions are set by the test.
class FakeHeatGuardPlatform extends HeatGuardPlatform {
  FakeHeatGuardPlatform({
    this.status_ = const HeatGuardStatus(),
    this.permissions_ = const HeatGuardPermissions(
      location: true,
      backgroundLocation: true,
      notifications: true,
      sms: true,
    ),
    this.grant = true,
  });

  HeatGuardStatus status_;
  HeatGuardPermissions permissions_;

  /// What `request` answers (and whether it grants the permission).
  bool grant;
  final calls = <String>[];
  String? config;

  @override
  Stream<void> get checks => const Stream.empty();

  @override
  Future<void> configure(String json) async {
    calls.add('configure');
    config = json;
  }

  @override
  Future<void> start() async => calls.add('start');

  @override
  Future<void> stop() async => calls.add('stop');

  @override
  Future<void> test() async {
    calls.add('test');
    status_ = const HeatGuardStatus(running: true, phase: HeatGuardPhase.ask);
  }

  @override
  Future<void> answer({required bool needHelp}) async {
    calls.add(needHelp ? 'help' : 'ok');
    status_ = HeatGuardStatus(
      running: true,
      phase: needHelp ? HeatGuardPhase.full : HeatGuardPhase.idle,
    );
  }

  @override
  Future<HeatGuardStatus> status() async => status_;

  @override
  Future<bool> pendingCheck() async => false;

  @override
  Future<void> checkClosed() async => calls.add('checkClosed');

  @override
  Future<HeatGuardPermissions> permissions() async => permissions_;

  @override
  Future<bool> request(String kind) async {
    calls.add('request:$kind');
    return grant;
  }

  @override
  Future<void> openSettings(String kind) async => calls.add('settings:$kind');
}
