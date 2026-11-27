extends Node
## (No class_name on purpose: the autoload registration provides the
## global "LanSession" name, exactly like the original build.)

## K2-FIX-004: LAN multiplayer session — RECONSTRUCTION of the
## feature that shipped only in the separate Kilometer2_LAN_Test.apk
## (2026-10-30) and was never merged into the Final Project source.
## The design below is recovered from that build's bytecode (file
## layout, autoload registration, RPC modes, Persian UI strings) and
## re-implemented against the current codebase; see FIX004_REPORT.md
## for the archaeology. The original UDP port was not recoverable
## from the bytecode, so a documented port is used instead.
##
## Two players on one Wi-Fi / hotspot, no internet needed:
## one device hosts a room, the other joins by discovery or the host's LAN IP.
## Registered as the "LanSession" autoload, like the original.

const PORT := 42424
## Host discovery (v0.3). A host answers beacons and periodically announces itself on the
## local subnet so the other device lists it automatically without typing an IP.
## Kept on a separate port from the game so a beacon can never be mistaken for a connection.
const DISCOVERY_PORT := 42425
## Overridable so the automated two-session test can run host and listener on one machine
## (two sockets cannot share a UDP port). Real devices always use DISCOVERY_PORT.
const DISCOVERY_PORT_ENV := "K2_LAN_DISCOVERY_PORT"
const BEACON := "K2LAN1?"
const BEACON_REPLY := "K2LAN1!"
const ADVERTISE_INTERVAL_SEC := 1.0
const ADVERTISE_POLL_SEC := 0.15
const BEACON_INTERVAL_SEC := 1.5
const DISCOVERY_TIMEOUT_SEC := 2.0
## A host that stopped advertising is dropped from the list after this long.
const HOST_TTL_SEC := 4.0
const MAX_CLIENTS := 1
const CONNECT_TIMEOUT_SEC := 8.0
const LOBBY_SCENE := "res://scenes/multiplayer/lan_lobby.tscn"
const GAME_SCENE := "res://scenes/multiplayer/lan_game.tscn"
const MENU_SCENE := "res://scenes/ui/main_menu.tscn"

enum State { IDLE, HOSTING, CONNECTING, IN_GAME }

signal status_changed(message: String)
signal lan_error(message: String)
## Emitted whenever the discovered-host list changes (found, refreshed, expired).
signal hosts_changed(hosts: Array)

var state: State = State.IDLE
var is_host := false
var status_text := ""
## Wire transport: "enet" (UDP, the normal LAN transport) or "ws"
## (WebSocket/TCP fallback). The K2_LAN_TRANSPORT environment
## variable can force "ws" — used by the automated two-process test
## in sandboxes that block UDP outright, and harmless elsewhere.
var transport := "enet"
var _connect_timer: Timer = null
## Discovered LAN hosts: [{ip, port, name, seen_at}]. Never contains this device itself.
var hosts: Array = []
var _advertise: PacketPeerUDP = null
var _advertise_owns_port := false
var _listen: PacketPeerUDP = null
var _advertise_timer: Timer = null
var _advertise_accum := 0.0
var _listen_timer: Timer = null
var _listen_beacon_accum := 0.0
var _session_name := "K2"


func is_in_game() -> bool:
	return state == State.IN_GAME


func discovery_port() -> int:
	var raw := OS.get_environment(DISCOVERY_PORT_ENV)
	if raw != "" and raw.is_valid_int():
		return int(raw)
	return DISCOVERY_PORT


func _use_ws() -> bool:
	return OS.get_environment("K2_LAN_TRANSPORT") == "ws"


func _ready() -> void:
	_session_name = "K2 · " + str(OS.get_model_name() if OS.get_model_name() != "" else "دستگاه")
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


func _exit_tree() -> void:
	close()


func _set_status(msg: String) -> void:
	status_text = msg
	status_changed.emit(msg)


func _fail(msg: String) -> void:
	lan_error.emit(msg)
	_set_status(msg)


