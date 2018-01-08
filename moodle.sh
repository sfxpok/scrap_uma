#/bin/ksh
set -e

base_url=http://moodle.cee.uma.pt
dest=$HOME/uma/moodle

echo "MOODLE> WELCOME"

echo -n USERNAME:\ 
read username

echo -n PASSWORD:\ 
read password

tmp=`mktemp /tmp/moodleXXXXXXXXX`

cookie=$tmp.0
body=$tmp.1
head=$tmp.2

quit() { rm $tmp.* || true ; }
trap quit INT

smart_curl() {
	curl -sb $cookie -w '%{url_effective} %{content_type}' -o $body "$@" >$head
}

resource_handler() {
	read effective_url content_type encoding <$head

	case $content_type in
		text/html*)
			echo -n ...\ 
			# some links go through another page
			real_url=`cat $body | sed -n 's/.*Clique na h[^"]*"\([^"]*\).*/\1/p'`
			smart_curl $real_url && resource_handler $@
			;;
		*)
			ext=`echo ${effective_url##*.} | sed 's/?.*$//'`
			mv $body "`echo $@.$ext | sed 's$/$-$g'`"
			echo $ext GET
	esac
}

forum_handler() { return 1 ; }
choice_handler() { return 1 ; }
assign_handler() { return 1 ; }

curl -Lsc $cookie -d "username=$username&password=$password" \
	$base_url/login/index.php | grep Turmas | sed -n 's/id=/\
/gp' | sed -ne 's/"[^/]*\/span>/ /' -e 's/<.*//p' | \
tail -n +2 | while read class_id class_name
do
	echo "o===<|---------> $class_name (id: $class_id)"

	class_pwd="$dest/$class_name"
	[[ -d "$class_pwd" ]] || mkdir -p "$class_pwd/.cache"
	cd "$class_pwd"

	curl -sb $cookie $base_url/course/view.php?id=$class_id | \
		sed 's$mod/\([a-z]*\)/view.php?id=\([0-9]*\)"><[^<]*[^>]*>\([^<]*\)$\
LINK \1 \2 \3\
$g' | sed -n 's/LINK //p' | while read type id name
	do
		echo -n $type $id \"$name\"\ 

		if [[ -e ".cache/$id" ]]; then
			echo SKIP
		else
			smart_curl -L --post303 $base_url/mod/$type/view.php?id=$id &&
				${type}_handler $name && touch ".cache/$id" || echo ERROR
		fi

	done
	cd -
done

quit
