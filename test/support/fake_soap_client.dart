import 'package:personal_sonos/src/services/soap_client.dart';
import 'package:xml/xml.dart';

typedef SoapCall = ({
  String host,
  SonosService service,
  String action,
  Map<String, String> args,
});

/// Builds a response element whose `.arg(name)` finds direct children.
XmlElement soapResponse(String innerXml) =>
    XmlDocument.parse('<Response>$innerXml</Response>').rootElement;

/// A [SoapClient] that records calls and returns canned responses instead of
/// hitting the network.
class FakeSoapClient extends SoapClient {
  FakeSoapClient([this._responder]);

  final XmlElement Function(String action)? _responder;
  final List<SoapCall> calls = [];

  SoapCall get lastCall => calls.last;

  @override
  Future<XmlElement> invoke(
    String host,
    SonosService service,
    String action, {
    Map<String, String> arguments = const {},
  }) async {
    calls.add((host: host, service: service, action: action, args: arguments));
    return _responder?.call(action) ?? soapResponse('');
  }
}