static func normalize_ip(raw: String) -> String:
	var s := raw.strip_edges()
	if s.begins_with("::ffff:"):
		s = s.substr(7)
	const PERSIAN_DIGITS := "۰۱۲۳۴۵۶۷۸۹"
	const ARABIC_DIGITS := "٠١٢٣٤٥٦٧٨٩"
	for i in range(10):
		s = s.replace(PERSIAN_DIGITS[i], str(i))
		s = s.replace(ARABIC_DIGITS[i], str(i))
	s = s.replace("٫", ".").replace("،", ".").replace(",", ".")
	return s


static func _is_private_lan_ipv4(ip: String) -> int:
	if ip.begins_with("192.168."):
		return 50
	if ip.begins_with("10."):
		return 30
	if ip.begins_with("172."):
		var parts := ip.split(".")
		if parts.size() == 4 and parts[1].is_valid_int():
			var second := int(parts[1])
			if second >= 16 and second <= 31:
				return 40
	if ip.begins_with("100."):
		var parts := ip.split(".")
		if parts.size() == 4 and parts[1].is_valid_int():
			var second := int(parts[1])
			if second >= 64 and second <= 127:
				return -50 # Carrier-grade NAT (mobile data)
	return 0


static func _interface_score(iface_name: String) -> int:
	var n := iface_name.to_lower()
	for bad in ["lo", "rmnet", "ccmni", "pdp", "wwan", "clat", "v4-", "tun", "tap", "ppp", "wg", "ipsec", "sit", "dummy", "docker", "veth", "virbr"]:
		if n.begins_with(bad) or n.contains(bad):
			return -1
	for good in ["ap", "swlan", "softap", "wlan", "wifi", "eth", "en"]:
		if n.begins_with(good) or n.contains(good):
			return 100
	return 10


## Ordered list of this device's Wi-Fi / Hotspot / LAN IPv4 addresses, preferring
## wireless/hotspot interfaces and RFC1918 private ranges over cellular/VPN tunnels.
func get_local_ips() -> PackedStringArray:
	var scored: Array = []
	var seen: Dictionary = {}
	for iface in IP.get_local_interfaces():
		var iname := str(iface.get("name", ""))
		var iscore := _interface_score(iname)
		if iscore < 0:
			continue
		var addrs: Array = iface.get("addresses", [])
		for raw_ip in addrs:
			var ip := str(raw_ip)
			if ip.contains(":") or ip == "0.0.0.0":
				continue
			if ip.begins_with("127.") or ip.begins_with("169.254."):
				continue
			if not ip.is_valid_ip_address() or seen.has(ip):
				continue
			seen[ip] = true
			scored.append({"ip": ip, "score": iscore + _is_private_lan_ipv4(ip)})
	if scored.is_empty():
		for ip in IP.get_local_addresses():
			if ip.contains(":") or ip == "0.0.0.0":
				continue
			if ip.begins_with("127.") or ip.begins_with("169.254."):
				continue
			if not ip.is_valid_ip_address() or seen.has(ip):
				continue
			seen[ip] = true
			scored.append({"ip": ip, "score": _is_private_lan_ipv4(ip)})
	scored.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a["score"]) > int(b["score"]))
	var out := PackedStringArray()
	for item in scored:
		out.append(str(item["ip"]))
	return out


## This device's primary LAN IPv4, skipping loopback, link-local, cellular and VPN
## interfaces where Wi-Fi / Hotspot addresses are available.
func get_local_ip() -> String:
	var ips := get_local_ips()
	return ips[0] if not ips.is_empty() else ""


func _is_own_ip(ip: String) -> bool:
	var norm := normalize_ip(ip)
	if norm == "127.0.0.1":
		return true
	for local_ip in IP.get_local_addresses():
		if normalize_ip(local_ip) == norm:
			return true
	return false


