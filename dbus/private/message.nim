
type Message* = object
  msg: ptr DBusMessage

proc makeSignal*(path: string, iface: string, name: string): Message =
  result.msg = dbus_message_new_signal(path, iface, name)

proc makeCall*(dest: string, path: string, iface: string, name: string): Message =
  result.msg = dbus_message_new_method_call(dest, path, iface, name)

proc sendMessage*(conn: Connection, msg: var Message): dbus_uint32_t {.discardable.} =
  var serial: dbus_uint32_t
  let ret = dbus_connection_send(conn.conn, msg.msg, addr serial)
  dbus_message_unref(msg.msg)
  msg.msg = nil
  if not bool(ret):
      raise newException(DbusException, "dbus_connection_send")
  return serial

type PendingCall* = object
  call: ptr DBusPendingCall

proc sendMessageWithReply*(conn: Connection, msg: var Message): PendingCall =
  let ret = dbus_connection_send_with_reply(conn.conn, msg.msg, addr result.call, -1)
  dbus_message_unref(msg.msg)
  msg.msg = nil
  if not bool(ret):
    raise newException(DbusException, "dbus_connection_send_with_reply")
  if result.call == nil:
    raise newException(DbusException, "pending call still nil")

# Serialization

proc append(msg: Message, typecode: DbusType, data: pointer) =
  var args: DBusMessageIter
  dbus_message_iter_init_append(msg.msg, addr args);
  if dbus_message_iter_append_basic(addr args, typecode.kind.char.cint, data) == 0:
      raise newException(DbusException, "append_basic")

proc append*[T: cstring|uint32|int32|uint16|int16](msg: Message, x: T) =
  var y: T = x
  msg.append(getDbusType(T), addr y)

proc append*(msg: Message, x: string) =
  # TODO: check if dbus_message_iter_init_append appends or there is a room
  # for use use-after-free.
  msg.append(x.cstring)