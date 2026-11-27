extends SceneTree

## Kilometer 2 — LAN host discovery (v0.3).
## Verifies the beacon handshake that lets the second device SEE the host instead of typing
## an IP by hand:
##   1. a hosting session answers a K2LAN1? beacon with K2LAN1!<name>,
##   2. a listening session that receives that reply publishes the peer in `hosts`,
##   3. `hosts_changed` fires, and a non-host never announces itself as a host,
##   4. a stale host is dropped from the list.
## Loopback is used on purpose: the protocol is the same bytes on a real Wi-Fi subnet.

var passed := 0
var failed := 0

func check(cond: bool, name: String, detail: String = "") -> void:
	if cond:
		passed += 1
		print("  [PASS] %s %s" % [name, detail])
	else:
		failed += 1
		push_error("  [FAIL] %s %s" % [name, detail])


func _initialize() -> void:
	await run()
	print("=== LAN DISCOVERY SUMMARY: %d passed, %d failed ===" % [passed, failed])
	quit(1 if failed > 0 else 0)


func run() -> void:
	var host = load("res://scripts/multiplayer/lan_session.gd").new()
	host.name = "HostSession"
	get_root().add_child(host)
	await process_frame

	# The game port may be busy in a sandbox; the discovery port is what this test is about.
	var hosted: int = host.host_room()
	check(host.get("is_host") == true, "host_marks_itself_host", "(host_room err=%d)" % hosted)
	check(host.get("_advertise") != null, "host_starts_advertising")
	await create_timer(0.3).timeout

	# 1) probe the beacon exactly the way a second device would
	# The real listener binds the discovery port, so the probe does the same: the host answers
	# unicast to the asker's own port, which is what makes two devices see each other.
	# Both sessions live on one machine here, so the probe and the listener get their own
	# ports (K2_LAN_DISCOVERY_PORT). On two devices both use the fixed port.
	var client_port := 42429
	OS.set_environment("K2_LAN_DISCOVERY_PORT", str(client_port))
	var probe := PacketPeerUDP.new()
	var bind_err := probe.bind(client_port)
	check(bind_err == OK, "probe_socket_binds")
	probe.set_broadcast_enabled(true)
	probe.set_dest_address("127.0.0.1", 42425)
	probe.put_packet("K2LAN1?".to_utf8_buffer())
	var reply := ""
	for i in 20:
		await create_timer(0.1).timeout
		while probe.get_available_packet_count() > 0:
			reply = probe.get_packet().get_string_from_utf8()
		if reply != "":
			break
	check(reply.begins_with("K2LAN1!"), "host_answers_beacon", "(reply='%s')" % reply)
	check(reply.length() > "K2LAN1!".length(), "reply_carries_the_room_name", "(name='%s')" % reply.substr(7))
	probe.close()

	# 2) the listener side: a sensor session that should list the host
	var client = load("res://scripts/multiplayer/lan_session.gd").new()
	client.name = "ClientSession"
	get_root().add_child(client)
	await process_frame
	var changes := [0]
	client.hosts_changed.connect(func(_l: Array) -> void: changes[0] += 1)
	check(client.get("is_host") == false, "listener_is_not_a_host")

	# feed the listener the reply the host really sends
	client.start_discovery()
	await create_timer(0.2).timeout
	# the probe held this port; release it so the listener can take it
	probe = null
	var listen_port: PacketPeerUDP = client.get("_listen")
	check(listen_port != null, "listener_binds_the_discovery_port")
	if listen_port != null:
		# simulate the host's unicast answer arriving at the listener
		var sender := PacketPeerUDP.new()
		sender.bind(0)
		sender.set_dest_address("127.0.0.1", client_port)
		sender.put_packet((reply if reply != "" else "K2LAN1!K2").to_utf8_buffer())
		sender.close()
		var found := false
		for i in 20:
			await create_timer(0.1).timeout
			if not (client.get("hosts") as Array).is_empty():
				found = true
				break
		check(found, "listener_lists_the_host")
		var hosts: Array = client.get("hosts")
		check(not hosts.is_empty() and str(hosts[0].get("ip", "")) != "", "host_entry_has_an_ip",
			str(hosts[0].get("ip", "")) if not hosts.is_empty() else "")
		check(changes[0] > 0, "hosts_changed_is_emitted")

		# 3) TTL: an entry that stops answering is dropped. The host must be stopped first —
		# while it still advertises, every poll legitimately refreshes the entry.
		host.close()
		await create_timer(0.3).timeout
		# a stale entry is one whose last sighting is older than HOST_TTL_SEC (4 s)
		var now := Time.get_ticks_msec() / 1000.0
		for h in (client.get("hosts") as Array):
			h["seen_at"] = now - 10.0
		client._poll_discovery()
		await create_timer(0.2).timeout
		check((client.get("hosts") as Array).is_empty(), "stale_host_expires",
			"(left=%d)" % (client.get("hosts") as Array).size())

	# 4) shutting down clears the list and stops the timer
	client.stop_discovery()
	check(client.get("_listen") == null, "stop_discovery_releases_the_port")
	check((client.get("hosts") as Array).is_empty(), "stop_discovery_clears_hosts")

	check(host.get("_advertise") == null, "close_stops_advertising")

	# 5) real lobby flow: start_discovery() already holds the port when host_room() is called
	var lan_script := load("res://scripts/multiplayer/lan_session.gd")
	check(lan_script.normalize_ip(" ۱۹۲.۱۶۸.۱٫۲ ") == "192.168.1.2", "normalize_ip_handles_persian_digits")
	OS.set_environment("K2_LAN_DISCOVERY_PORT", "42430")
	host.start_discovery()
	await create_timer(0.1).timeout
	var lobby_host_err: int = host.host_room()
	check(host.get("_listen") != null and host.get("_advertise") != null, "lobby_host_does_not_collide_with_listener",
		"(host_room err=%d)" % lobby_host_err)
	var probe2 := PacketPeerUDP.new()
	if probe2.bind(0, "127.0.0.1") == OK:
		probe2.set_dest_address("127.0.0.1", 42430)
		probe2.put_packet("K2LAN1?".to_utf8_buffer())
		var reply2 := ""
		for i in 15:
			await create_timer(0.1).timeout
			while probe2.get_available_packet_count() > 0:
				reply2 = probe2.get_packet().get_string_from_utf8()
			if reply2 != "":
				break
		check(reply2.begins_with("K2LAN1!"), "lobby_host_still_answers_beacons", "(reply='%s')" % reply2)
		probe2.close()
	host.close()
	host.stop_discovery()

	client.queue_free()
	host.queue_free()
