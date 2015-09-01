#!/bin/bash

BASE=$1
BUILDER_LIB_RUBY="${BASE}/builder/extra/cluster-home/lib/ruby"

if [ "$BASE" == "" ]; then
	echo "The path to a Tungsten Replicator code tree is required"
	exit 1
fi

if ! [ -d $BUILDER_LIB_RUBY ]; then
	echo "${BASE} does not point to a Tungsten Replicator code tree"
	exit 1
fi

cd `dirname $0`/lib
rm -f ./tungsten.rb
rm -rf ./tungsten
rm -f ./iniparse.rb
rm -rf ./iniparse
rm -f ./ipparse.rb
rm -rf ./ipparse

cp $BUILDER_LIB_RUBY/tungsten.rb .
cp -r $BUILDER_LIB_RUBY/tungsten .
cp $BUILDER_LIB_RUBY/iniparse.rb .
cp -r $BUILDER_LIB_RUBY/iniparse .
cp $BUILDER_LIB_RUBY/ipparse.rb .
cp -r $BUILDER_LIB_RUBY/ipparse .

exit 0