# Chrome OS workflow methods
cros_bd() { emerge-$BOARD "$*" && cros deploy $DEVICE "$*"; }

# Chrome workflows
cr_stackwalk() {
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
cr_build_dir() { export CR_BUILD_DIR=$1; }
cr_build() { ninja -j128 -C $CR_BUILD_DIR chrome chrome_sandbox nacl_helper; }
cr_deploy() { deploy_chrome --build-dir=$CR_BUILD_DIR --to=$1 }
cr_bd() { cr_build && cr_deploy $1 }

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
arct_deploy() {
  rsync -v --chmod=755 out/target/product/$TARGET_PRODUCT/data/nativetest/$1/$1 $2:/home/root/\*/android-data/data
}
arct_run() { ssh $2 "android-sh -c \"/data/$1\"" }
arct_bdr() { m $1 && arct_deploy $1 $2 && arct_run $1 $2 }
arc_root() {
	echo /workspace/android/$(pwd | awk -F/ '/workspace\/android/ { print $4 }')
}
arc_build() { m -j32 }
arc_deploy() { $(arc_root)/device/google/cheets2/scripts/push-to-device.sh $1 }
arc_bd() { arc_build && arc_deploy }

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