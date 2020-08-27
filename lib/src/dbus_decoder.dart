import 'dart:convert';
import 'dart:typed_data';

import 'dbus_buffer.dart';
import 'dbus_message.dart';
import 'dbus_value.dart';

/// Decodes DBus messages from binary data.
class DBusDecoder extends DBusBuffer {
  /// Stream of messages received.
  final messages = StreamController<DBusMessage>();

  /// Unused data
  var _buffer = <int>[];

  /// True when have received authorization messages.
  var _authorized = false;

  /// Creates a new reader using [stream].
  DBusDecoder(Stream<Uint8List> stream) {
    // FIXME(robert-ancell): handle onError, onDone.
    stream.listen(_onData);
  }

  /// Process received data.
  void _onData(UintList data) {
    _buffer.addAll(data);


  }

  /// Read a single byte from the buffer.
  int readByte() {
    readOffset++;
    return _buffer[readOffset - 1];
  }

  /// Reads [length] bytes from the buffer.
  Future<ByteBuffer> readBytes(int length) async {
    var bytes = Uint8List(length);
    for (var i = 0; i < length; i++) {
      bytes[i] = readByte();
    }
    return bytes.buffer;
  }

  /// Reads a single line of UTF-8 text (terminated with CR LF) from the buffer.
  Future<String> readLine() async {
    for (var i = readOffset; i < data.length - 1; i++) {
      if (_buffer[i] == 13 /* '\r' */ && _buffer[i + 1] == 10 /* '\n' */) {
        var bytes = List<int>(i - readOffset);
        for (var j = readOffset; j < i; j++) {
          bytes[j] = readByte();
        }
        readOffset = i + 2;
        return utf8.decode(bytes);
      }
    }
    return null;
  }

  /// Reads a D-Bus message from the buffer or returns null if not enough data.
  DBusMessage readMessage() {
    if (remaining < 12) {
      return null;
    }

    readDBusByte(); // Endianess.
    var type = readDBusByte().value;
    var flags = readDBusByte().value;
    readDBusByte(); // Protocol version.
    var dataLength = readDBusUint32();
    var serial = readDBusUint32().value;
    var headers = readDBusArray(DBusSignature('(yv)'));
    if (headers == null) {
      return null;
    }

    DBusSignature signature;
    DBusObjectPath path;
    String interface;
    String member;
    String errorName;
    int replySerial;
    String destination;
    String sender;
    for (var child in headers.children) {
      var header = child as DBusStruct;
      var code = (header.children.elementAt(0) as DBusByte).value;
      var value = (header.children.elementAt(1) as DBusVariant).value;
      if (code == HeaderCode.Path) {
        path = value as DBusObjectPath;
      } else if (code == HeaderCode.Interface) {
        interface = (value as DBusString).value;
      } else if (code == HeaderCode.Member) {
        member = (value as DBusString).value;
      } else if (code == HeaderCode.ErrorName) {
        errorName = (value as DBusString).value;
      } else if (code == HeaderCode.ReplySerial) {
        replySerial = (value as DBusUint32).value;
      } else if (code == HeaderCode.Destination) {
        destination = (value as DBusString).value;
      } else if (code == HeaderCode.Sender) {
        sender = (value as DBusString).value;
      } else if (code == HeaderCode.Signature) {
        signature = value as DBusSignature;
      }
    }
    if (!align(8)) {
      return null;
    }

    if (remaining < dataLength.value) {
      return null;
    }

    var values = <DBusValue>[];
    if (signature != null) {
      var signatures = signature.split();
      for (var s in signatures) {
        var value = readDBusValue(s);
        if (value == null) {
          return null;
        }
        values.add(value);
      }
    }

    return DBusMessage(
        type: type,
        flags: flags,
        serial: serial,
        path: path,
        interface: interface,
        member: member,
        errorName: errorName,
        replySerial: replySerial,
        destination: destination,
        sender: sender,
        values: values);
  }

  /// Reads a 16 bit signed integer from the buffer.
  Future<int> readInt16() async {
    return ByteData.view(readBytes(2)).getInt16(0, Endian.little);
  }