## Builds UDP discovery destination addresses: global broadcast, directed /24 subnet
## broadcasts (critical on Android Hotspot where 255.255.255.255 routes out cellular or
## fails without a default gateway), and the /24 .1 gateway (hotspot owner IP).
func _discovery_targets(include_gateway: bool) -> PackedStringArray:
	var targets: Array[String] = ["255.255.255.255"]
	var seen := {"255.255.255.255": true}
	for ip in get_local_ips():
		var parts := ip.split(".")
		if parts.size() != 4:
			continue
		var prefix := "%s.%s.%s" % [parts[0], parts[1], parts[2]]
		var bcast := prefix + ".255"
		if not seen.has(bcast):
			seen[bcast] = true
			targets.append(bcast)
		if include_gateway:
			var gw := prefix + ".1"
			if gw != ip and not seen.has(gw):
				seen[gw] = true
				targets.append(gw)
	return PackedStringArray(targets)


func _send_to_targets(sock: PacketPeerUDP, payload: PackedByteArray, port: int, include_gateway: bool) -> void:
	if sock == null:
		return
	for target in _discovery_targets(include_gateway):
		sock.set_dest_address(target, port)
		sock.put_packet(payload)


func host_room() -> Error:
	close()
	var peer: MultiplayerPeer
	var err: Error
	if _use_ws():
		transport = "ws"
		var ws := WebSocketMultiplayerPeer.new()
		err = ws.create_server(PORT)
		peer = ws
	else:
		transport = "enet"
		var en := ENetMultiplayerPeer.new()
		err = en.create_server(PORT, MAX_CLIENTS)
		peer = en
	if err != OK:
		_fail("ساخت اتاق ناموفق بود؛ پورت ممکن است مشغول باشد. کد: " + str(err))
		return err
	multiplayer.multiplayer_peer = peer
	is_host = true
	state = State.HOSTING
	_start_advertising()
	_set_status("اتاق ساخته شد؛ منتظر بازیکن دوم هستیم.")
	return OK


func join_room(ip: String) -> Error:
	close()
	var target := normalize_ip(ip)
	if not target.is_valid_ip_address():
		_fail("نشانی IP معتبر نیست یا اتصال آغاز نشد. کد: " + str(ERR_INVALID_PARAMETER))
		return ERR_INVALID_PARAMETER
	var peer: MultiplayerPeer
	var err: Error
	if _use_ws():
		transport = "ws"
		var ws := WebSocketMultiplayerPeer.new()
		err = ws.create_client("ws://" + target + ":" + str(PORT))
		peer = ws
	else:
		transport = "enet"
		var en := ENetMultiplayerPeer.new()
		err = en.create_client(target, PORT)
		peer = en
	if err != OK:
		_fail("نشانی IP معتبر نیست یا اتصال آغاز نشد. کد: " + str(err))
		return err
	multiplayer.multiplayer_peer = peer
	is_host = false
	state = State.CONNECTING
	_set_status("در حال اتصال به میزبان…")
	_connect_timer = Timer.new()
	_connect_timer.wait_time = CONNECT_TIMEOUT_SEC
	_connect_timer.one_shot = true
	_connect_timer.timeout.connect(_on_connect_timeout)
	add_child(_connect_timer)
	_connect_timer.start()
	return OK


func cancel() -> void:
	close()
	_set_status("اتصال لغو شد.")


func close() -> void:
	_stop_advertising()
	if _connect_timer != null:
		_connect_timer.stop()
		_connect_timer.queue_free()
		_connect_timer = null
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	is_host = false
	state = State.IDLE


func open_lobby() -> void:
	SceneTransitionLayer.go(get_tree(), LOBBY_SCENE, "در حال آماده‌سازی بازی شبکه‌ای…")


func open_menu() -> void:
	SceneTransitionLayer.go(get_tree(), MENU_SCENE, "بازگشت به نمایشگاه…")


## v0.3: the handshake result is shown on the same loading screen as every other scene
## change, instead of a hard cut. The peer is already connected by this point, so the dwell
## only delays the first frame -- it cannot break the handshake.

func _open_game() -> void:
	state = State.IN_GAME
	SceneTransitionLayer.go(get_tree(), GAME_SCENE, "در حال آماده‌سازی پیست — بازی شبکه‌ای")


