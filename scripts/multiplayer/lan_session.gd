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
## one device hosts a room, the other joins by the host's LAN IP.
## Registered as the "LanSession" autoload, like the original.

const PORT := 42424
## Host discovery (v0.3). A host answers one beacon with one reply on the same subnet, so the
## other device can list it instead of asking the player to copy an IP by hand. Kept on a
## separate port from the game so a beacon can never be mistaken for a connection attempt.
const DISCOVERY_PORT := 42425
## Overridable so the automated two-session test can run host and listener on one machine
## (two sockets cannot share a UDP port). Real devices always use DISCOVERY_PORT.
const DISCOVERY_PORT_ENV := "K2_LAN_DISCOVERY_PORT"
const BEACON := "K2LAN1?"
const BEACON_REPLY := "K2LAN1!"
const ADVERTISE_INTERVAL_SEC := 1.0
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
var _listen: PacketPeerUDP = null
var _advertise_timer: Timer = null
var _listen_timer: Timer = null
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


## This device's LAN IPv4, skipping loopback and link-local — the
## same rule the original used (it rejected 127.* and 169.254.*).
func get_local_ip() -> String:
	for ip in IP.get_local_addresses():
		if ip.contains(":"):
			continue
		if ip.begins_with("127.") or ip.begins_with("169.254."):
			continue
		if ip.is_valid_ip_address():
			return ip
	return ""


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
	var target := ip.strip_edges()
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
## The host broadcasts a small beacon once a second. Every listening device on the same
## Wi-Fi / hotspot answers the beacon, and whoever replies becomes an entry in `hosts`.
## UDP broadcast never leaves the local subnet, so nothing is exposed to the internet and
## the feature keeps working on a hotspot with no uplink at all.

func start_discovery() -> void:
	if _listen != null:
		return
	var udp := PacketPeerUDP.new()
	var err := udp.bind(discovery_port())
	if err != OK:
		# A bound port is not fatal: another K2 on this device may hold it. The player can
		# still type the address by hand, so this is surfaced as a hint, not an error dialog.
		_set_status("جست‌وجوی خودکار در دسترس نیست؛ نشانی را دستی وارد کنید. کد: " + str(err))
		return
	udp.set_broadcast_enabled(true)
	_listen = udp
	if _listen_timer == null:
		_listen_timer = Timer.new()
		_listen_timer.wait_time = 0.1
		_listen_timer.autostart = true
		_listen_timer.timeout.connect(_poll_discovery)
		add_child(_listen_timer)
	_listen_timer.start()
	_send_beacon()


func stop_discovery() -> void:
	if _listen_timer != null:
		_listen_timer.stop()
	if _listen != null:
		_listen.close()
		_listen = null
	hosts.clear()
	hosts_changed.emit(hosts)


func _send_beacon() -> void:
	if _listen == null:
		return
	_listen.set_dest_address("255.255.255.255", discovery_port())
	_listen.put_packet(BEACON.to_utf8_buffer())


func _poll_discovery() -> void:
	if _listen == null:
		return
	var now := Time.get_ticks_msec() / 1000.0
	var changed := false
	var got_reply := false
	while _listen.get_available_packet_count() > 0:
		var pkt := _listen.get_packet()
		var from := _listen.get_packet_ip()
		var txt := pkt.get_string_from_utf8()
		var from_port: int = _listen.get_packet_port()
		if txt == BEACON:
			# Someone is looking for a host: answer if this device is the host. Answering
			# unicast to the asker's OWN port keeps the reply off every other machine and
			# stops the host's own beacon from being taken as an answer by itself.
			if is_host and state == State.HOSTING:
				_listen.set_dest_address(from, from_port)
				_listen.put_packet((BEACON_REPLY + _session_name).to_utf8_buffer())
		elif txt.begins_with(BEACON_REPLY):
			if is_host and (from_port == discovery_port() or from == get_local_ip()):
				continue                       # never list ourselves
			var name := txt.substr(BEACON_REPLY.length())
			var found := false
			for h in hosts:
				if str(h.get("ip", "")) == from:
					h["seen_at"] = now
					h["name"] = name
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


## Ask once now instead of waiting for the 100 ms poll (used by the «جست‌وجو» button).
func refresh_hosts() -> void:
	_send_beacon()
	_poll_discovery()


func _start_advertising() -> void:
	_stop_advertising()
	var udp := PacketPeerUDP.new()
	if udp.bind(discovery_port()) != OK:
		# Advertising needs the discovery port. If it is taken the room still works with a
		# hand-typed address, so this is not treated as a failed host.
		return
	udp.set_broadcast_enabled(true)
	_advertise = udp
	_advertise_timer = Timer.new()
	_advertise_timer.wait_time = ADVERTISE_INTERVAL_SEC
	_advertise_timer.autostart = true
	_advertise_timer.timeout.connect(_answer_beacons)
	add_child(_advertise_timer)
	_advertise_timer.start()


func _answer_beacons() -> void:
	if _advertise == null or not is_host:
		return
	while _advertise.get_available_packet_count() > 0:
		var pkt := _advertise.get_packet()
		var from := _advertise.get_packet_ip()
		var from_port: int = _advertise.get_packet_port()
		if pkt.get_string_from_utf8() == BEACON:
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