  /// Reads a 16 bit unsigned integer from the buffer.
  Future<int> readUint16() async {
    return ByteData.view(readBytes(2)).getUint16(0, Endian.little);
  }

  /// Reads a 32 bit signed integer from the buffer.
  Future<int> readInt32() async {
    return ByteData.view(readBytes(4)).getInt32(0, Endian.little);
  }

  /// Reads a 32 bit unsigned integer from the buffer.
  Future<int> readUint32() async {
    return ByteData.view(readBytes(4)).getUint32(0, Endian.little);
  }

  /// Reads a 64 bit signed integer from the buffer.
  /// Assumes that there is sufficient data in the buffer.
  Future<int> readInt64() async {
    return ByteData.view(readBytes(8)).getInt64(0, Endian.little);
  }

  /// Reads a 64 bit unsigned integer from the buffer.
  /// Assumes that there is sufficient data in the buffer.
  Future<int> readUint64() async {
    return ByteData.view(readBytes(8)).getUint64(0, Endian.little);
  }

  /// Reads a 64 bit floating point number from the buffer.
  /// Assumes that there is sufficient data in the buffer.
  Future<double> readFloat64() async {
    return ByteData.view(readBytes(8)).getFloat64(0, Endian.little);
  }

  /// Reads a [DBusByte] from the buffer.
  Future<DBusByte> readDBusByte() async {
    return DBusByte(await readByte());
  }

  /// Reads a [DBusBoolean] from the buffer.
  Future<DBusBoolean> readDBusBoolean() async {
    await align(BOOLEAN_ALIGNMENT);
    return DBusBoolean(await readUint32() != 0);
  }

  /// Reads a [DBusInt16] from the buffer.
  Future<DBusInt16> readDBusInt16() async {
    await align(INT16_ALIGNMENT);
    return DBusInt16(await readInt16());
  }

  /// Reads a [DBusUint16] from the buffer.
  Future<DBusUint16> readDBusUint16() async {
    await align(UINT16_ALIGNMENT);
    return DBusUint16(await readUint16());
  }

  /// Reads a [DBusInt32] from the buffer.
  Future<DBusInt32> readDBusInt32() async {
    await align(INT32_ALIGNMENT);
    return DBusInt32(await readInt32());
  }

  /// Reads a [DBusUint32] from the buffer.
  Future<DBusUint32> readDBusUint32() async {
    await align(UINT32_ALIGNMENT);
    return DBusUint32(await readUint32());
  }

  /// Reads a [DBusInt64] from the buffer.
  Future<DBusInt64> readDBusInt64() async {
    await align(INT64_ALIGNMENT)l
    return DBusInt64(await readInt64());
  }

  /// Reads a [DBusUint64] from the buffer.
  Future<DBusUint64> readDBusUint64() async {
    await align(UINT64_ALIGNMENT);
    return DBusUint64(await readUint64());
  }

  /// Reads a [DBusDouble] from the buffer.
  Future<DBusDouble> readDBusDouble() async {
    await align(DOUBLE_ALIGNMENT);
    return DBusDouble(await readFloat64());
  }

  /// Reads a [DBusString] from the buffer.
  Future<DBusString> readDBusString() async {
    var length = await readDBusUint32();
    if (remaining < (length.value + 1)) {
      return null;
    }

    var values = <int>[];
    for (var i = 0; i < length.value; i++) {
      values.add(readByte());
    }
    await readByte(); // Trailing nul.

    return DBusString(utf8.decode(values));
  }

  /// Reads a [DBusObjectPath] from the buffer.
  Future<DBusObjectPath> readDBusObjectPath() async {
    var string = await readDBusString();
    return DBusObjectPath(string.value);
  }

  /// Reads a [DBusSignature] from the buffer.
  Future<DBusSignature> readDBusSignature() async {
    var length = await readByte();
    if (remaining < length + 1) {
      return null;
    }

    var values = <int>[];
    for (var i = 0; i < length; i++) {
      values.add(readByte());
    }
    readByte(); // Trailing nul

    return DBusSignature(utf8.decode(values));
  }