func _on_connect_timeout() -> void:
	if state == State.CONNECTING:
		close()
		_fail("زمان اتصال به پایان رسید. نشانی و شبکه را بررسی کنید.")


func _on_peer_connected(_id: int) -> void:
	if is_host and state == State.HOSTING:
		_set_status("بازیکن دوم متصل شد؛ در حال آماده‌سازی بازی…")
		_open_game.call_deferred()


func _on_connected_to_server() -> void:
	if state == State.CONNECTING:
		if _connect_timer != null:
			_connect_timer.stop()
			_connect_timer.queue_free()
			_connect_timer = null
		_set_status("به میزبان متصل شدید؛ در حال آماده‌سازی…")
		_open_game.call_deferred()


func _on_connection_failed() -> void:
	close()
	_fail("اتصال برقرار نشد؛ نشانی IP و شبکه را بررسی کنید.")


func _on_peer_disconnected(_id: int) -> void:
	if state == State.IN_GAME:
		var msg := "بازیکن دوم قطع شد. دوباره اتاق بسازید." if is_host else "ارتباط با میزبان قطع شد."
		close()
		_fail(msg)
		open_lobby.call_deferred()
	elif is_host and state == State.HOSTING:
		_set_status("اتاق ساخته شد؛ منتظر بازیکن دوم هستیم.")


func _on_server_disconnected() -> void:
	if state == State.IN_GAME or state == State.CONNECTING:
		close()
		_fail("ارتباط با میزبان قطع شد.")
		open_lobby.call_deferred()


# =========================================================================================
# LAN host discovery
# =========================================================================================
## The host answers beacons and also broadcasts periodic announcements across the local
## subnet(s). Every listening device on the same Wi-Fi / hotspot collects replies in
## `hosts`. Using directed subnet broadcasts and the .1 hotspot gateway alongside
## 255.255.255.255 keeps discovery working on Android hotspots and multi-homed phones.

func start_discovery() -> void:
	if _listen != null:
		return
	var udp := PacketPeerUDP.new()
	var err := udp.bind(discovery_port(), "0.0.0.0")
	if err != OK:
		# A bound port is not fatal: another K2 on this device may hold it. The player can
		# still type the address by hand, so this is surfaced as a hint, not an error dialog.
		_set_status("جست‌وجوی خودکار در دسترس نیست؛ نشانی را دستی وارد کنید. کد: " + str(err))
		return
	udp.set_broadcast_enabled(true)
	_listen = udp
	_listen_beacon_accum = 0.0
	if _listen_timer == null:
		_listen_timer = Timer.new()
		_listen_timer.wait_time = 0.1
		_listen_timer.autostart = true
		_listen_timer.timeout.connect(_on_listen_tick)
		add_child(_listen_timer)
	_listen_timer.start()
	_send_beacon()


func stop_discovery() -> void:
	if _listen_timer != null:
		_listen_timer.stop()
		_listen_timer.queue_free()
		_listen_timer = null
	if _listen != null:
		_listen.close()
		_listen = null
	hosts.clear()
	hosts_changed.emit(hosts)


func _on_listen_tick() -> void:
	_poll_discovery()
	if not is_host and state == State.IDLE:
		_listen_beacon_accum += 0.1
		if _listen_beacon_accum >= BEACON_INTERVAL_SEC:
			_listen_beacon_accum = 0.0
			_send_beacon()
	else:
		_listen_beacon_accum = 0.0


func _send_beacon() -> void:
	if _listen == null:
		return
	_send_to_targets(_listen, BEACON.to_utf8_buffer(), discovery_port(), true)


