function fs_remove_directory_contents()
{
	DIR="$1"
	if [ -d "$DIR" ]; then
		find "$DIR" -mindepth 1 -maxdepth 1 -type f -exec rm {} \; || return 1
		find "$DIR" -mindepth 1 -maxdepth 1 -type d \( ! -name "lost+found" \) -exec rm -r {} \; || return 1
	fi
}
