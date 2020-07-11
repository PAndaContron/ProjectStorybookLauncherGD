extends Control

var releases

var downloading = false
var down_version = ""
var play_on_download = false

onready var VersionSelect = $MarginContainer/UI/Elements/VBoxContainer/VersionSelect

onready var DownloadButton = $MarginContainer/UI/Elements/VBoxContainer/Buttons/DownloadContainer/Download
onready var DeleteButton = $MarginContainer/UI/Elements/VBoxContainer/Buttons/DeleteContainer/Delete
onready var PlayButton = $MarginContainer/UI/Elements/VBoxContainer/Buttons/PlayContainer/Play

func _ready():
	make_dir("user://", "versions")
	get_release_data()
	update_menu()

func version_list():
	var versions = []
	var local_versions = get_local_versions()
	for release in releases:
		if release.tag_name in local_versions:
			versions.append(release.tag_name + " [DOWNLOADED]")
		else:
			versions.append(release.tag_name + " [AVAILABLE]")
	versions.invert()
	return versions

func get_release_data():
	var data = do_request("api.github.com", "/repos/jcampbell11245/Project-Storybook/releases")
	releases = JSON.parse(data.get_string_from_utf8()).result
	releases.sort_custom(self, "compare_releases")

func get_local_versions():
	var versions = []
	for f in dir_contents("user://versions"):
		if f.ends_with(".pck"):
			versions.append(f.substr(0, len(f) - 4))
	return versions

func download_release(version):
	var curr_release = null
	for release in releases:
		if release.tag_name == version:
			curr_release = release
			break
	
	if curr_release:
		var curr_release_url = ""
		for asset in curr_release.assets:
			if asset.name == "ProjectStorybook.pck":
				curr_release_url = asset.browser_download_url
				break
		
		if curr_release_url == "":
			return false
		
		down_version = version
		downloading = true
		refresh_buttons(VersionSelect.selected)
		$Downloading.popup_centered()
		return $PCKRequest.request(curr_release_url) == OK
	
	return false

func do_request(host, path):
	var err = 0
	var http = HTTPClient.new()
	
	err = http.connect_to_host(host, -1, true)
	if err != OK:
		return null
	
	while http.get_status() == HTTPClient.STATUS_CONNECTING or http.get_status() == HTTPClient.STATUS_RESOLVING:
		http.poll()
		OS.delay_msec(50)
	
	if http.get_status() != HTTPClient.STATUS_CONNECTED:
		return null
	
	var headers = [
		"User-Agent: Pirulo/1.0 (Godot)",
		"Accept: */*"
	]
	
	err = http.request(HTTPClient.METHOD_GET, path, headers)
	if err != OK:
		return null
	
	while http.get_status() == HTTPClient.STATUS_REQUESTING:
		http.poll()
		OS.delay_msec(50)
	
	if http.get_status() != HTTPClient.STATUS_BODY and http.get_status() != HTTPClient.STATUS_CONNECTED:
		return null
	
	if http.has_response():
		headers = http.get_response_headers_as_dictionary()
		
		var rb = PoolByteArray()
		while http.get_status() == HTTPClient.STATUS_BODY:
			http.poll()
			var chunk = http.read_response_body_chunk()
			if chunk.size() == 0:
				OS.delay_msec(1)
			else:
				rb += chunk
		
		return rb

func compare_releases(r1, r2):
	return compare_versions(r1.tag_name, r2.tag_name)

func compare_versions(v1, v2):
	v1 = v1.substr(1).split('.')
	v2 = v2.substr(1).split('.')
	
	if int(v1[0]) < int(v2[0]):
		return true
	if int(v2[0]) < int(v1[0]):
		return false
	if int(v1[1]) < int(v2[1]):
		return true
	if int(v2[1]) < int(v1[1]):
		return false
	if int(v1[2]) < int(v2[2]):
		return true
	if int(v2[2]) < int(v1[2]):
		return false
	return false

func _on_PCKRequest_completed(result, response_code, headers, body):
	var game_pack = File.new()
	game_pack.open("user://versions/" + down_version + ".pck", File.WRITE)
	game_pack.store_buffer(body)
	game_pack.close()
	
	downloading = false
	$Downloading.hide()
	update_menu()
	
	if play_on_download:
		_on_Play_pressed()

func make_dir(parent, dirname):
	var dir = Directory.new()
	if dir.open(parent) == OK:
		dir.make_dir(dirname)

func dir_contents(path):
	var dir = Directory.new()
	var contents = []
	if dir.open(path) == OK:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir():
				contents.append(
					file_name.substr(file_name.find_last("/") + 1)
				)
			file_name = dir.get_next()
	return contents

func update_menu():
	var index = VersionSelect.selected
	if index == -1:
		index = 0
	VersionSelect.items = []
	for version in version_list():
		VersionSelect.add_item(version)
	VersionSelect.selected = index
	refresh_buttons(index)

func _on_VersionSelect_item_selected(index):
	refresh_buttons(index)

func refresh_buttons(index):
	var version = VersionSelect.get_item_text(index)
	if downloading or play_on_download:
		DownloadButton.disabled = true
		DeleteButton.disabled = true
		PlayButton.disabled = true
		VersionSelect.disabled = true
	elif version.ends_with("[AVAILABLE]"):
		DownloadButton.disabled = false
		DeleteButton.disabled = true
		PlayButton.disabled = false
		VersionSelect.disabled = false
	elif version.ends_with("[DOWNLOADED]"):
		DownloadButton.disabled = true
		DeleteButton.disabled = false
		PlayButton.disabled = false
		VersionSelect.disabled = false

func _on_Download_pressed():
	var index = VersionSelect.selected
	var version = VersionSelect.get_item_text(index)
	if not download_release(version.substr(0, version.find(" "))):
		downloading = false
		$Downloading.hide()
		refresh_buttons(index)

func _on_Delete_pressed():
	var index = VersionSelect.selected
	var version = VersionSelect.get_item_text(index)
	version = version.substr(0, version.find(" "))
	var dir = Directory.new()
	dir.remove("user://versions/" + version + ".pck")
	update_menu()

func _on_Play_pressed():
	var index = VersionSelect.selected
	var version = VersionSelect.get_item_text(index)
	if version.ends_with("[AVAILABLE]"):
		play_on_download = true
		_on_Download_pressed()
	else:
		version = version.substr(0, version.find(" "))
		var pck_file = ProjectSettings.globalize_path("user://versions/" + version + ".pck")
		var _exit_code = OS.execute(OS.get_executable_path(), ["--main-pack", pck_file], false)
		get_tree().quit()