func _poll_discovery() -> void:
	if _listen == null:
		return
	var now := Time.get_ticks_msec() / 1000.0
	var changed := false
	while _listen.get_available_packet_count() > 0:
		var pkt := _listen.get_packet()
		var from := normalize_ip(_listen.get_packet_ip())
		var txt := pkt.get_string_from_utf8()
		var from_port: int = _listen.get_packet_port()
		if txt == BEACON:
			# Someone is looking for a host: answer if this device is the host. Answering
			# unicast to the asker's OWN port keeps the reply off every other machine and
			# stops the host's own beacon from being taken as an answer by itself.
			if is_host and state == State.HOSTING and from != "":
				_listen.set_dest_address(from, from_port)
				_listen.put_packet((BEACON_REPLY + _session_name).to_utf8_buffer())
		elif txt.begins_with(BEACON_REPLY):
			if is_host and (from_port == discovery_port() or _is_own_ip(from)):
				continue                       # never list ourselves
			if from == "":
				continue
			var name := txt.substr(BEACON_REPLY.length())
			var found := false
			for h in hosts:
				if str(h.get("ip", "")) == from:
					h["seen_at"] = now
					if str(h.get("name", "")) != name:
						h["name"] = name
						changed = true
					found = true
					break
			if not found:
				hosts.append({"ip": from, "port": PORT, "name": name, "seen_at": now})
				changed = true
	# drop hosts that stopped answering
	var keep: Array = []
	for h in hosts:
		if now - float(h.get("seen_at", 0.0)) <= HOST_TTL_SEC:
			keep.append(h)
		else:
			changed = true
	hosts = keep
	if changed:
		hosts_changed.emit(hosts)


## Ask once now instead of waiting for the periodic poll (used by the «جست‌وجو» button).
func refresh_hosts() -> void:
	if _listen == null:
		start_discovery()
		return
	_listen_beacon_accum = 0.0
	_send_beacon()
	_poll_discovery()


func _start_advertising() -> void:
	_stop_advertising()
	var udp := PacketPeerUDP.new()
	if _listen != null:
		# The lobby listener already holds discovery_port() and answers incoming beacons
		# every 0.1 s in _poll_discovery(). Bind an ephemeral port for outgoing announcements
		# so host_room() never collides with _listen on port 42425.
		if udp.bind(0, "0.0.0.0") != OK:
			return
		_advertise_owns_port = false
	else:
		if udp.bind(discovery_port(), "0.0.0.0") != OK:
			# Advertising needs the discovery port when _listen is absent. If it is taken,
			# the room still works with a hand-typed address.
			return
		_advertise_owns_port = true
	udp.set_broadcast_enabled(true)
	_advertise = udp
	_advertise_accum = 0.0
	_advertise_timer = Timer.new()
	_advertise_timer.wait_time = ADVERTISE_POLL_SEC
	_advertise_timer.autostart = true
	_advertise_timer.timeout.connect(_on_advertise_tick)
	add_child(_advertise_timer)
	_advertise_timer.start()
	_broadcast_announcement()


func _on_advertise_tick() -> void:
	if _advertise == null or not is_host or state != State.HOSTING:
		return
	if _advertise_owns_port:
		_answer_beacons()
	_advertise_accum += ADVERTISE_POLL_SEC
	if _advertise_accum >= ADVERTISE_INTERVAL_SEC:
		_advertise_accum = 0.0
		_broadcast_announcement()


func _broadcast_announcement() -> void:
	if _advertise == null or not is_host or state != State.HOSTING:
		return
	_send_to_targets(_advertise, (BEACON_REPLY + _session_name).to_utf8_buffer(), discovery_port(), true)


func _answer_beacons() -> void:
	if _advertise == null or not is_host:
		return
	while _advertise.get_available_packet_count() > 0:
		var pkt := _advertise.get_packet()
		var from := normalize_ip(_advertise.get_packet_ip())
		var from_port: int = _advertise.get_packet_port()
		if pkt.get_string_from_utf8() == BEACON and from != "":
			_advertise.set_dest_address(from, from_port)
			_advertise.put_packet((BEACON_REPLY + _session_name).to_utf8_buffer())


func _stop_advertising() -> void:
	if _advertise_timer != null:
		_advertise_timer.stop()
		_advertise_timer.queue_free()
		_advertise_timer = null
	if _advertise != null:
		_advertise.close()
		_advertise = null
	_advertise_owns_port = false
	_advertise_accum = 0.0