  /// Reads a [DBusVariant] from the buffer.
  Future<DBusVariant> readDBusVariant() async {
    var signature = await readDBusSignature();
    return DBusVariant(await readDBusValue(signature));
  }

  /// Reads a [DBusStruct] from the buffer.
  Future<DBusStruct> readDBusStruct(List<DBusSignature> childSignatures) async {
    await align(STRUCT_ALIGNMENT);

    var children = <DBusValue>[];
    for (var signature in childSignatures) {
      children.add(await readDBusValue(signature));
    }

    return DBusStruct(children);
  }

  /// Reads a [DBusArray] from the buffer.
  Future<DBusArray> readDBusArray(DBusSignature childSignature) async {
    var length = await readDBusUint32();
    await align(getAlignment(childSignature));

    /// FIXME(robert-ancell): Ensure we don't read off the end of the buffer.
    var end = readOffset + length.value;
    var children = <DBusValue>[];
    while (readOffset < end) {
      children.add(await readDBusValue(childSignature));
    }

    return DBusArray(childSignature, children);
  }

  Future<DBusDict> readDBusDict(
      DBusSignature keySignature, DBusSignature valueSignature) async {
    var length = await readDBusUint32();
    await align(DICT_ENTRY_ALIGNMENT);

    /// FIXME(robert-ancell): Ensure we don't read off the end of the buffer.
    var end = readOffset + length.value;
    var childSignatures = [keySignature, valueSignature];
    var children = <DBusValue, DBusValue>{};
    while (readOffset < end) {
      var child = await readDBusStruct(childSignatures);
      var key = child.children.elementAt(0);
      var value = child.children.elementAt(1);
      children[key] = value;
    }

    return DBusDict(keySignature, valueSignature, children);
  }

  /// Reads a [DBusValue] with [signature].
  Future<DBusValue> readDBusValue(DBusSignature signature) async {
    var s = signature.value;
    if (s == 'y') {
      return readDBusByte();
    } else if (s == 'b') {
      return readDBusBoolean();
    } else if (s == 'n') {
      return readDBusInt16();
    } else if (s == 'q') {
      return readDBusUint16();
    } else if (s == 'i') {
      return readDBusInt32();
    } else if (s == 'u') {
      return readDBusUint32();
    } else if (s == 'x') {
      return readDBusInt64();
    } else if (s == 't') {
      return readDBusUint64();
    } else if (s == 'd') {
      return readDBusDouble();
    } else if (s == 's') {
      return readDBusString();
    } else if (s == 'o') {
      return readDBusObjectPath();
    } else if (s == 'g') {
      return readDBusSignature();
    } else if (s == 'v') {
      return readDBusVariant();
    } else if (s.startsWith('a{') && s.endsWith('}')) {
      var childSignature = DBusSignature(s.substring(2, s.length - 1));
      var signatures = childSignature.split(); // FIXME: Check two signatures
      return readDBusDict(signatures[0], signatures[1]);
    } else if (s.startsWith('a')) {
      return readDBusArray(DBusSignature(s.substring(1, s.length)));
    } else if (s.startsWith('(') && s.endsWith(')')) {
      var childSignatures = <DBusSignature>[];
      for (var i = 1; i < s.length - 1; i++) {
        childSignatures.add(DBusSignature(s[i]));
      }
      return readDBusStruct(childSignatures);
    } else {
      throw "Unknown DBus data type '${s}'";
    }
  }

  /// Skips data from the buffer to align to [boundary].
  Future align(int boundary) {
    while (readOffset % boundary != 0) {
      if (remaining == 0) {
        return false;
      }
      readOffset++;
    }
    return true;
  }

  /// Removes all buffered data.
  void flush() {
    _data.removeRange(0, readOffset);
    readOffset = 0;
  }

  @override
  String toString() {
    var s = '';
    for (var d in _data) {
      if (d >= 33 && d <= 126) {
        s += String.fromCharCode(d);
      } else {
        s += '\\' + d.toRadixString(8);
      }
    }
    return "DBusDecoder('${s}')";
  }
}
