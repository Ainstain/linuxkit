#!/bin/sh

# This is designed to compile a single package to a single binary
# so it makes some assumptions about things to simplify config
# to output a single binary (in a tarball) just use -o file
# use --docker to output a tarball for input to docker build -

set -e

usage() {
	echo "Usage: -o file"
	exit 1
}

[ $# = 0 ] && usage

while [ $# -gt 1 ]
do
	flag="$1"
	case "$flag" in
	-o)
		out="$2"
		mkdir -p "$(dirname $2)"
		shift
	;;
	*)
		echo "Unknown option $1"
		exit 1
	esac
	shift
done

[ $# -gt 0 ] && usage
[ -z "$out" ] && usage

package=$(basename "$out")

dir="$GOPATH/src/$package"

mkdir -p $dir

# untar input
tar xf - -C $dir

cd $dir

# lint before building
>&2 echo "gofmt..."
test -z $(gofmt -s -l .| grep -v .pb. | grep -v */vendor/ | tee /dev/stderr)

>&2 echo "govet..."
test -z $(go tool vet -printf=false . 2>&1 | grep -v */vendor/ | tee /dev/stderr)

>&2 echo "golint..."
test -z $(find . -type f -name "*.go" -not -path "*/vendor/*" -not -name "*.pb.*" -exec golint {} \; | tee /dev/stderr)

>&2 echo "go build..."

go build -o $out -buildmode pie --ldflags '-extldflags "-static"' "$package"

tar cf - $out
