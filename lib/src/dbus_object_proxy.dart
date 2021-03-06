import "dbus_client.dart";
import "dbus_value.dart";

/// An object to simplify access to a D-Bus object.
class DBusObjectProxy {
  final DBusClient client;
  final String destination;
  final String path;

  /// Creates a new DBus object proxy to access the object at [destination], [path].
  DBusObjectProxy(this.client, this.destination, this.path);

  /// Gets the introspection data for this object.
  Future<String> introspect() async {
    var result = await client.callMethod(
        destination: destination,
        path: path,
        interface: 'org.freedesktop.DBus.Introspectable',
        member: 'Introspect');
    return (result[0] as DBusString).value;
  }

  /// Gets a property on this object.
  Future<DBusVariant> getProperty(String interface, String name) async {
    var result = await client.callMethod(
        destination: destination,
        path: path,
        interface: 'org.freedesktop.DBus.Properties',
        member: 'Get',
        values: [DBusString(interface), DBusString(name)]);
    return result[0] as DBusVariant;
  }

  /// Gets the values of all the properties on this object.
  Future<DBusDict> getAllProperties(String interface) async {
    var result = await client.callMethod(
        destination: destination,
        path: path,
        interface: 'org.freedesktop.DBus.Properties',
        member: 'GetAll',
        values: [DBusString(interface)]);
    return result[0] as DBusDict;
  }

  /// Sets a property on this object.
  setProperty(String interface, String name, DBusValue value) async {
    await client.callMethod(
        destination: destination,
        path: path,
        interface: 'org.freedesktop.DBus.Properties',
        member: 'Set',
        values: [DBusString(interface), DBusString(name), DBusVariant(value)]);
  }

  /// Invokes a method on this object.
  Future<List<DBusValue>> callMethod(
      String interface, String member, List<DBusValue> values) async {
    return client.callMethod(
        destination: destination,
        path: path,
        interface: interface,
        member: member,
        values: values);
  }
}
