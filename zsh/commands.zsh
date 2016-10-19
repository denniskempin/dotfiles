# Chrome OS workflow methods
if [ -e ~/deviceip ]; then
	export DEVICE=$(cat ~/deviceip)
fi
setboard() { export B=--board="$*"; export BOARD="$*"; echo $B; }
setdevice(){ export DEVICE="$*"; echo "$*" > ~/deviceip; }
deploy() { emerge-$BOARD "$*" && cros deploy $DEVICE "$*"; }

# Chrome debugging
chrome_stackwalk() {
	mkdir -p crash/symbols

	select FILENAME in `ssh $1 'ls /var/spool/crash | grep dmp'`;
	do
		FILE=crash/$FILENAME
		if [ ! -e $FILE ]; then
			echo "Downloading $FILENAME"
			scp $1:/var/spool/crash/$FILENAME $FILE
		fi

		HASH=`minidump_stackwalk -m $FILE | grep 'Module|chrome|' | awk -F'|' '{print $5}'`

		mkdir -p crash/symbols/chrome/$HASH
		SYM_FILE=crash/symbols/chrome/$HASH/chrome.sym
		if [ ! -e $SYM_FILE ]; then
			echo "Generating symbols for $HASH"
			dump_syms $2/chrome > /tmp/chrome.sym
			SYM_HASH=`head -n1 /tmp/chrome.sym | awk '{print $4}'`

			if [ ! "$HASH" = "$SYM_HASH" ]; then
				echo "Local chrome binary does not match crashed binary."
				exit
		 	fi
		 	cp /tmp/chrome.sym $SYM_FILE
		fi

		minidump_stackwalk $FILE crash/symbols
		exit
	done
}

# GIT history editing methods. Requires you to be on branch work.
CL_IN_EDIT=NONE
cledit() {
  export CL_IN_EDIT=$(git log --pretty=format:'%h %s' --abbrev-commit | grep "$*" | cut -d " " -f1 | head -n1);
  echo "Editing: $(gitlogall | grep $CL_IN_EDIT)"
  git checkout $CL_IN_EDIT
}
clrebase() { git rebase --onto HEAD $CL_IN_EDIT work }
clcommit() { git commit -a --amend; clrebase }
gitlogall() { git log --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit }
gitlog() { gitlogall | head -n 40 }


# Android workflow
deploy_test() {
  rsync -v --chmod=755 out/target/product/$TARGET_PRODUCT/data/nativetest/$1/$1 $2:/home/root/\*/android-data/data
}
run_test() { ssh $2 "android-sh -c \"/data/$1\"" }
bdr_test() { m $1 && deploy_test $1 $2 && run_test $1 $2 }

get_manifest() {
  sso_client -location https://android-build.googleplex.com/builds/submitted/$1/$TARGET_PRODUCT-$TARGET_BUILD_VARIANT/latest/manifest_$1.xml > .repo/manifests/$1.xml
}


# Gerrit methods
gerrit_resubmit() {
	for cl in $(gerrit mine --raw); do
		if [[ "$(gerrit inspect $cl)" == *V:\ 1* ]]; then
			gerrit ready $cl 1;
		fi
	done
}

gerrit_submit() {
	for cl in $(gerrit mine --raw); do
		if [[ "$(gerrit inspect $cl)" == *CR:\ 2* ]]; then
			gerrit ready $cl 1; gerrit verify $cl 1;
		fi
	done
}


# Random helper to cause iterm to show a notification
notify() {
	($*);
	echo 'iterm-notify';
}

# General tools
alias zc="z -c"